/*
 * bp_fe_pc_gen.v
 *
 * pc_gen.v provides the interfaces for the pc_gen logics and also interfacing
 * other modules in the frontend. PC_gen provides the pc for the itlb and icache.
 * PC_gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

module bp_fe_pc_gen
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_fe_pkg::*;
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter eaddr_width_p="inv"
   , parameter btb_tag_width_p="inv"
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , parameter instr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter bp_first_pc_p="inv"
   , localparam instr_scan_width_lp=`bp_fe_instr_scan_width
   , localparam branch_metadata_fwd_width_lp=`bp_fe_branch_metadata_fwd_width(btb_tag_width_p,btb_indx_width_p,bht_indx_width_p,ras_addr_width_p)
   , localparam bp_fe_pc_gen_icache_width_lp=eaddr_width_p
   , localparam bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p)
   , localparam bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
   , localparam bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p,branch_metadata_fwd_width_lp)
   , localparam bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp)
   , localparam unaligned_instr_metadata_width_lp = `bp_be_unaligned_instr_metadata_width
   , parameter prediction_on_p=1
   , parameter branch_predictor_p="inv"

   , localparam btb_tag_width_lp = eaddr_width_p - btb_indx_width_p - 2
   )
  (input                                             clk_i
   , input                                           reset_i
   , input                                           v_i
    
   , output logic [bp_fe_pc_gen_icache_width_lp-1:0] pc_gen_icache_o
   , output logic                                    pc_gen_icache_v_o
   , input                                           pc_gen_icache_ready_i

   , input [bp_fe_icache_pc_gen_width_lp-1:0]        icache_pc_gen_i
   , input                                           icache_pc_gen_v_i
   , output logic                                    icache_pc_gen_ready_o
   , input                                           icache_miss_i

   , output logic [bp_fe_pc_gen_itlb_width_lp-1:0]   pc_gen_itlb_o
   , output logic                                    pc_gen_itlb_v_o
   , input                                           pc_gen_itlb_ready_i
     
   , output logic [bp_fe_pc_gen_width_o_lp-1:0]      pc_gen_fe_o
   , output logic                                    pc_gen_fe_v_o
   , input                                           pc_gen_fe_ready_i

   , input [bp_fe_pc_gen_width_i_lp-1:0]             fe_pc_gen_i
   , input                                           fe_pc_gen_v_i
   , output logic                                    fe_pc_gen_ready_o

   , input logic                                     tlb_miss_v_i
   );

// Suppress unused signal warnings
wire unused0 = v_i;
wire unused1 = pc_gen_itlb_ready_i;

assign icache_pc_gen_ready_o = '0;
assign pc_gen_itlb_v_o = pc_gen_icache_v_o;

//the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
//fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(branch_metadata_fwd_width_lp);
//pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(eaddr_width_p);
//pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);
//icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(eaddr_width_p);
//the second level structs definitions
`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p,btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);

   
//the first level structs instatiations
bp_fe_pc_gen_queue_s        pc_gen_queue;
bp_fe_pc_gen_cmd_s          fe_pc_gen_cmd;
bp_fe_pc_gen_icache_s       pc_gen_icache;
bp_fe_pc_gen_itlb_s         pc_gen_itlb;
bp_fe_branch_metadata_fwd_s branch_metadata_fwd_o;
bp_fe_icache_pc_gen_s       icache_pc_gen;
bp_be_unaligned_instr_metadata  unaligned_instr, unaligned_instr_r;
   

   
//the second level structs instatiations
bp_fe_fetch_s            pc_gen_fetch;
bp_fe_exception_s        pc_gen_exception;
bp_fe_instr_scan_s [1:0]      scan_instr;
   
   
// pipeline pc's
logic [eaddr_width_p-1:0]       pc_f2, prev_pc_f2;
logic                           pc_v_f2;
logic [eaddr_width_p-1:0]       pc_f1;
// pc_v_f1 is not a pipeline register, because the squash needs to be 
// done in the same cycle as when we know the instruction in f2 is
// a branch
logic                           pc_v_f1;
logic [eaddr_width_p-1:0]       pc_n;

logic                           stall;

//branch prediction wires
logic                           is_rvi_br;
logic                           is_rvc_br;   
logic                           is_rvi_jal;
logic                           is_rvc_jal;
logic [eaddr_width_p-1:0]       br_target;
logic [eaddr_width_p-1:0]       prev_br_target;
logic                           is_back_br;
logic                           predict_taken;

// icache miss recovery wires
logic                           icache_miss_recover;
logic                           icache_miss_prev;

// tlb miss recovery wires
logic                           tlb_miss_recover;
logic                           tlb_miss_prev;

//control signals
logic                          misalignment;
logic                          predict;
logic                          pc_redirect_after_icache_miss;
logic                          stalled_pc_redirect;
logic                          bht_r_v_branch_jalr_inst;
logic                          branch_inst;
logic 		                     btb_r_v_i;
logic 		                     previous_pc_gen_icache_v;
   
bp_fe_branch_metadata_fwd_s fe_queue_branch_metadata, fe_queue_branch_metadata_r;

logic btb_pred_f1_r, btb_pred_f2_r;
logic br_predict_taken_f1, br_predict_taken_f2;
logic prev_cycle_jump, jump;
        
//zazad begins
logic [1:0] instr_is_compressed;
logic [2:0] taken;
// save the unaligned part of the instruction to this ff
//logic [15:0] unaligned_instr_d, unaligned_instr_q;
// the last instruction was unaligned
//logic unaligned_d, unaligned_q;
// register to save the unaligned address
//logic [eaddr_width_p-1:0] unaligned_address_d, unaligned_address_q;
logic instruction_valid;
logic [1:0][instr_width_p-1:0] instr;
logic [1:0][eaddr_width_p-1:0] addr;
logic [1:0]                 valid;
   
// Logic for handling coming out of reset
enum bit [0:0] {e_stall, e_run} state_n, state_r;
logic ready;  
logic [eaddr_width_p-1:0] pc_resume;
logic                  jump_second_half,  jump_second_half_prev;   
logic               prev_predict_taken;   
   

assign ready = pc_gen_fe_ready_i & pc_gen_icache_ready_i;   
always_comb
  begin
     unique casez (state_r)
       e_run   : state_n = ~ready ? e_stall : e_run;
       e_stall : state_n = ready  ? e_run   : e_stall;
       default : state_n = e_run;
     endcase // casez (state_r)
  end
   
 always_ff @(posedge clk_i)
  begin
     if (reset_i)
       state_r <= e_run;
     else
       state_r <= state_n;
  end
   
always_ff @(posedge clk_i)
  begin
     if (state_r == e_run && predict_taken && stall && unaligned_instr_r.valid)
       pc_resume <= pc_f2;
     else if (state_r == e_run && predict_taken && stall)
       pc_resume <= br_target;
     else if (state_r == e_run && ~prev_predict_taken)
       pc_resume <= pc_f2; 
     else if (state_r == e_run && prev_predict_taken)
       pc_resume <= prev_br_target;
     else if (fe_pc_gen_v_i && fe_pc_gen_cmd.pc_redirect_valid)
       pc_resume <= fe_pc_gen_cmd.pc;
     else
       pc_resume <= pc_resume;
  end 

   
for (genvar i = 0; i < 2; i ++) begin
   // LSB != 2'b11
   assign instr_is_compressed[i] = ~&icache_pc_gen.instr[i * 16 +: 2];
end
   
// FE realignment to do branch-prediction
always_comb begin : re_align
   unaligned_instr.valid = unaligned_instr_r.valid;
   unaligned_instr.address = unaligned_instr_r.address;
   unaligned_instr.instr = unaligned_instr_r.instr;
   instruction_valid = icache_pc_gen_v_i;


    // 2 16-bit instructions
   instr[0] = icache_pc_gen.instr;
   addr[0]  = icache_pc_gen.addr;
   valid[0] = 1;
   
   instr[1] = '0;
   addr[1] = {icache_pc_gen.addr[63:2], 2'b10};
   valid[1] = 1;
  
   if (icache_pc_gen_v_i) begin
      // last instruction was unaligned
      if (unaligned_instr_r.valid) begin
         instr[0] = {icache_pc_gen.instr[15:0], unaligned_instr_r.instr};
         addr[0]  = unaligned_instr_r.address;

         unaligned_instr.address = {icache_pc_gen.addr[63:2], 2'b10};
         unaligned_instr.instr = icache_pc_gen.instr[31:16]; // save the upper bits for next cycle

         if (instr_is_compressed[1]) begin
            unaligned_instr.valid = 1'b0;
            instr[1] = {16'b0, icache_pc_gen.instr[31:16]};
            pc_gen_fetch.pc                  = icache_pc_gen.addr;
            pc_gen_fetch.instr               = icache_pc_gen.instr;
            
         end
         else
           begin
              pc_gen_fetch.pc                  = icache_pc_gen.addr;
              pc_gen_fetch.instr               = icache_pc_gen.instr;
           end
      
      end else if (instr_is_compressed[0]) begin // RVC
         pc_gen_fetch.pc                  = icache_pc_gen.addr;
         pc_gen_fetch.instr               = icache_pc_gen.instr;
         if(icache_pc_gen.addr[1])
           valid[0]=0;
         if (instr_is_compressed[1]) begin
            instr[1] = {16'b0, icache_pc_gen.instr[31:16]};
         end else begin
            unaligned_instr.instr = icache_pc_gen.instr[31:16];
            unaligned_instr.address = {icache_pc_gen.addr[63:2], 2'b10};
            unaligned_instr.valid = 1'b1;
         end 
      end 
      else
        begin
           pc_gen_fetch.pc                  = icache_pc_gen.addr;
           pc_gen_fetch.instr               = icache_pc_gen.instr;
        end 
   end 

   if (icache_pc_gen_v_i && icache_pc_gen.addr[1] && !instr_is_compressed[1]) begin
       instruction_valid = 1'b0;
       unaligned_instr.valid = 1'b1;
       unaligned_instr.address = {icache_pc_gen.addr[63:2], 2'b10};
       unaligned_instr.instr = icache_pc_gen.instr[31:16];
   end
end      
 

   
//connect pc_gen to the rest of the FE submodules as well as FE top module   
assign pc_gen_icache_o = pc_gen_icache;
assign pc_gen_itlb_o   = pc_gen_itlb;
assign pc_gen_fe_o     = pc_gen_queue;
assign fe_pc_gen_cmd   = fe_pc_gen_i;
assign icache_pc_gen   = icache_pc_gen_i;

assign misalignment    = fe_pc_gen_v_i
                         && fe_pc_gen_cmd.pc_redirect_valid 
                         && ~fe_pc_gen_cmd.pc[3:0] == 4'h0 
                         && ~fe_pc_gen_cmd.pc[3:0] == 4'h4
                         && ~fe_pc_gen_cmd.pc[3:0] == 4'h8
                         && ~fe_pc_gen_cmd.pc[3:0] == 4'hC;

assign btb_r_v_i       = previous_pc_gen_icache_v;
   
/* output wiring */
// there should be fixes to the pc signal sent out according to the valid/ready signal pairs
always_comb 
  begin
    pc_gen_queue.msg_type            = (misalignment) ?  e_fe_exception : e_fe_fetch;
    pc_gen_exception.exception_code  = (misalignment) ? e_instr_addr_misaligned : e_illegal_instruction;
    pc_gen_fetch.branch_metadata_fwd = fe_queue_branch_metadata_r;
    pc_gen_fetch.valid_branch_taken  = taken;
    pc_gen_fetch.padding             = '0;
    pc_gen_exception.padding         = '0;
    pc_gen_queue.msg                 = (pc_gen_queue.msg_type == e_fe_fetch) ? pc_gen_fetch : pc_gen_exception;
    pc_gen_icache.virt_addr          = pc_n;
    pc_gen_itlb.virt_addr            = pc_n;
  end
   
