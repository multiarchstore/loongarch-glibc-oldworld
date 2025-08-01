/* Save and set current context.
   Copyright (C) 2009-2018 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <http://www.gnu.org/licenses/>.  */

#include "ucontext-macros.h"

/* int swapcontext (ucontext_t *oucp, const ucontext_t *ucp) */

LEAF (__swapcontext, 3)
	ori 	a2, sp, 0		/* Save sp to a2. */
	addi.d	sp, sp, -16
	st.d	a1, sp, 0
	ori 	t0, a1, 0	

	SAVE_INT_REG (ra,   1, a0)
	SAVE_INT_REG (a2,   3, a0)      /* Store sp .*/
	SAVE_INT_REG (zero,  4, a0)	/* return 0 by overwriting a0.  */
	SAVE_INT_REG (x,  21, a0)
	SAVE_INT_REG (fp,  22, a0)
	SAVE_INT_REG (s0,  23, a0)
	SAVE_INT_REG (s1,  24, a0)
	SAVE_INT_REG (s2,  25, a0)
	SAVE_INT_REG (s3,  26, a0)
	SAVE_INT_REG (s4,  27, a0)
	SAVE_INT_REG (s5,  28, a0)
	SAVE_INT_REG (s6,  29, a0)
	SAVE_INT_REG (s7,  30, a0)
	SAVE_INT_REG (s8,  31, a0)
	st.d ra, a0, MCONTEXT_PC
#ifndef __loongarch_soft_float
	movfcsr2gr a1, $r0

	SAVE_FP_REG (fs0,  24, a0)
	SAVE_FP_REG (fs1,  25, a0)
	SAVE_FP_REG (fs2,  26, a0)
	SAVE_FP_REG (fs3,  27, a0)
	SAVE_FP_REG (fs4,  28, a0)
	SAVE_FP_REG (fs5,  29, a0)
	SAVE_FP_REG (fs6,  30, a0)
	SAVE_FP_REG (fs7,  31, a0)

	st.w	a1, a0, MCONTEXT_FCSR
#endif /* __loongarch_soft_float */

/* rt_sigprocmask (SIG_SETMASK, &ucp->uc_sigmask, &oucp->uc_sigmask, _NSIG8) */
	li.d	a3, _NSIG8
	addi.d	a2, a0, UCONTEXT_SIGMASK
	addi.d  a1, t0, UCONTEXT_SIGMASK
	li.d	a0, SIG_SETMASK

	li.d	a7, SYS_ify (rt_sigprocmask)
	syscall 0

	blt	a0, zero, 99f

#ifndef __loongarch_soft_float
	ld.d	t0, sp, 0		/* Load a1 to t0. */
	ld.w	t1, t0, MCONTEXT_FCSR

	RESTORE_FP_REG (fs0,  24, t0)
	RESTORE_FP_REG (fs1,  25, t0)
	RESTORE_FP_REG (fs2,  26, t0)
	RESTORE_FP_REG (fs3,  27, t0)
	RESTORE_FP_REG (fs4,  28, t0)
	RESTORE_FP_REG (fs5,  29, t0)
	RESTORE_FP_REG (fs6,  30, t0)
	RESTORE_FP_REG (fs7,  31, t0)

	movgr2fcsr	$r0, t1
#endif /* __loongarch_soft_float */

	/* Note the contents of argument registers will be random
	   unless makecontext() has been called.  */
	RESTORE_INT_REG (ra,   1, t0)
	RESTORE_INT_REG (sp,   3, t0)
	RESTORE_INT_REG (a0,   4, t0)
	RESTORE_INT_REG (a1,   5, t0)
	RESTORE_INT_REG (a2,   6, t0)
	RESTORE_INT_REG (a3,   7, t0)
	RESTORE_INT_REG (a4,   8, t0)
	RESTORE_INT_REG (a5,   9, t0)
	RESTORE_INT_REG (a6,  10, t0)
	RESTORE_INT_REG (a7,  11, t0)
	RESTORE_INT_REG (x,  21, t0)
	RESTORE_INT_REG (fp,  22, t0)
	RESTORE_INT_REG (s0,  23, t0)
	RESTORE_INT_REG (s1,  24, t0)
	RESTORE_INT_REG (s2,  25, t0)
	RESTORE_INT_REG (s3,  26, t0)
	RESTORE_INT_REG (s4,  27, t0)
	RESTORE_INT_REG (s5,  28, t0)
	RESTORE_INT_REG (s6,  29, t0)
	RESTORE_INT_REG (s7,  30, t0)
	RESTORE_INT_REG (s8,  31, t0)
	ld.d t1, t0, MCONTEXT_PC

	jirl	$r0, t1, 0


99:	
	addi.d	sp, sp, 16
	b	__syscall_error

PSEUDO_END (__swapcontext)

weak_alias (__swapcontext, swapcontext)
