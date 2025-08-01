#ifdef _LIBC
#include <sysdep.h>
#include <sys/regdef.h>
#include <sys/asm.h>
#else
#include <sys/asm.h>
#include <sys/regdef.h>
#endif

#ifndef MEMSET_NAME
#define MEMSET_NAME memset
#endif

#define ST_64(n)                \
    st.d        a1, a0, n;      \
    st.d        a1, a0, n+8;    \
    st.d        a1, a0, n+16;   \
    st.d        a1, a0, n+24;   \
    st.d        a1, a0, n+32;   \
    st.d        a1, a0, n+40;   \
    st.d        a1, a0, n+48;   \
    st.d        a1, a0, n+56;

LEAF(MEMSET_NAME, 6)
    move        t0, a0
    andi        a3, a0, 0x7
    li.w        t6, 16
    beqz        a3, L(align)
    blt         a2, t6, L(short_data)

L(make_align):
    li.w        t8, 8
    sub.d       t2, t8, a3
    pcaddi      t1, 11
    slli.d      t3, t2, 2
    sub.d       t1, t1, t3
    jirl        zero, t1, 0

L(al7):
    st.b        a1, t0, 6
L(al6):
    st.b        a1, t0, 5
L(al5):
    st.b        a1, t0, 4
L(al4):
    st.b        a1, t0, 3
L(al3):
    st.b        a1, t0, 2
L(al2):
    st.b        a1, t0, 1
L(al1):
    st.b        a1, t0, 0
L(al0):
    add.d       t0, t0, t2
    sub.d       a2, a2, t2

L(align):
    bstrins.d   a1, a1, 15, 8
    bstrins.d   a1, a1, 31, 16
    bstrins.d   a1, a1, 63, 32

    blt         a2, t6, L(less_16bytes)

    andi        a4, a2, 0x3f
    beq         a4, a2, L(less_64bytes)

    sub.d       t1, a2, a4
    move        a2, a4
    add.d       a5, t0, t1

L(loop_64bytes):
    addi.d      t0, t0, 64
    st.d        a1, t0, -64
    st.d        a1, t0, -56
    st.d        a1, t0, -48
    st.d        a1, t0, -40
    st.d        a1, t0, -32
    st.d        a1, t0, -24
    st.d        a1, t0, -16
    st.d        a1, t0, -8
    bne         t0, a5, L(loop_64bytes)

L(less_64bytes):
    srai.d      a4, a2, 5
    beqz        a4, L(less_32bytes)
    addi.d      a2, a2, -32
    st.d        a1, t0, 0
    st.d        a1, t0, 8
    st.d        a1, t0, 16
    st.d        a1, t0, 24
    addi.d      t0, t0, 32
L(less_32bytes):
    blt         a2, t6, L(less_16bytes)
    addi.d      a2, a2, -16
    st.d        a1, t0, 0
    st.d        a1, t0, 8
    addi.d      t0, t0, 16
L(less_16bytes):
    srai.d      a4, a2, 3
    beqz        a4, L(less_8bytes)
    addi.d      a2, a2, -8
    st.d        a1, t0, 0
    addi.d      t0, t0, 8
L(less_8bytes):
    beqz        a2, L(less_1byte)
    srai.d      a4, a2, 2
    beqz        a4, L(less_4bytes)
    addi.d      a2, a2, -4
    st.w        a1, t0, 0
    addi.d      t0, t0, 4
L(less_4bytes):
    srai.d      a3, a2, 1
    beqz        a3, L(less_2bytes)
    addi.d      a2, a2, -2
    st.h        a1, t0, 0
    addi.d      t0, t0, 2
L(less_2bytes):
    beqz        a2, L(less_1byte)
    st.b        a1, t0, 0
L(less_1byte):
    jr          ra

L(short_data):
    pcaddi      t1, 19
    slli.d      t3, a2, 2
    sub.d       t1, t1, t3
    jirl        zero, t1, 0
L(short_15):
    st.b        a1, a0, 14

L(short_14):
    st.b        a1, a0, 13
L(short_13):
    st.b        a1, a0, 12
L(short_12):
    st.b        a1, a0, 11
L(short_11):
    st.b        a1, a0, 10
L(short_10):
    st.b        a1, a0, 9
L(short_9):
    st.b        a1, a0, 8
L(short_8):
    st.b        a1, a0, 7
L(short_7):
    st.b        a1, a0, 6
L(short_6):
    st.b        a1, a0, 5
L(short_5):
    st.b        a1, a0, 4
L(short_4):
    st.b        a1, a0, 3
L(short_3):
    st.b        a1, a0, 2
L(short_2):
    st.b        a1, a0, 1
L(short_1):
    st.b        a1, a0, 0
L(short_0):
    jr          ra

END(MEMSET_NAME)

#ifdef _LIBC
libc_hidden_builtin_def (MEMSET_NAME)
#endif