//valid-ready signals assignments
always_comb 
begin
  if (reset_i) 
    begin
      pc_gen_fe_v_o     = 1'b0;
      fe_pc_gen_ready_o = 1'b0;
      pc_gen_icache_v_o = 1'b0;
    end 
  else 
    begin
      fe_pc_gen_ready_o = ~stall & fe_pc_gen_v_i;
      pc_gen_fe_v_o     = pc_gen_fe_ready_i & icache_pc_gen_v_i & ~icache_miss_i & pc_v_f2 & ~tlb_miss_v_i & (state_r != e_stall);
      pc_gen_icache_v_o = pc_gen_fe_ready_i && ~icache_miss_i;
    end
end

assign pc_v_f1 = (~((predict_taken & ~btb_pred_f2_r))) | prev_predict_taken;

// stall logic
assign stall = ~pc_gen_fe_ready_i | (~pc_gen_icache_ready_i &  ~tlb_miss_v_i) | icache_miss_i;

assign icache_miss_recover = icache_miss_prev & (~icache_miss_i);
assign tlb_miss_recover    = tlb_miss_prev & (~tlb_miss_v_i);
   
// icache and  itlb miss recover logic
always_ff @(posedge clk_i)
begin
    if (reset_i)
    begin
        icache_miss_prev <= '0;
        tlb_miss_prev    <= '0;
        jump_second_half_prev <= '0;
    end
    else
    begin
        icache_miss_prev <= icache_miss_i;
        tlb_miss_prev    <= tlb_miss_v_i;
        jump_second_half_prev <= jump_second_half;
    end
