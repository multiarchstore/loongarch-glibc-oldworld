/* LoongArch CPU feature tuning.
   This file is part of the GNU C Library.
   Copyright (C) 2017-2018 Free Software Foundation, Inc.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#if HAVE_TUNABLES
# define TUNABLE_NAMESPACE cpu
# include <stdbool.h>
# include <stdint.h>
# include <unistd.h>		/* Get STDOUT_FILENO for _dl_printf.  */
# include <elf/dl-tunables.h>
# include <string.h>
# include <cpu-features.h>
# include <ldsodefs.h>
# include <sys/auxv.h>
# include <dl-symbol-redir-ifunc.h>

#define CHECK_GLIBC_IFUNC_CPU(f, name, len)			\
  _Static_assert (sizeof (#name) - 1 == len, #name " != " #len);	\
  if (memcmp (f, #name, len) == 0)				\
    {									\
      if (disable)							\
	GLRO(dl_larch_cpu_features).hwcap &= (~HWCAP_LOONGARCH_##name);	\
      else								\
	GLRO(dl_larch_cpu_features).hwcap |= HWCAP_LOONGARCH_##name;	\
      break;								\
    }

attribute_hidden void
TUNABLE_CALLBACK (set_hwcaps) (tunable_val_t *valp)
{
  /* The current IFUNC selection is always using the most recent
     features which are available via AT_HWCAP.  But in
     some scenarios it is useful to adjust this selection.

     The environment variable:

     GLIBC_TUNABLES=glibc.cpu.hwcaps=-xxx,yyy,zzz,....

     can be used to enable HWCAP feature yyy, disable HWCAP feature xxx,
     where the feature name is case-sensitive and has to match the ones
     used below.  */

  const char *p = valp->strval;
  const char *c;

  do
    {
      bool disable;
      size_t len, nl;
      const char *n;

      for (c = p; *c != ','; c++)
	if (*c == '\0')
	  break;

      len = c - p;
      disable = *p == '-';
      if (disable)
	{
	  n = p + 1;
	  nl = len - 1;
	}
      else
	{
	  n = p;
	  nl = len;
	}

      switch (nl)
	{
	  default:
	    break;
	  case 3:
	    {
	      CHECK_GLIBC_IFUNC_CPU (n, LSX, 3);
	      CHECK_GLIBC_IFUNC_CPU (n, UAL, 3);
	    }
	    break;
	  case 4:
	    {
	      CHECK_GLIBC_IFUNC_CPU (n, LASX, 4);
	    }
	    break;
	}
      p += len + 1;
    }
  while (*c != '\0');

  /* Ensure that the user has not enabled any unsupported features.  */
  GLRO(dl_larch_cpu_features).hwcap &= GLRO(dl_hwcap);
}

#endif
