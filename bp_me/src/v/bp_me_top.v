/**
 *
 * Name:
 *   bp_me_top.v
 *
 * Description:
 *   This is the top level module for the Memory End of BlackParrot
 *
 */ 

module bp_me_top
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p                ="inv"
    , parameter num_cce_p              ="inv"
    , parameter paddr_width_p          ="inv"
    , parameter lce_assoc_p            ="inv"
    , parameter lce_sets_p             ="inv"
    , parameter block_size_in_bytes_p  ="inv"

    , parameter num_inst_ram_els_p     ="inv"//256

    , parameter mem_els_p              ="inv"//512
    , parameter boot_rom_width_p       ="inv"//512
    , parameter boot_rom_els_p         ="inv"//512

    // Default parameters
    , parameter harden_p               = 0

    // Derived parameters
    , localparam block_size_in_bits_lp = (block_size_in_bytes_p*8)
    , localparam lg_num_cce_lp         = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_boot_rom_els_lp    = `BSG_SAFE_CLOG2(boot_rom_els_p)
    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_inst_ram_els_p)

    , localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                               ,num_lce_p
                                                               ,paddr_width_p
                                                               ,lce_assoc_p)

    , localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                 ,num_lce_p
                                                                 ,paddr_width_p)

    , localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                           ,num_lce_p
                                                                           ,paddr_width_p
                                                                           ,block_size_in_bits_lp)

    , localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                               ,num_lce_p
                                                               ,paddr_width_p
                                                               ,lce_assoc_p)

    , localparam bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                         ,num_lce_p
                                                                         ,paddr_width_p
                                                                         ,block_size_in_bits_lp
                                                                         ,lce_assoc_p)

    , localparam bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                       ,paddr_width_p
                                                                       ,block_size_in_bits_lp
                                                                       ,lce_assoc_p)

    , localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p
                                                                 ,num_lce_p
                                                                 ,lce_assoc_p)

    , localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p
                                                                           ,block_size_in_bits_lp
                                                                           ,num_lce_p
                                                                           ,lce_assoc_p)

    , localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p
                                                               ,num_lce_p
                                                               ,lce_assoc_p)

    , localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p
                                                                         ,block_size_in_bits_lp
                                                                         ,num_lce_p
                                                                         ,lce_assoc_p)
  )
  (input  clk_i
   , input reset_i

   // LCE <-> Coherence Network Interface
   // inbound: ready->valid, helpful consumer
   , input [num_lce_p-1:0][bp_lce_cce_req_width_lp-1:0]                   lce_req_i
   , input [num_lce_p-1:0]                                                lce_req_v_i
   , output logic [num_lce_p-1:0]                                         lce_req_ready_o

   , input [num_lce_p-1:0][bp_lce_cce_resp_width_lp-1:0]                  lce_resp_i
   , input [num_lce_p-1:0]                                                lce_resp_v_i
   , output logic [num_lce_p-1:0]                                         lce_resp_ready_o

   , input [num_lce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0]             lce_data_resp_i
   , input [num_lce_p-1:0]                                                lce_data_resp_v_i
   , output logic [num_lce_p-1:0]                                         lce_data_resp_ready_o

   // outbound: ready->valid, demanding producer
   , output logic [num_lce_p-1:0][bp_cce_lce_cmd_width_lp-1:0]            lce_cmd_o
   , output logic [num_lce_p-1:0]                                         lce_cmd_v_o
   , input [num_lce_p-1:0]                                                lce_cmd_ready_i

   , output logic [num_lce_p-1:0][bp_cce_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
   , output logic [num_lce_p-1:0]                                         lce_data_cmd_v_o
   , input [num_lce_p-1:0]                                                lce_data_cmd_ready_i

   // LCE <-> LCE transfer networks
   , input [num_lce_p-1:0][bp_lce_lce_tr_resp_width_lp-1:0]               lce_tr_resp_i
   , input [num_lce_p-1:0]                                                lce_tr_resp_v_i
   , output logic [num_lce_p-1:0]                                         lce_tr_resp_ready_o

   , output logic [num_lce_p-1:0][bp_lce_lce_tr_resp_width_lp-1:0]        lce_tr_resp_o
   , output logic [num_lce_p-1:0]                                         lce_tr_resp_v_o
   , input [num_lce_p-1:0]                                                lce_tr_resp_ready_i

   , output logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0]                 boot_rom_addr_o
   , input logic [num_cce_p-1:0][boot_rom_width_p-1:0]                    boot_rom_data_i

   , output logic [inst_ram_addr_width_lp-1:0]                            cce_inst_boot_rom_addr_o
   , input [`bp_cce_inst_width-1:0]                                       cce_inst_boot_rom_data_i
  );

  // Coherence Network <-> CCE
  // To CCE
  logic [num_cce_p-1:0][bp_lce_cce_req_width_lp-1:0]            lce_req_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_req_v_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_req_ready_o_from_cce;

  logic [num_cce_p-1:0][bp_lce_cce_resp_width_lp-1:0]           lce_resp_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_resp_v_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_resp_ready_o_from_cce;

  logic [num_cce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0]      lce_data_resp_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_data_resp_v_i_to_cce;
  logic [num_cce_p-1:0]                                         lce_data_resp_ready_o_from_cce;

  // From CCE;
  logic [num_cce_p-1:0][bp_cce_lce_cmd_width_lp-1:0]            lce_cmd_o_from_cce;
  logic [num_cce_p-1:0]                                         lce_cmd_v_o_from_cce;
  logic [num_cce_p-1:0]                                         lce_cmd_ready_i_to_cce;

  logic [num_cce_p-1:0][bp_cce_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o_from_cce;
  logic [num_cce_p-1:0]                                         lce_data_cmd_v_o_from_cce;
  logic [num_cce_p-1:0]                                         lce_data_cmd_ready_i_to_cce;


  // Coherence Network
  bp_coherence_network
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_p)
      )
    network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      // CCE Command Network - (CCE->network->LCE)
      // (LCE side)
      ,.lce_cmd_o(lce_cmd_o)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      // (CCE side)
      ,.lce_cmd_i(lce_cmd_o_from_cce)
      ,.lce_cmd_v_i(lce_cmd_v_o_from_cce)
      ,.lce_cmd_ready_o(lce_cmd_ready_i_to_cce)

      // CCE Data Command Network - (CCE->network->LCE)
      // (LCE side)
      ,.lce_data_cmd_o(lce_data_cmd_o)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
      // (CCE side)
      ,.lce_data_cmd_i(lce_data_cmd_o_from_cce)
      ,.lce_data_cmd_v_i(lce_data_cmd_v_o_from_cce)
      ,.lce_data_cmd_ready_o(lce_data_cmd_ready_i_to_cce)

      // LCE Request Network - (LCE->network->CCE)
      // (LCE side)
      ,.lce_req_i(lce_req_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_ready_o(lce_req_ready_o)
      // (CCE side)
      ,.lce_req_o(lce_req_i_to_cce)
      ,.lce_req_v_o(lce_req_v_i_to_cce)
      ,.lce_req_ready_i(lce_req_ready_o_from_cce)

      // LCE Response Network - (LCE->network->CCE)
	    // (LCE side)
      ,.lce_resp_i(lce_resp_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_ready_o(lce_resp_ready_o)
      // (CCE side)
      ,.lce_resp_o(lce_resp_i_to_cce)
      ,.lce_resp_v_o(lce_resp_v_i_to_cce)
      ,.lce_resp_ready_i(lce_resp_ready_o_from_cce)

      // LCE Data Response Network - (LCE->network->CCE)
      // (LCE side)
      ,.lce_data_resp_i(lce_data_resp_i)
      ,.lce_data_resp_v_i(lce_data_resp_v_i)
      ,.lce_data_resp_ready_o(lce_data_resp_ready_o)
      // (CCE side)
      ,.lce_data_resp_o(lce_data_resp_i_to_cce)
      ,.lce_data_resp_v_o(lce_data_resp_v_i_to_cce)
      ,.lce_data_resp_ready_i(lce_data_resp_ready_o_from_cce)

      // LCE-LCE Transfer Network - (LCE(s)->network->LCE(d))
      // (LCE source side)
      ,.lce_tr_resp_i(lce_tr_resp_i)
      ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
      ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)
      // (LCE dest side)
      ,.lce_tr_resp_o(lce_tr_resp_o)
      ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
      ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
      );

  // CCE-MEM Interface
  logic [num_cce_p-1:0][bp_mem_cce_resp_width_lp-1:0]           mem_resp_i;
  logic [num_cce_p-1:0]                                         mem_resp_v_i;
  logic [num_cce_p-1:0]                                         mem_resp_ready_o;

  logic [num_cce_p-1:0][bp_mem_cce_data_resp_width_lp-1:0]      mem_data_resp_i;
  logic [num_cce_p-1:0]                                         mem_data_resp_v_i;
  logic [num_cce_p-1:0]                                         mem_data_resp_ready_o;

  logic [num_cce_p-1:0][bp_cce_mem_cmd_width_lp-1:0]            mem_cmd_o;
  logic [num_cce_p-1:0]                                         mem_cmd_v_o;
  logic [num_cce_p-1:0]                                         mem_cmd_yumi_i;

  logic [num_cce_p-1:0][bp_cce_mem_data_cmd_width_lp-1:0]       mem_data_cmd_o;
  logic [num_cce_p-1:0]                                         mem_data_cmd_v_o;
  logic [num_cce_p-1:0]                                         mem_data_cmd_yumi_i;

  logic [num_cce_p-1:0][lg_num_cce_lp-1:0] cce_id;
  for (genvar i = 0; i < num_cce_p; i++) begin
    localparam id = i;
    assign cce_id[i] = (lg_num_cce_lp)'(id);
    bp_cce_top
      #(.num_lce_p(num_lce_p)
        ,.num_cce_p(num_cce_p)
        ,.paddr_width_p(paddr_width_p)
        ,.lce_assoc_p(lce_assoc_p)
        ,.lce_sets_p(lce_sets_p)
        ,.block_size_in_bytes_p(block_size_in_bytes_p)
        ,.num_cce_inst_ram_els_p(num_inst_ram_els_p)
        ,.harden_p(harden_p)
        )
      bp_cce_top
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.cce_id_i(cce_id[i])

        ,.boot_rom_addr_o(cce_inst_boot_rom_addr_o)
        ,.boot_rom_data_i(cce_inst_boot_rom_data_i)

        // To CCE
        ,.lce_req_i(lce_req_i_to_cce[i])
        ,.lce_req_v_i(lce_req_v_i_to_cce[i])
        ,.lce_req_ready_o(lce_req_ready_o_from_cce[i])
        ,.lce_resp_i(lce_resp_i_to_cce[i])
        ,.lce_resp_v_i(lce_resp_v_i_to_cce[i])
        ,.lce_resp_ready_o(lce_resp_ready_o_from_cce[i])
        ,.lce_data_resp_i(lce_data_resp_i_to_cce[i])
        ,.lce_data_resp_v_i(lce_data_resp_v_i_to_cce[i])
        ,.lce_data_resp_ready_o(lce_data_resp_ready_o_from_cce[i])

        // From CCE
        ,.lce_cmd_o(lce_cmd_o_from_cce[i])
        ,.lce_cmd_v_o(lce_cmd_v_o_from_cce[i])
        ,.lce_cmd_ready_i(lce_cmd_ready_i_to_cce[i])
        ,.lce_data_cmd_o(lce_data_cmd_o_from_cce[i])
        ,.lce_data_cmd_v_o(lce_data_cmd_v_o_from_cce[i])
        ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i_to_cce[i])

        // To CCE
        ,.mem_resp_i(mem_resp_i[i])
        ,.mem_resp_v_i(mem_resp_v_i[i])
        ,.mem_resp_ready_o(mem_resp_ready_o[i])
        ,.mem_data_resp_i(mem_data_resp_i[i])
        ,.mem_data_resp_v_i(mem_data_resp_v_i[i])
        ,.mem_data_resp_ready_o(mem_data_resp_ready_o[i])

        // From CCE
        ,.mem_cmd_o(mem_cmd_o[i])
        ,.mem_cmd_v_o(mem_cmd_v_o[i])
        ,.mem_cmd_yumi_i(mem_cmd_yumi_i[i])
        ,.mem_data_cmd_o(mem_data_cmd_o[i])
        ,.mem_data_cmd_v_o(mem_data_cmd_v_o[i])
        ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i[i])
        );

    bp_mem
      #(.num_lce_p(num_lce_p)
        ,.num_cce_p(num_cce_p)
        ,.paddr_width_p(paddr_width_p)
        ,.lce_assoc_p(lce_assoc_p)
        ,.block_size_in_bytes_p(block_size_in_bytes_p)
        ,.lce_sets_p(lce_sets_p)
        ,.mem_els_p(mem_els_p)
        ,.boot_rom_width_p(boot_rom_width_p)
        ,.boot_rom_els_p(boot_rom_els_p)
        )
      bp_mem
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.mem_cmd_i(mem_cmd_o[i])
        ,.mem_cmd_v_i(mem_cmd_v_o[i])
        ,.mem_cmd_yumi_o(mem_cmd_yumi_i[i])
        ,.mem_data_cmd_i(mem_data_cmd_o[i])
        ,.mem_data_cmd_v_i(mem_data_cmd_v_o[i])
        ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_i[i])
        ,.mem_resp_o(mem_resp_i[i])
        ,.mem_resp_v_o(mem_resp_v_i[i])
        ,.mem_resp_ready_i(mem_resp_ready_o[i])
        ,.mem_data_resp_o(mem_data_resp_i[i])
        ,.mem_data_resp_v_o(mem_data_resp_v_i[i])
        ,.mem_data_resp_ready_i(mem_data_resp_ready_o[i])

        ,.boot_rom_addr_o(boot_rom_addr_o[i])
        ,.boot_rom_data_i(boot_rom_data_i[i])
        );
  end

endmodule