end

logic [eaddr_width_p-1:0] btb_br_tgt_lo;
logic                     btb_br_tgt_v_lo;

bp_fe_branch_metadata_fwd_s fe_cmd_branch_metadata;
always_comb
  begin
     jump_second_half = 0;
     
    // if we need to redirect
    if (fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i) begin
        pc_n = fe_pc_gen_cmd.pc;
        if (pc_n[1]) //next pc has to be +2 rather than +4
          jump_second_half = 1;
    end
     else if (state_r == e_stall)
    begin
        pc_n = pc_resume;
        if (pc_n[1]) //next pc has to be +2 rather than +4
          jump_second_half = 1;
    end
    // if we've missed in the itlb
    else if (tlb_miss_recover)
    begin
        pc_n = pc_f1; 
    end
    // if we've missed in the icache
    else if (icache_miss_recover)
    begin
        pc_n = pc_f2;
    end
    else if (predict_taken && ~prev_cycle_jump)
    begin
        pc_n = br_target;
        if (pc_n[1]) //next pc has to be +2 rather than +4
          jump_second_half = 1;
    end
    else
      begin
        pc_n = jump_second_half_prev ?  pc_f1 + 2 : pc_f1 + 4;
    end
end

always_ff @(posedge clk_i)
begin
    if (reset_i) 
    begin
        pc_f2 <= '0;
        pc_v_f2 <= '0;
        pc_f1 <= '0;

        btb_pred_f1_r <= '0;
        btb_pred_f2_r <= '0;
        br_predict_taken_f1 <= 0;
        br_predict_taken_f2 <= 0;
    end
    else 
    begin
        if (~stall)
        begin
            pc_f2 <= pc_f1;
            pc_v_f2 <= pc_v_f1 & ~(fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i);
            pc_f1 <= pc_n;
            btb_pred_f1_r <= btb_br_tgt_v_lo;
            btb_pred_f2_r <= btb_pred_f1_r;
            br_predict_taken_f1 <= predict_taken;
            br_predict_taken_f2 <= br_predict_taken_f1;
           
        end
    end
