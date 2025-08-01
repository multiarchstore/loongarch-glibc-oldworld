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

#ifndef dl_machine_h
#define dl_machine_h

#define ELF_MACHINE_NAME "LoongArch"

#if HAVE_TUNABLES
#define TUNABLE_NAMESPACE cpu
#include <elf/dl-tunables.h>
extern void TUNABLE_CALLBACK (set_hwcaps) (tunable_val_t *) attribute_hidden;
#endif

#include <entry.h>
#include <elf/elf.h>
#include <sys/asm.h>
#include <dl-tls.h>
#include <cpu-features.c>


#ifndef _RTLD_PROLOGUE
# define _RTLD_PROLOGUE(entry)						\
	".globl\t" __STRING (entry) "\n\t"				\
	".type\t" __STRING (entry) ", @function\n\t"			\
	CFI_STARTPROC "\n"						\
	__STRING (entry) ":\n"
#endif

#ifndef _RTLD_EPILOGUE
# define _RTLD_EPILOGUE(entry)						\
	CFI_ENDPROC "\n\t"						\
	".size\t" __STRING (entry) ", . - " __STRING (entry) "\n"
#endif

#define ELF_MACHINE_JMP_SLOT R_LARCH_JUMP_SLOT
#define ELF_MACHINE_IRELATIVE R_LARCH_IRELATIVE

#define elf_machine_type_class(type)				\
  ((ELF_RTYPE_CLASS_PLT * ((type) == ELF_MACHINE_JMP_SLOT	\
     || (__WORDSIZE == 32 && (type) == R_LARCH_TLS_DTPREL32)	\
     || (__WORDSIZE == 32 && (type) == R_LARCH_TLS_DTPMOD32)	\
     || (__WORDSIZE == 32 && (type) == R_LARCH_TLS_TPREL32)	\
     || (__WORDSIZE == 64 && (type) == R_LARCH_TLS_DTPREL64)	\
     || (__WORDSIZE == 64 && (type) == R_LARCH_TLS_DTPMOD64)	\
     || (__WORDSIZE == 64 && (type) == R_LARCH_TLS_TPREL64)))	\
   | (ELF_RTYPE_CLASS_COPY * ((type) == R_LARCH_COPY)))

#define ELF_MACHINE_NO_REL 1
#define ELF_MACHINE_NO_RELA 0

#define DL_PLATFORM_INIT dl_platform_init ()

static inline void __attribute__ ((unused))
dl_platform_init (void)
{
  if (GLRO(dl_platform) != NULL && *GLRO(dl_platform) == '\0')
    /* Avoid an empty string which would disturb us.  */
    GLRO(dl_platform) = NULL;

#ifdef SHARED
  /* init_cpu_features has been called early from __libc_start_main in
     static executable.  */
  init_cpu_features (&GLRO(dl_larch_cpu_features));

#if HAVE_TUNABLES
  TUNABLE_GET (hwcaps, tunable_val_t *, TUNABLE_CALLBACK (set_hwcaps));
#endif

#endif
}


/* Return nonzero iff ELF header is compatible with the running host.  */
static inline int __attribute_used__
elf_machine_matches_host (const ElfW(Ehdr) *ehdr)
{
  /* We can only run LoongArch binaries.  */
  if (ehdr->e_machine != EM_LOONGARCH)
    return 0;

#ifdef _ABILP64
  if ((ehdr->e_flags & EF_LARCH_ABI) != EF_LARCH_ABI_LP64)
#elif defined _ABILP32
  if ((ehdr->e_flags & EF_LARCH_ABI) != EF_LARCH_ABI_LP32)
#else
# error "Unknown ABI"
#endif
    return 0;

  return 1;
}

/* Runtime address of .got */
#define _GLOBAL_OFFSET_TABLE_ ({ \
  ElfW(Addr) *r; \
  asm ("la.pcrel %0, _GLOBAL_OFFSET_TABLE_":"=r" (r)); \
  r; \
})

/* Return the link-time address of _DYNAMIC.  */
static inline ElfW(Addr)
elf_machine_dynamic (void)
{
  return _GLOBAL_OFFSET_TABLE_[0];
}

