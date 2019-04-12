module bp_be_nonsynth_tracer
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter num_core_p                  = "inv"
   , parameter num_lce_p                   = "inv"

   // Default parameters
   , parameter debug_file_p = "debug.log"

   // Calculated parameters
   , localparam mhartid_width_lp      = `BSG_SAFE_CLOG2(num_core_p)
   , localparam proc_cfg_width_lp     = `bp_proc_cfg_width(num_core_p, num_lce_p)
   , localparam issue_pkt_width_lp    = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam exception_width_lp    = `bp_be_exception_width

   // Constants
   , localparam pipe_stage_els_lp = 5

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [mhartid_width_lp-1:0]                          mhartid_i

   , input [issue_pkt_width_lp-1:0]                        issue_pkt_i
   , input                                                 issue_pkt_v_i

   , input [dispatch_pkt_width_lp-1:0]                     dispatch_pkt_i
   , input                                                 fe_nop_v_i
   , input                                                 be_nop_v_i
   , input                                                 me_nop_v_i

   , input [reg_data_width_lp-1:0]                         ex1_br_tgt_i
   , input                                                 ex1_btaken_i
   , input [reg_data_width_lp-1:0]                         iwb_result_i
   , input [reg_data_width_lp-1:0]                         fwb_result_i

   , input [pipe_stage_els_lp-1:0][exception_width_lp-1:0] cmt_trace_exc_i 
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );
// Cast input and output ports
bp_be_issue_pkt_s             issue_pkt;
bp_be_dispatch_pkt_s          dispatch_pkt;
bp_be_exception_s [pipe_stage_els_lp-1:0]             cmt_trace_exc;

assign issue_pkt = issue_pkt_i;
assign dispatch_pkt = dispatch_pkt_i;

assign cmt_trace_exc       = cmt_trace_exc_i;

wire                         unused0 = ex1_btaken_i;
wire [reg_data_width_lp-1:0] unused1 = fwb_result_i;

    bp_be_dispatch_pkt_s [pipe_stage_els_lp-1:0] dbg_stage_r;

    bsg_dff 
     #(.width_p(dispatch_pkt_width_lp*pipe_stage_els_lp))
     dbg_stage_reg
      (.clk_i(clk_i)
       ,.data_i({dbg_stage_r[0+:pipe_stage_els_lp-1], dispatch_pkt})
       ,.data_o(dbg_stage_r)
       );
     
    logic [reg_data_width_lp-1:0] iwb_br_tgt_r;
    bsg_shift_reg
     #(.width_p(reg_data_width_lp)
       ,.stages_p(2)
       )
     dbg_shift_reg
      (.clk(clk_i)
       ,.reset_i(reset_i)
       ,.valid_i(1'b1)
       ,.valid_o(/* We don't care */)
       ,.data_i(ex1_br_tgt_i)
       ,.data_o(iwb_br_tgt_r)
       );

    integer file;
    initial file = $fopen(debug_file_p, "w");

    logic booted_r;

    bsg_dff_reset_en
     #(.width_p(1))
     boot_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(issue_pkt_v_i)
       ,.data_i(1'b1)
       ,.data_o(booted_r)
       );

logic [4:0][2:0][7:0] stage_aliases;
assign stage_aliases = {"FWB", "IWB", "EX2", "EX1"};
always_ff @(posedge clk_i) begin
    if(booted_r) begin
            $fwrite(file, "-----\n");
            if (issue_pkt_v_i)
              $fwrite(file, "[ISS] core: %x pc: %x\n", mhartid_i, issue_pkt.instr_metadata.pc);

            if (fe_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (fe)\n", mhartid_i);
            else if (be_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (be)\n", mhartid_i);
            else if (me_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (me)\n", mhartid_i);
            else 
              $fwrite(file, "[ISD] core: %x pc: %x\n", mhartid_i, dispatch_pkt.instr_metadata.pc);

for (integer i = 0; i < 4; i++)
begin
            if (cmt_trace_exc[i].roll_v)
              $fwrite(file, "[%s] core: %x rolled\n", stage_aliases[i], mhartid_i);
            else if (cmt_trace_exc[i].poison_v)
              $fwrite(file, "[%s] core: %x poisoned\n", stage_aliases[i], mhartid_i);
            else if (~dbg_stage_r[i].decode.instr_v)
              $fwrite(file, "[%s] core: %x nop\n", stage_aliases[i], mhartid_i);
            else
              $fwrite(file, "[%s] core: %x pc: %x\n", stage_aliases[i], mhartid_i, dbg_stage_r[i].instr_metadata.pc);
end
            if(dbg_stage_r[2].decode.instr_v & ~cmt_trace_exc[2].poison_v) begin
                $fwrite(file, "[CMT] core: %x itag: %x pc: %x instr: %x\n"
                         ,mhartid_i
                         ,dbg_stage_r[2].instr_metadata.itag
                         ,dbg_stage_r[2].instr_metadata.pc
                         ,dbg_stage_r[2].instr
                         );
                if(dbg_stage_r[2].decode.csr_instr_v) begin
                     $fwrite(file, "\t\top: csr sem: r%d <- csr {%x}\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             );
                /*
                 * TODO: Add back in CSR printing
                if(dbg_stage_r[2].decode.mhartid_r_v) begin
                    $fwrite(file, "\t\top: csr sem: r%d <- mhartid {%x}\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.mtvec_rw_v) begin
                    $fwrite(file, "\t\top: csr sem: r%d <- mtvec {%x} r%d {%x} -> mtvec\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             ,dbg_stage_r[2].decode.rs1_addr
                             ,dbg_stage_r[2].rs1
                             );
                end else if(dbg_stage_r[2].decode.mepc_rw_v) begin
                    $fwrite(file, "\t\top: csr sem: r%d <- mepc {%x} r%d {%x} -> mepc\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             ,dbg_stage_r[2].decode.rs1_addr
                             ,dbg_stage_r[2].rs1
                             );
                end else if(dbg_stage_r[2].decode.mscratch_rw_v) begin
                    $fwrite(file, "\t\top: csr sem: r%d <- mscratch {%x} r%d {%x} -> mscratch\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             ,dbg_stage_r[2].decode.rs1_addr
                             ,dbg_stage_r[2].rs1
                             );
                end else if(dbg_stage_r[2].decode.mtval_rw_v) begin
                    $fwrite(file, "\t\top: csr sem: r%d <- mtval {%x} r%d {%x} -> mtval\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             ,dbg_stage_r[2].decode.rs1_addr
                             ,dbg_stage_r[2].rs1
                             );
                */
                end else if(dbg_stage_r[2].decode.ret_v) begin
                    $fwrite(file, "\t\top: ret\n");
                end else if(dbg_stage_r[2].decode.dcache_r_v) begin
                    $fwrite(file, "\t\top: load sem: r%d <- mem[%x] {%x}\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,dbg_stage_r[2].rs1 
                              + dbg_stage_r[2].imm
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.dcache_w_v) begin
                    if(dbg_stage_r[2].rs1
                       +dbg_stage_r[2].imm==64'hc00dead0) begin
                        if(dbg_stage_r[2].rs2[31:16]==16'h0000) begin
                            $fwrite(file, "[CORE%0x PAS] TEST_NUM=%x\n"
                                     ,mhartid_i
                                     ,dbg_stage_r[2].rs2[15:0]
                                     );
                        end else if(dbg_stage_r[2].rs2[31:16]==16'hFFFF) begin
                            $fwrite(file, "[CORE%0x FAL] TEST_NUM=%x\n"
                                     ,mhartid_i
                                     ,dbg_stage_r[2].rs2[15:0]
                                     );
                        end else begin
                            $fwrite(file, "[CORE%0x ERR] STORE TO 0xC00DEAD0, change test address\n"
                                     ,mhartid_i
                                     );
                        end
                    end else if(dbg_stage_r[2].rs1
                                +dbg_stage_r[2].imm==64'h8FFF_FFFF) begin
                        $fwrite(file, "[CORE%0x PRT] %x\n"
                                 ,mhartid_i
                                 ,dbg_stage_r[2].rs2[0+:8]
                                 );
                    end else if(dbg_stage_r[2].rs1
                                +dbg_stage_r[2].imm==64'h8FFF_EFFF) begin
                        $fwrite(file, "[CORE%0x PRT] %c\n"
                                 ,mhartid_i
                                 ,dbg_stage_r[2].rs2[0+:8]
                                 );
                    end else begin
                        $fwrite(file, "\t\top: store sem: mem[%x] <- r%d {%x}\n"
                                 ,dbg_stage_r[2].rs1 
                                  + dbg_stage_r[2].imm
                                 ,dbg_stage_r[2].decode.rs2_addr
                                 ,dbg_stage_r[2].rs2
                                 );   
                    end
                end else if(dbg_stage_r[2].decode.jmp_v) begin
                    $fwrite(file, "\t\top: jump sem: pc <- {%x}, r%d <- {%x}\n"
                             ,iwb_br_tgt_r
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.br_v) begin
                    // TODO: Expand on this trace to have all branch instructions
                    $fwrite(file, "\t\top: branch sem: pc <- {%x} rs1: %x cmp rs2: %x taken: %x\n"
                             ,iwb_br_tgt_r
                             ,dbg_stage_r[2].rs1
                             ,dbg_stage_r[2].rs2
                             ,iwb_result_i[0]
                             );
                end else if(dbg_stage_r[2].decode.irf_w_v) begin
                    // TODO: Expand on this trace to have all integer instructions
                    $fwrite(file, "\t\top: integer sem: r%d <- {%x}\n"
                             ,dbg_stage_r[2].decode.rd_addr
                             ,iwb_result_i
                             );
                end
            end
        end
    //end
end

endmodule : bp_be_nonsynth_tracer

