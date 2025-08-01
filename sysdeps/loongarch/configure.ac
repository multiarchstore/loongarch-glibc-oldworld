GLIBC_PROVIDES dnl See aclocal.m4 in the top level source directory.
# Local configure fragment for sysdeps/loongarch/elf.

dnl It is always possible to access static and hidden symbols in an
dnl position independent way.
#AC_DEFINE(PI_STATIC_AND_HIDDEN)

# Check if asm support vector instructions.
AC_CACHE_CHECK(for vector support in assembler, libc_cv_loongarch_vec_asm, [dnl
cat > conftest.s <<\EOF
        vld  $vr0, $sp, 0
EOF
if AC_TRY_COMMAND(${CC-cc} -c $CFLAGS conftest.s -o conftest 1>&AS_MESSAGE_LOG_FD); then
  libc_cv_loongarch_vec_asm=yes
else
  libc_cv_loongarch_vec_asm=no
fi
rm -f conftest*])
if test $libc_cv_loongarch_vec_asm = yes; then
  AC_DEFINE(HAVE_LOONGARCH_VEC_ASM)
fi