#define STRINGXP(X) __STRING (X)
#define STRINGXV(X) STRINGV_ (X)
#define STRINGV_(...) # __VA_ARGS__

/* Return the run-time load address of the shared object.  */
static inline ElfW(Addr)
elf_machine_load_address (void)
{
  ElfW(Addr) got_linktime_addr;
  asm (
    "la.got %0, _GLOBAL_OFFSET_TABLE_"
    /* Link-time address in GOT entry before runtime relocation */
    : "=r" (got_linktime_addr)
  );
  return (ElfW(Addr))_GLOBAL_OFFSET_TABLE_ - got_linktime_addr;
}

/* Initial entry point code for the dynamic linker.
   The C function `_dl_start' is the real entry point;
   its return value is the user program's entry point.  */

#define RTLD_START asm (\
	".text\n\
	" _RTLD_PROLOGUE (ENTRY_POINT) "\
	.cfi_label .Ldummy\n\
	" CFI_UNDEFINED (1) "\n\
	or	$a0, $sp, $zero\n\
	bl	_dl_start\n\
	# Stash user entry point in s0.\n\
	or	$s0, $v0, $zero\n\
	# See if we were run as a command with the executable file\n\
	# name as an extra leading argument.\n\
	la	$a0, _dl_skip_args\n\
	ld.w	$a0, $a0, 0\n\
	# Load the original argument count.\n\
	ld.d	$a1, $sp, 0\n\
	# Subtract _dl_skip_args from it.\n\
	sub.d	$a1, $a1, $a0\n\
	# Adjust the stack pointer to skip _dl_skip_args words.\n\
	slli.d	$a0, $a0, 3\n\
	add.d	$sp, $sp, $a0\n\
	# Save back the modified argument count.\n\
	st.d	$a1, $sp, 0\n\
	# Call _dl_init (struct link_map *main_map, int argc, char **argv, char **env) \n\
	la	$a0, _rtld_local\n\
	ld.d	$a0, $a0, 0\n\
	addi.d	$a2, $sp, 8\n\
	slli.d	$a3, $a1, 3\n\
	add.d	$a3, $a3, $a2\n\
	addi.d	$a3, $a3, 8\n\
	# Adjust $sp for 16-aligned\n\
	srli.d  $t0, $sp, 4\n\
	slli.d  $t0, $t0, 4\n\
	ori	$t1, $sp, 0\n\
	addi.d  $sp, $t0, -32\n\
	st.d	$t1, $sp, 24\n\
	# Call the function to run the initializers.\n\
	bl	_dl_init\n\
	# Pass our finalizer function to _start.\n\
	ld.d    $sp, $sp, 24\n\
	la	$a0, _dl_fini\n\
	# Jump to the user entry point.\n\
	jirl	$zero, $s0, 0\n\
	" _RTLD_EPILOGUE (ENTRY_POINT) "\
	.previous" \
);

/* Names of the architecture-specific auditing callback functions.  */
#define ARCH_LA_PLTENTER loongarch_gnu_pltenter
#define ARCH_LA_PLTEXIT loongarch_gnu_pltexit

/* Bias .got.plt entry by the offset requested by the PLT header.  */
#define elf_machine_plt_value(map, reloc, value) (value)

static inline ElfW(Addr)
elf_machine_fixup_plt (struct link_map *map, lookup_t t,
		       const ElfW(Sym) *refsym, const ElfW(Sym) *sym,
		       const ElfW(Rela) *reloc,
		       ElfW(Addr) *reloc_addr, ElfW(Addr) value)
{
  return *reloc_addr = value;
}

#endif /* !dl_machine_h */

#ifdef RESOLVE_MAP

/* Perform a relocation described by R_INFO at the location pointed to
   by RELOC_ADDR.  SYM is the relocation symbol specified by R_INFO and
   MAP is the object containing the reloc.  */

