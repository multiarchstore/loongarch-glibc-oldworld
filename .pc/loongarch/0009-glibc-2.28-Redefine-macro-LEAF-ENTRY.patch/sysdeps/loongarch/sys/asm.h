#ifndef _SYS_ASM_H
#define _SYS_ASM_H

#include <sys/regdef.h>
#include <sysdeps/generic/sysdep.h>

/* Macros to handle different pointer/register sizes for 32/64-bit code.  */
#ifdef __loongarch64
# define PTRLOG 3
# define SZREG	8
# define SZFREG	8
# define REG_L ld.d
# define REG_S st.d
# define FREG_L fld.d
# define FREG_S fst.d
#elif defined __loongarch32
# define PTRLOG 2
# define SZREG	4
# define SZFREG	4
# define REG_L ld.w
# define REG_S st.w
# define FREG_L fld.w
# define FREG_S fst.w
#else
# error __loongarch_xlen must equal 32 or 64
#endif


/* Declare leaf routine.  */
#define	LEAF(symbol, aln)		\
	.text;				\
	.globl	symbol;			\
	.align	aln;			\
	.type	symbol, @function;	\
symbol: \
	cfi_startproc;			\

# define ENTRY(symbol, aln) LEAF(symbol, aln)

#define	LEAF_NO_ALIGN(symbol)			\
	.text;				\
	.globl	symbol;			\
	.type	symbol, @function;	\
symbol: \
	cfi_startproc;

# define ENTRY_NO_ALIGN(symbol) LEAF_NO_ALIGN(symbol)

/* Mark end of function.  */
#undef END
#define END(function)			\
	cfi_endproc ;			\
	.size	function,.-function;

/* Stack alignment.  */
#define ALMASK	~15

#endif /* sys/asm.h */
