/* Run-time dynamic linker data structures for loaded ELF shared objects.
   Copyright (C) 2011-2018 Free Software Foundation, Inc.
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

#ifndef _LOONGARCH_LDSODEFS_H
#define _LOONGARCH_LDSODEFS_H 1

#include <elf.h>

struct La_loongarch_regs;
struct La_loongarch_retval;

#define ARCH_PLTENTER_MEMBERS						\
    ElfW(Addr) (*loongarch_gnu_pltenter) (ElfW(Sym) *, unsigned int,	\
				      uintptr_t *, uintptr_t *,		\
				      const struct La_loongarch_regs *,	\
				      unsigned int *, const char *name,	\
				      long int *framesizep);

#define ARCH_PLTEXIT_MEMBERS						\
    unsigned int (*loongarch_gnu_pltexit) (ElfW(Sym) *, unsigned int,	\
				       uintptr_t *, uintptr_t *,	\
				       const struct La_loongarch_regs *,	\
				       struct La_loongarch_retval *,	\
				       const char *);

/* The LoongArch ABI specifies that the dynamic section has to be read-only.  */

#define DL_RO_DYN_SECTION 1

#include_next <ldsodefs.h>

#endif
