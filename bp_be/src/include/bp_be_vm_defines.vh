
`ifndef BP_BE_VM_DEFINES_VH
`define BP_BE_VM_DEFINES_VH

`define declare_bp_sv39_pte_s                                            \
  typedef struct packed {                                                \
    logic [bp_sv39_pte_width_gp-10-bp_sv39_paddr_width_gp-1:0] reserved; \
    logic [bp_sv39_paddr_width_gp-1:0] ppn;                              \
    logic [1:0] rsw;                                                     \
    logic d;                                                             \
    logic a;                                                             \
    logic g;                                                             \
    logic u;                                                             \
    logic x;                                                             \
    logic w;                                                             \
    logic r;                                                             \
    logic v;                                                             \
  } bp_sv39_pte_s                                                

  
`define declare_bp_be_tlb_entry_s(ptag_width_mp) \
  typedef struct packed {                        \
    logic [ptag_width_mp-1:0]  ptag;             \
    logic                      g;                \
    logic                      u;                \
    logic                      x;                \
    logic                      w;                \
    logic                      r;                \
  } bp_be_tlb_entry_s                            
  
`define bp_be_tlb_entry_width(ptag_width_mp)     \
  (ptag_width_mp + 5)                            
  
`endif
