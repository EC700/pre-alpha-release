TRACE_REPLAY ?= 1

DUT_PARAMS = -pvalue+vaddr_width_p=39                \
             -pvalue+paddr_width_p=56                \
             -pvalue+asid_width_p=10                 \
             -pvalue+btb_tag_width_p=9               \
             -pvalue+btb_idx_width_p=9               \
             -pvalue+bht_idx_width_p=5               \
             -pvalue+ras_idx_width_p=22             \
             -pvalue+num_core_p=1                    \
             -pvalue+num_cce_p=1                     \
             -pvalue+num_lce_p=2                     \
             -pvalue+lce_sets_p=64                   \
             -pvalue+cce_block_size_in_bytes_p=64    \
             -pvalue+cce_num_inst_ram_els_p=256      \
             -pvalue+lce_assoc_p=8                   \
						 -pvalue+trace_p=$(TRACE_REPLAY)         \
						 -pvalue+cfg_string_p=\'bp_single_core\'

TB_PARAMS =  -pvalue+trace_ring_width_p=129          \
             -pvalue+trace_rom_addr_width_p=32       \
             -pvalue+boot_rom_els_p=512              \
             -pvalue+boot_rom_width_p=512            \
						 -pvalue+mem_els_p=512

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS)