auto inline void
__attribute__ ((always_inline))
elf_machine_rela (struct link_map *map, const ElfW(Rela) *reloc,
		  const ElfW(Sym) *sym, const struct r_found_version *version,
		  void *const reloc_addr, int skip_ifunc)
{
  ElfW(Addr) r_info = reloc->r_info;
  const unsigned long int r_type = ELFW (R_TYPE) (r_info);
  ElfW(Addr) *addr_field = (ElfW(Addr) *) reloc_addr;
  const ElfW(Sym) *const __attribute__ ((unused)) refsym = sym;
  struct link_map *sym_map = RESOLVE_MAP (&sym, version, r_type);
  ElfW(Addr) value = 0;
  if (sym_map != NULL)
    value = SYMBOL_ADDRESS (sym_map, sym, true) + reloc->r_addend;

  if (sym != NULL
      && __builtin_expect (ELFW(ST_TYPE) (sym->st_info) == STT_GNU_IFUNC, 0)
      && __builtin_expect (sym->st_shndx != SHN_UNDEF, 1)
      && __builtin_expect (!skip_ifunc, 1))
    value = ((ElfW(Addr) (*) (int)) value) (GLRO(dl_hwcap));

  switch (r_type)
    {
#ifndef RTLD_BOOTSTRAP
    case __WORDSIZE == 64 ? R_LARCH_TLS_DTPMOD64 : R_LARCH_TLS_DTPMOD32:
      if (sym_map)
	*addr_field = sym_map->l_tls_modid;
      break;

    case __WORDSIZE == 64 ? R_LARCH_TLS_DTPREL64 : R_LARCH_TLS_DTPREL32:
      if (sym != NULL)
	*addr_field = TLS_DTPREL_VALUE (sym) + reloc->r_addend;
      break;

    case __WORDSIZE == 64 ? R_LARCH_TLS_TPREL64 : R_LARCH_TLS_TPREL32:
      if (sym != NULL)
	{
	  CHECK_STATIC_TLS (map, sym_map);
	  *addr_field = TLS_TPREL_VALUE (sym_map, sym) + reloc->r_addend;
	}
      break;

    case R_LARCH_COPY:
      {
	if (__glibc_unlikely (sym == NULL))
	  /* This can happen in trace mode if an object could not be
	     found.  */
	  break;

	/* Handle TLS copy relocations.  */
	if (__glibc_unlikely (ELFW (ST_TYPE) (sym->st_info) == STT_TLS))
	  {
	    /* There's nothing to do if the symbol is in .tbss.  */
	    if (__glibc_likely (sym->st_value >= sym_map->l_tls_initimage_size))
	      break;
	    value += (ElfW(Addr)) sym_map->l_tls_initimage - sym_map->l_addr;
	  }

	size_t size = sym->st_size;
	if (__glibc_unlikely (sym->st_size != refsym->st_size))
	  {
	    const char *strtab = (const void *) D_PTR (map, l_info[DT_STRTAB]);
	    if (sym->st_size > refsym->st_size)
	      size = refsym->st_size;
	    if (sym->st_size > refsym->st_size || GLRO(dl_verbose))
	      _dl_error_printf ("\
  %s: Symbol `%s' has different size in shared object, consider re-linking\n",
				rtld_progname ?: "<program name unknown>",
				strtab + refsym->st_name);
	  }

	memcpy (reloc_addr, (void *)value, size);
	break;
      }
#endif

#if !defined RTLD_BOOTSTRAP || !defined HAVE_Z_COMBRELOC
    case R_LARCH_RELATIVE:
      {
# if !defined RTLD_BOOTSTRAP && !defined HAVE_Z_COMBRELOC
	/* This is defined in rtld.c, but nowhere in the static libc.a;
	   make the reference weak so static programs can still link.
	   This declaration cannot be done when compiling rtld.c
	   (i.e. #ifdef RTLD_BOOTSTRAP) because rtld.c contains the
	   common defn for _dl_rtld_map, which is incompatible with a
	   weak decl in the same file.  */
#  ifndef SHARED
	weak_extern (GL(dl_rtld_map));
#  endif
	if (map != &GL(dl_rtld_map)) /* Already done in rtld itself.  */
# endif
	  *addr_field = map->l_addr + reloc->r_addend;
      break;
    }
#endif

    case R_LARCH_JUMP_SLOT:
    case __WORDSIZE == 64 ? R_LARCH_64 : R_LARCH_32:
      *addr_field = value;
      break;

    case R_LARCH_IRELATIVE:
      value = map->l_addr + reloc->r_addend;
      if (__glibc_likely (!skip_ifunc))
	value = ((ElfW(Addr) (*) (void)) value) ();
      *addr_field = value;
      break;

    case R_LARCH_NONE:
      break;

    default:
      _dl_reloc_bad_type (map, r_type, 0);
      break;
    }
}

