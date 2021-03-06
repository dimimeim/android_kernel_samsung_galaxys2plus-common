/*****************************************************************************
* arch/arm/mach-capri/capri_dormant_entry.S
*
* Copyright 2003 - 2012 Broadcom Corporation.  All rights reserved.
*
* Unless you and Broadcom execute a separate written software license
* agreement governing use of this software, this software is licensed to you
* under the terms of the GNU General Public License version 2, available at
* http://www.broadcom.com/licenses/GPLv2.php (the "GPL").
*
* Notwithstanding the above, under no circumstances may you combine this
* software in any way with any other Broadcom software provided under a
* license other than the GPL, without Broadcom's express prior written
* consent.
*****************************************************************************/

#include <linux/linkage.h>
#include <asm/assembler.h>

	.text

	.equ DORMANT_NOT_ENTERED, 0
	.equ DORMANT_ENTERED, 1

ENTRY(dormant_enter_prepare)
	stmfd	sp!, { r4 - r12, lr } @ save regs that could be corrupted
	ldr	r3, =saved_virtual_sp
#ifdef CONFIG_SMP
	ALT_SMP(mrc p15, 0, r2, c0, c0, 5)
	ALT_UP(mov r2, #0)
	and	r2, r2, #15
	str	sp, [r3, r2, lsl #2]	@ save the virtual stack pointer
#else
	str	sp, [r3]	@ save the virtual stack pointer
#endif

	/* Push the current SP to the un-cached stack and use the
	un-cached stack from now on */
	stmfd r0!, {sp}
	mov sp, r0

	ldr	r3, =restore_and_return
	bl	cpu_suspend	@ set-up to be ready to suspend

	ldr	r3, =saved_virtual_sp
#ifdef CONFIG_SMP
	ALT_SMP(mrc p15, 0, r2, c0, c0, 5)
	ALT_UP(mov r2, #0)
	and	r2, r2, #15
	ldr	sp, [r3, r2, lsl #2]	@ restore the saved virtual sp
#else
	ldr	sp, [r3]		@ restore the saved virtual sp
#endif

	/* Just returned from cleaning the cache */
	bl dormant_enter_continue

	/* Return a failure response since this is a fall through */
	mov	r0, #DORMANT_NOT_ENTERED
	ldmfd	sp!, { r4 - r12, pc}	@return to the caller

	/*
	 * We must have come here through cpu_resume.  i.e a reset
	 * occured, let us return a success value
	 *
	 */
restore_and_return:
	ALT_SMP(mrc p15, 0, r0, c0, c0, 5)
	ALT_UP(mov r0, #0)
	and	r0, r0, #15
	cmp r0, #0
infinite_loop:
	@beq infinite_loop

	mov	r0, #DORMANT_ENTERED
	ldmfd	sp!, {r0}
	mov		sp, r0
	ldmfd	sp!, { r4 - r12, pc}

ENTRY(invalidate_tlb_btac)
	stmfd	sp!, { lr }

	/* Invalidate the TLBs & BTAC */
	mov r0, #0
	mcr p15, 0, r0, c8, c3, 0   @ invalidate shared TLBs
	mcr p15, 0, r0, c7, c1, 6   @ invalidate shared BTAC
	dsb
	isb

	ldmfd	sp!, { pc }
ENDPROC(invalidate_tlb_btac)

	.data
	.align
saved_virtual_sp:
	.rept	CONFIG_NR_CPUS
	.long	0				@ virtual sp
	.endr
