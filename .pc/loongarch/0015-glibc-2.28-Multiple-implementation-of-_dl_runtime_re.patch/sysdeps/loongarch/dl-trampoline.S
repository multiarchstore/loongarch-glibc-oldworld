/* Copyright (C) 2020-2021 Free Software Foundation, Inc.

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

#include <sysdep.h>
#include <sys/asm.h>

/* Assembler veneer called from the PLT header code for lazy loading.
   The PLT header passes its own args in t0-t2.  */

#ifdef __loongarch_soft_float
# define FRAME_SIZE (-((-10 * SZREG) & ALMASK))
#else
# define FRAME_SIZE (-((-10 * SZREG - 8 * SZFREG) & ALMASK))
#endif

ENTRY (_dl_runtime_resolve)
  # Save arguments to stack.

#ifdef __loongarch64
	addi.d	sp, sp, -FRAME_SIZE
#elif defined __loongarch32
	addi.w	sp, sp, -FRAME_SIZE
#endif

	REG_S	ra, sp, 9*SZREG
	REG_S	a0, sp, 1*SZREG
	REG_S	a1, sp, 2*SZREG
	REG_S	a2, sp, 3*SZREG
	REG_S	a3, sp, 4*SZREG
	REG_S	a4, sp, 5*SZREG
	REG_S	a5, sp, 6*SZREG
	REG_S	a6, sp, 7*SZREG
	REG_S	a7, sp, 8*SZREG

#ifndef __loongarch_soft_float
	FREG_S	fa0, sp, 10*SZREG + 0*SZFREG
	FREG_S	fa1, sp, 10*SZREG + 1*SZFREG
	FREG_S	fa2, sp, 10*SZREG + 2*SZFREG
	FREG_S	fa3, sp, 10*SZREG + 3*SZFREG
	FREG_S	fa4, sp, 10*SZREG + 4*SZFREG
	FREG_S	fa5, sp, 10*SZREG + 5*SZFREG
	FREG_S	fa6, sp, 10*SZREG + 6*SZFREG
	FREG_S	fa7, sp, 10*SZREG + 7*SZFREG
#endif

  # Update .got.plt and obtain runtime address of callee.
#ifdef __loongarch64
	slli.d	a1, t1, 1
	or	a0, t0, zero
	add.d	a1, a1, t1
	la	a2, _dl_fixup
	jirl	ra, a2, 0
	or	t1, v0, zero
#elif defined __loongarch32
	slli.w	a1, t1, 1
	or	a0, t0, zero
	add.w	a1, a1, t1
	la	a2, _dl_fixup
	jirl	ra, a2, 0
	or	t1, v0, zero
#endif

  # Restore arguments from stack.
	REG_L	ra, sp, 9*SZREG
	REG_L	a0, sp, 1*SZREG
	REG_L	a1, sp, 2*SZREG
	REG_L	a2, sp, 3*SZREG
	REG_L	a3, sp, 4*SZREG
	REG_L	a4, sp, 5*SZREG
	REG_L	a5, sp, 6*SZREG
	REG_L	a6, sp, 7*SZREG
	REG_L	a7, sp, 8*SZREG

#ifndef __loongarch_soft_float
	FREG_L	fa0, sp, 10*SZREG + 0*SZFREG
	FREG_L	fa1, sp, 10*SZREG + 1*SZFREG
	FREG_L	fa2, sp, 10*SZREG + 2*SZFREG
	FREG_L	fa3, sp, 10*SZREG + 3*SZFREG
	FREG_L	fa4, sp, 10*SZREG + 4*SZFREG
	FREG_L	fa5, sp, 10*SZREG + 5*SZFREG
	FREG_L	fa6, sp, 10*SZREG + 6*SZFREG
	FREG_L	fa7, sp, 10*SZREG + 7*SZFREG
#endif

#ifdef __loongarch64
	addi.d	sp, sp, FRAME_SIZE
#elif defined __loongarch32
	addi.w	sp, sp, FRAME_SIZE
#endif

  # Invoke the callee.
	jirl	zero, t1, 0
END (_dl_runtime_resolve)
