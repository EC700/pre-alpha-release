/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 */

#include <sbi/riscv_encoding.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_platform.h>

/*
 * Include these files as needed.
 * See config.mk PLATFORM_xxx configuration parameters.
 */
#include <plat/irqchip/plic.h>
#include <plat/serial/uart8250.h>
#include <plat/sys/clint.h>

/*
 * Platform early initialization.
 */
static int blackparrot_early_init(bool cold_boot)
{
	return 0;
}

/*
 * Platform final initialization.
 */
static int blackparrot_final_init(bool cold_boot)
{
	return 0;
}

/*
 * Get number of PMP regions for given HART.
 */
static u32 blackparrot_pmp_region_count(u32 hartid)
{
	return 0;
}

/*
 * Get PMP regions details (namely: protection, base address, and size) for
 * a given HART.
 */
static int blackparrot_pmp_region_info(u32 hartid, u32 index,
				    ulong *prot, ulong *addr, ulong *log2size)
{
	return 0;
}

/*
 * Initialize the platform console.
 */
static int blackparrot_console_init(void)
{
	/* Example if the generic UART8250 driver is used */
    return 0;
}

/*
 * Write a character to the platform console output.
 */
static void blackparrot_console_putc(char ch)
{
	/* Example if the generic UART8250 driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Read a character from the platform console input.
 */
static int blackparrot_console_getc(void)
{
	return 0;
}

/*
 * Initialize the platform interrupt controller for current HART.
 */
static int blackparrot_irqchip_init(bool cold_boot)
{
    return 0;
}

/*
 * Initialize IPI for current HART.
 */
static int blackparrot_ipi_init(bool cold_boot)
{
    return 0;
}

/*
 * Send IPI to a target HART
 */
static void blackparrot_ipi_send(u32 target_hart)
{
	/* Example if the generic CLINT driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Wait for target HART to acknowledge IPI.
 */
static void blackparrot_ipi_sync(u32 target_hart)
{
	/* Example if the generic CLINT driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Clear IPI for a target HART.
 */
static void blackparrot_ipi_clear(u32 target_hart)
{
	/* Example if the generic CLINT driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Initialize platform timer for current HART.
 */
static int blackparrot_timer_init(bool cold_boot)
{
    return 0;
}

/*
 * Get platform timer value.
 */
static u64 blackparrot_timer_value(void)
{
	/* Example if the generic CLINT driver is used */
	return 0; 
}

/*
 * Start platform timer event for current HART.
 */
static void blackparrot_timer_event_start(u64 next_event)
{
	/* Example if the generic CLINT driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Stop platform timer event for current HART.
 */
static void blackparrot_timer_event_stop(void)
{
	/* Example if the generic CLINT driver is used */
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
}

/*
 * Reboot the platform.
 */
static int blackparrot_system_reboot(u32 type)
{
	return 0;
}

/*
 * Shutdown or poweroff the platform.
 */
static int blackparrot_system_shutdown(u32 type)
{
	return 0;
}

/*
 * Platform descriptor.
 */
const struct sbi_platform platform = {

	.name = "blackparrot",
	.features = SBI_PLATFORM_DEFAULT_FEATURES,
	.hart_count = 1,
	.hart_stack_size = 4096,
	.disabled_hart_mask = 0,

	.early_init = blackparrot_early_init,
	.final_init = blackparrot_final_init,

	.pmp_region_count = blackparrot_pmp_region_count,
	.pmp_region_info = blackparrot_pmp_region_info,

	.console_init = blackparrot_console_init,
	.console_putc = blackparrot_console_putc,
	.console_getc = blackparrot_console_getc,

	.irqchip_init = blackparrot_irqchip_init,
	.ipi_init = blackparrot_ipi_init,
	.ipi_send = blackparrot_ipi_send,
	.ipi_sync = blackparrot_ipi_sync,
	.ipi_clear = blackparrot_ipi_clear,

	.timer_init = blackparrot_timer_init,
	.timer_value = blackparrot_timer_value,
	.timer_event_start = blackparrot_timer_event_start,
	.timer_event_stop = blackparrot_timer_event_stop,

	.system_reboot = blackparrot_system_reboot,
	.system_shutdown = blackparrot_system_shutdown
};

