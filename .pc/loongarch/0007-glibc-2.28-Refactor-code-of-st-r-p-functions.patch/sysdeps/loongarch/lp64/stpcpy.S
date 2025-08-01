#ifdef _LIBC
#include <sysdep.h>
#include <sys/regdef.h>
#include <sys/asm.h>
#else
#include <sys/asm.h>
#include <sys/regdef.h>
#endif

#ifndef STPCPY_NAME
#define STPCPY_NAME __stpcpy
#endif

LEAF(STPCPY_NAME, 6)
    andi        a3, a0, 0x7
    beqz        a3, L(dest_align)
    sub.d       a5, a1, a3
    addi.d      a5, a5, 8

L(make_dest_align):
    ld.b        t0, a1, 0
    addi.d      a1, a1, 1
    st.b        t0, a0, 0
    addi.d      a0, a0, 1

    beqz        t0, L(al_out)
    bne         a1, a5, L(make_dest_align)

L(dest_align):
    andi        a4, a1, 7
    bstrins.d   a1, zero, 2, 0

    lu12i.w     t5, 0x1010
    ld.d        t0, a1, 0
    ori         t5, t5, 0x101
    bstrins.d   t5, t5, 63, 32

    slli.d      t6, t5, 0x7
    bnez        a4, L(unalign)
    sub.d       t1, t0, t5
    andn        t2, t6, t0

    and         t3, t1, t2
    bnez        t3, L(al_end)

L(al_loop):
    st.d        t0, a0, 0
    ld.d        t0, a1, 8

    addi.d      a1, a1, 8
    addi.d      a0, a0, 8
    sub.d       t1, t0, t5
    andn        t2, t6, t0

    and         t3, t1, t2
    beqz        t3, L(al_loop)

L(al_end):
    ctz.d       t1, t3
    srli.d      t1, t1, 3
    addi.d      t1, t1, 1 # add 1, since '\0' needs to be copied to dest

    andi        a3, t1, 8
    andi        a4, t1, 4
    andi        a5, t1, 2
    andi        a6, t1, 1

L(al_end_8):
    beqz        a3, L(al_end_4)
    st.d        t0, a0, 0
    addi.d      a0, a0, 7
    jr          ra
L(al_end_4):
    beqz        a4, L(al_end_2)
    st.w        t0, a0, 0
    addi.d      a0, a0, 4
    srli.d      t0, t0, 32
L(al_end_2):
    beqz        a5, L(al_end_1)
    st.h        t0, a0, 0
    addi.d      a0, a0, 2
    srli.d      t0, t0, 16
L(al_end_1):
    beqz        a6, L(al_out)
    st.b        t0, a0, 0
    addi.d      a0, a0, 1
L(al_out):
    addi.d      a0, a0, -1
    jr          ra

L(unalign):
    slli.d      a5, a4, 3
    li.d        t1, -1
    sub.d       a6, zero, a5

    srl.d       a7, t0, a5
    sll.d       t7, t1, a6

    or          t0, a7, t7
    sub.d       t1, t0, t5
    andn        t2, t6, t0
    and         t3, t1, t2

    bnez        t3, L(un_end)

    ld.d        t4, a1, 8
    addi.d      a1, a1, 8

    sub.d       t1, t4, t5
    andn        t2, t6, t4
    sll.d       t0, t4, a6
    and         t3, t1, t2

    or          t0, t0, a7
    bnez        t3, L(un_end_with_remaining)

L(un_loop):
    srl.d       a7, t4, a5

    ld.d        t4, a1, 8
    addi.d      a1, a1, 8

    st.d        t0, a0, 0
    addi.d      a0, a0, 8

    sub.d       t1, t4, t5
    andn        t2, t6, t4
    sll.d       t0, t4, a6
    and         t3, t1, t2

    or          t0, t0, a7
    beqz        t3, L(un_loop)

L(un_end_with_remaining):
    ctz.d       t1, t3
    srli.d      t1, t1, 3
    addi.d      t1, t1, 1
    sub.d       t1, t1, a4

    blt         t1, zero, L(un_end_less_8)
    st.d        t0, a0, 0
    addi.d      a0, a0, 8
    beqz        t1, L(un_out)
    srl.d       t0, t4, a5  # get the remaining part
    b           L(un_end_less_8)

L(un_end):
    ctz.d       t1, t3
    srli.d      t1, t1, 3
    addi.d      t1, t1, 1

L(un_end_less_8):
    andi        a4, t1, 4
    andi        a5, t1, 2
    andi        a6, t1, 1
L(un_end_4):
    beqz        a4, L(un_end_2)
    st.w        t0, a0, 0
    addi.d      a0, a0, 4
    srli.d      t0, t0, 32
L(un_end_2):
    beqz        a5, L(un_end_1)
    st.h        t0, a0, 0
    addi.d      a0, a0, 2
    srli.d      t0, t0, 16
L(un_end_1):
    beqz        a6, L(un_out)
    st.b        t0, a0, 0
    addi.d      a0, a0, 1
L(un_out):
    addi.d      a0, a0, -1
    jr          ra

END(STPCPY_NAME)

#ifdef _LIBC
weak_alias (STPCPY_NAME, stpcpy)
libc_hidden_builtin_def (STPCPY_NAME)
#endif
