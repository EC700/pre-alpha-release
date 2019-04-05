DUT_PARAMS= \
           -pvalue+vaddr_width_p=39               \
           -pvalue+paddr_width_p=56               \
           -pvalue+asid_width_p=10                \
           -pvalue+btb_tag_width_p=10             \
           -pvalue+btb_idx_width_p=5             \
           -pvalue+bht_idx_width_p=5             \
           -pvalue+ras_idx_width_p=1             \
           -pvalue+num_lce_p=1                    \
           -pvalue+num_cce_p=1                    \
           -pvalue+lce_sets_p=64                  \
           -pvalue+lce_assoc_p=8                  \
           -pvalue+cce_block_size_in_bytes_p=64   \
           "-pvalue+bp_first_pc_p=32\'h80000124"

TB_PARAMS= \
           -pvalue+num_core_p=1                   \
           -pvalue+eaddr_width_p=64               \
           -pvalue+branch_metadata_fwd_width_p=21 \
           -pvalue+cce_num_inst_ram_els_p=256     \
           -pvalue+boot_rom_width_p=512           \
           -pvalue+boot_rom_els_p=512             \
           -pvalue+trace_ring_width_p=96          \
           -pvalue+mem_els_p=512                  \
           -pvalue+trace_rom_addr_width_p=32

HDL_DEFINES = +define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