auto inline void
__attribute__ ((always_inline))
elf_machine_rela_relative (ElfW(Addr) l_addr, const ElfW(Rela) *reloc,
			  void *const reloc_addr)
{
  *(ElfW(Addr) *) reloc_addr = l_addr + reloc->r_addend;
}

auto inline void
__attribute__ ((always_inline))
elf_machine_lazy_rel (struct link_map *map, ElfW(Addr) l_addr,
		      const ElfW(Rela) *reloc, int skip_ifunc)
{
  ElfW(Addr) *const reloc_addr = (void *) (l_addr + reloc->r_offset);
  const unsigned int r_type = ELFW (R_TYPE) (reloc->r_info);

  /* Check for unexpected PLT reloc type.  */
  if (__glibc_likely (r_type == R_LARCH_JUMP_SLOT))
    {
      if (__glibc_unlikely (map->l_mach.plt == 0))
	{
	  if (l_addr)
	    *reloc_addr += l_addr;
	}
      else
	*reloc_addr = map->l_mach.plt;
    }
  else if (__glibc_unlikely (r_type == R_LARCH_IRELATIVE))
    {
      ElfW(Addr) *value = (void *) (l_addr + reloc->r_addend);
      if (__glibc_likely (!skip_ifunc))
	value = (ElfW(Addr) *)((ElfW(Addr) (*) (void)) value) ();
      *reloc_addr = (ElfW(Addr))value;
}
  else
    _dl_reloc_bad_type (map, r_type, 1);
}

/* Set up the loaded object described by L so its stub function
   will jump to the on-demand fixup code __dl_runtime_resolve.  */

auto inline int
__attribute__ ((always_inline))
elf_machine_runtime_setup (struct link_map *l, int lazy, int profile)
{
#ifndef RTLD_BOOTSTRAP
  /* If using PLTs, fill in the first two entries of .got.plt.  */
  if (l->l_info[DT_JMPREL])
    {

#if HAVE_LOONGARCH_VEC_ASM && !defined __loongarch_soft_float
      extern void _dl_runtime_resolve_lasx (void) __attribute__ ((visibility ("hidden")));
      extern void _dl_runtime_resolve_lsx (void) __attribute__ ((visibility ("hidden")));
#endif
      extern void _dl_runtime_resolve (void) __attribute__ ((visibility ("hidden")));

      ElfW(Addr) *gotplt = (ElfW(Addr) *) D_PTR (l, l_info[DT_PLTGOT]);
      /* If a library is prelinked but we have to relocate anyway,
	 we have to be able to undo the prelinking of .got.plt.
	 The prelinker saved the address of .plt for us here.  */
      if (gotplt[1])
	l->l_mach.plt = gotplt[1] + l->l_addr;

#if HAVE_LOONGARCH_VEC_ASM && !defined __loongarch_soft_float
      if (RTLD_SUPPORT_LASX)
	gotplt[0] = (ElfW(Addr)) &_dl_runtime_resolve_lasx;
      else if (RTLD_SUPPORT_LSX)
	gotplt[0] = (ElfW(Addr)) &_dl_runtime_resolve_lsx;
      else
#endif
	gotplt[0] = (ElfW(Addr)) &_dl_runtime_resolve;

      gotplt[1] = (ElfW(Addr)) l;
    }
#endif

  return lazy;
}

#endif /* RESOLVE_MAP */