end

assign fe_queue_branch_metadata = '{btb_tag: pc_gen_fetch.pc[2+btb_indx_width_p+:btb_tag_width_lp]
                                    , btb_indx: pc_gen_fetch.pc[2+:btb_indx_width_p]
                                    , default: '0
                                    };
bsg_dff_reset_en
 #(.width_p(branch_metadata_fwd_width_lp))
 branch_metadata_fwd_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i) 
   ,.en_i(pc_gen_fe_v_o)

   ,.data_i(fe_queue_branch_metadata)
   ,.data_o(fe_queue_branch_metadata_r)
   );


assign fe_cmd_branch_metadata = fe_pc_gen_cmd.branch_metadata_fwd;
bp_fe_btb
 #(.vaddr_width_p(vaddr_width_p)
   ,.btb_tag_width_p(btb_tag_width_p)
   ,.btb_idx_width_p(btb_indx_width_p)
   )
 btb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.r_addr_i(pc_n)
   ,.r_v_i(1'b1) //~stall)
   ,.br_tgt_o(btb_br_tgt_lo)
   ,.br_tgt_v_o(btb_br_tgt_v_lo)

   ,.w_tag_i(fe_cmd_branch_metadata.btb_tag) 
   ,.w_idx_i(fe_cmd_branch_metadata.btb_indx)
   ,.w_v_i(fe_pc_gen_cmd.pc_redirect_valid & fe_pc_gen_v_i & fe_pc_gen_ready_o)
   ,.br_tgt_i(fe_pc_gen_cmd.pc)
   );


   
