# Copyright (C) 1991-2018 Free Software Foundation, Inc.
# This file is part of the GNU C Library.

# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.

# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.

#
#	Sub-makefile for string portion of library.
#
subdir	:= string

include ../Makeconfig

headers		:= string.h bits/string_fortified.h			\
		   strings.h bits/strings_fortified.h			\
		   byteswap.h bits/byteswap.h				\
		   endian.h bits/endian.h bits/uintn-identity.h		\
		   memory.h argz.h envz.h

routines	:= strcat strchr strcmp strcoll strcpy strcspn		\
		   strverscmp strdup strndup				\
		   strerror _strerror strlen strnlen			\
		   strncat strncmp strncpy				\
		   strrchr strpbrk strsignal strspn strstr strtok	\
		   strtok_r strxfrm memchr memcmp memmove memset	\
		   mempcpy bcopy bzero ffs ffsll stpcpy stpncpy		\
		   strcasecmp strncase strcasecmp_l strncase_l		\
		   memccpy memcpy wordcopy strsep strcasestr		\
		   swab strfry memfrob memmem rawmemchr strchrnul	\
		   $(addprefix argz-,append count create ctsep next	\
				     delete extract insert stringify	\
				     addsep replace)			\
		   envz basename					\
		   strcoll_l strxfrm_l string-inlines memrchr		\
		   xpg-strerror strerror_l explicit_bzero

strop-tests	:= memchr memcmp memcpy memmove mempcpy memset memccpy	\
		   stpcpy stpncpy strcat strchr strcmp strcpy strcspn	\
		   strlen strncmp strncpy strpbrk strrchr strspn memmem	\
		   strstr strcasestr strnlen strcasecmp strncasecmp	\
		   strncat rawmemchr strchrnul bcopy bzero memrchr	\
		   explicit_bzero
tests		:= tester inl-tester noinl-tester testcopy test-ffs	\
		   tst-strlen stratcliff tst-svc tst-inlcall		\
		   bug-strncat1 bug-strspn1 bug-strpbrk1 tst-bswap	\
		   tst-strtok tst-strxfrm bug-strcoll1 tst-strfry	\
		   bug-strtok1 $(addprefix test-,$(strop-tests))	\
		   bug-envz1 tst-strxfrm2 tst-endian tst-svc2		\
		   tst-strtok_r bug-strcoll2 tst-cmp tst-xbzero-opt	\
		   test-endian-types test-endian-file-scope		\
		   test-endian-sign-conversion

# This test allocates a lot of memory and can run for a long time.
xtests = tst-strcoll-overflow

test-xfail-test-memcpy = yes
test-xfail-test-memset = yes

# This test needs libdl.
ifeq (yes,$(build-shared))
tests += test-strerror-errno
LDLIBS-test-strerror-errno = $(libdl)
endif

ifeq ($(run-built-tests),yes)
tests-special += $(objpfx)tst-svc-cmp.out
endif

include ../Rules

CFLAGS-inl-tester.c += -fno-builtin
CFLAGS-noinl-tester.c += -fno-builtin
CFLAGS-tst-strlen.c += -fno-builtin
CFLAGS-stratcliff.c += -fno-builtin
CFLAGS-test-ffs.c += -fno-builtin
CFLAGS-tst-inlcall.c += -fno-builtin
CFLAGS-tst-xbzero-opt.c += -O3
CFLAGS-test-endian-sign-conversion.c += -Werror -Wsign-conversion
# BZ 21006: Resolve all functions but at least explicit_bzero at startup.
# Otherwise the test fails on s390x as the memcpy in prepare_test_buffer is
# done by loading r4 / r5 with the test_pattern and using store multiple
# instruction to store r4 / r5 to buf.  If explicit_bzero would be resolved in
# setup_explicit_clear, r4 / r5 would be stored to stack by _dl_runtime_resolve
# and the call to memmem in count_test_patterns will find a hit of the
# test_pattern on the stack.
LDFLAGS-tst-xbzero-opt = -z now

# Called during TLS initialization.
CFLAGS-memcpy.c += $(no-stack-protector)
CFLAGS-wordcopy.c += $(no-stack-protector)

ifeq ($(run-built-tests),yes)
$(objpfx)tst-svc-cmp.out: tst-svc.expect $(objpfx)tst-svc.out
	cmp $^ > $@; \
	$(evaluate-test)

LOCALES := de_DE.UTF-8 en_US.ISO-8859-1 en_US.UTF-8 \
           tr_TR.ISO-8859-9 tr_TR.UTF-8 cs_CZ.UTF-8 \
	   da_DK.ISO-8859-1 en_GB.UTF-8
include ../gen-locales.mk

$(objpfx)test-strcasecmp.out: $(gen-locales)
$(objpfx)test-strncasecmp.out: $(gen-locales)
$(objpfx)tst-strxfrm.out: $(gen-locales)
$(objpfx)tst-strxfrm2.out: $(gen-locales)
# bug-strcoll2 needs cs_CZ.UTF-8 and da_DK.ISO-8859-1.
$(objpfx)bug-strcoll2.out: $(gen-locales)
$(objpfx)tst-strcoll-overflow.out: $(gen-locales)

endif
