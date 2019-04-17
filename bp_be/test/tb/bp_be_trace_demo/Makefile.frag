TRACE_REPLAY ?= 1
CALC_DEBUG   ?= 1

TB_PARAMS = -pvalue+boot_rom_els_p=512                   \
            -pvalue+boot_rom_width_p=512                 \
            -pvalue+trace_ring_width_p=129               \
            -pvalue+trace_rom_addr_width_p=32            \
            -pvalue+mem_els_p=512

DUT_PARAMS = -pvalue+trace_p=$(TRACE_REPLAY) \
						 -pvalue+calc_debug_p=$(CALC_DEBUG)

HDL_DEFINES = +define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