for (genvar i = 0; i < 2; i++) begin
   instr_scan 
     #(.eaddr_width_p(eaddr_width_p)
       ,.instr_width_p(instr_width_p)
       ) 
   instr_scan_1 
     (.instr_i(instr[i])
      ,.scan_o(scan_instr[i])
      );
end
logic predict_taken_temp;   
always_comb begin: branch_target_handling
   taken = '0; 
   for (int unsigned i = 0; i < 2; i++) begin
      if (!taken[i]) begin
         is_rvi_br = icache_pc_gen_v_i & (scan_instr[i].instr_scan_class == e_rvi_branch);
         is_rvc_br = icache_pc_gen_v_i & (scan_instr[i].instr_scan_class == e_rvc_branch);
         is_rvi_jal = icache_pc_gen_v_i & (scan_instr[i].instr_scan_class == e_rvi_jal);
         is_rvc_jal = icache_pc_gen_v_i & (scan_instr[i].instr_scan_class == e_rvc_jal);
         br_target = addr[i] + scan_instr[i].imm; 
         is_back_br = scan_instr[i].imm[63];
         predict_taken_temp = pc_v_f2 & ((is_rvi_br & is_back_br) | (is_rvi_jal)) | ((is_rvc_br & is_back_br) | (is_rvc_jal)) & ~btb_pred_f1_r & icache_pc_gen_v_i;
         if(predict_taken_temp && ~(icache_pc_gen_v_i && br_predict_taken_f2 && (i==0) && (icache_pc_gen.addr[1:0] == 2'b10))) begin
            taken[i+1] = 1'b1;
            jump = 1'b1;
         end
         else
           jump = 0;
      end
   end
end 

   
assign predict_taken = taken[2] | (taken[1] & valid[0]);
always_ff @(posedge clk_i) begin

 if (reset_i || (fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i) || btb_br_tgt_v_lo || predict_taken) begin
    unaligned_instr_r.valid          <= 1'b0;

    unaligned_instr_r.address  <= '0;

    unaligned_instr_r.instr    <= '0;

 end else if (~pc_gen_fe_v_o) begin
    unaligned_instr_r.valid  <= unaligned_instr_r.valid ;

    unaligned_instr_r.address  <= unaligned_instr_r.address;

    unaligned_instr_r.instr    <= unaligned_instr_r.instr;

       end else begin // if (~reset_i)
          unaligned_instr_r.valid           <= unaligned_instr.valid ;

          unaligned_instr_r.address  <= unaligned_instr.address;

          unaligned_instr_r.instr    <= unaligned_instr.instr;

             end // else: !if(~reset_i)

   if (reset_i || (fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i)) begin
     prev_predict_taken <= 0;
     prev_br_target     <= '0;
     prev_pc_f2         <= 0;
     prev_cycle_jump    <= 0;      
   end else begin
     prev_predict_taken <= predict_taken;
     prev_br_target     <= br_target;
     prev_pc_f2         <= pc_f2;
     prev_cycle_jump    <= jump; 
   end
end

/*bsg_dff_reset_en
 #(.width_p(unaligned_instr_metadata_width_lp)
  ) unaligned_instr_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i || (fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i) || btb_br_tgt_v_lo || predict_taken)
   ,.en_i(pc_gen_fe_v_o)

   ,.data_i( unaligned_instr)
   ,.data_o( unaligned_instr_r)
   );
  */ 
endmodule
