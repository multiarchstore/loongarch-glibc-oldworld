#include <sysdep.h>
#include <sys/asm.h>
#include <libm-alias-float.h>

/* Short algorithm description:
 *
 *  1) if |x|==0:    sin(x)=x,
 *                   cos(x)=1.
 *  2) if |x|<2^-27: sin(x)=x-x*DP_SMALL, raising underflow only when needed,
 *                   cos(x)=1-|x|.
 *  3) if |x|<2^-5 : sin(x)=x+x*x^2*DP_SIN2_0+x^5*DP_SIN2_1,
 *                   cos(x)=1+1*x^2*DP_COS2_0+x^5*DP_COS2_1
 *  4) if |x|< Pi/4: sin(x)=x+x*x^2*(S0+x^2*(S1+x^2*(S2+x^2*(S3+x^2*S4)))),
 *                   cos(x)=1+1*x^2*(C0+x^2*(C1+x^2*(C2+x^2*(C3+x^2*C4)))).
 *  5) if |x| < 9*Pi/4:
 *      5.1) Range reduction:
 *          k=trunc(|x|/(Pi/4)), j=(k+1)&0x0e, n=k+1, t=|x|-j*Pi/4.
 *      5.2) Reconstruction:
 *          sign_sin = sign(x) * (-1.0)^(( n   >>2)&1)
 *          sign_cos =           (-1.0)^(((n+2)>>2)&1)
 *          poly_sin = ((((S4*t^2 + S3)*t^2 + S2)*t^2 + S1)*t^2 + S0)*t^2*t+t
 *          poly_cos = ((((C4*t^2 + C3)*t^2 + C2)*t^2 + C1)*t^2 + C0)*t^2*s+s
 *          if(n&2 != 0) {
 *              using cos(t) and sin(t) polynomials for |t|<Pi/4, results are
 *              cos(x) = poly_sin * sign_cos
 *              sin(x) = poly_cos * sign_sin
 *          } else {
 *              sin(x) = poly_sin * sign_sin
 *              cos(x) = poly_cos * sign_cos
 *          }
 *  6) if |x| < 2^23, large args:
 *      6.1) Range reduction:
 *          k=trunc(|x|/(Pi/4)), j=(k+1)&0xfffffffe, n=k+1, t=|x|-j*Pi/4
 *      6.2) Reconstruction same as (5.2).
 *  7) if |x| >= 2^23, very large args:
 *      7.1) Range reduction:
 *          k=trunc(|x|/(Pi/4)), j=(k+1)&0xfffffffe, n=k+1, t=|x|-j*Pi/4.
 *      7.2) Reconstruction same as (5.2).
 *  8) if x is Inf, return x-x, and set errno=EDOM.
 *  9) if x is NaN, return x-x.
 *
 * Special cases:
 *  sin/cos(+-0) = +-0/1 not raising inexact/underflow,
 *  sin/cos(subnormal) raises inexact/underflow,
 *  sin/cos(min_normalized) raises inexact/underflow,
 *  sin/cos(normalized) raises inexact,
 *  sin/cos(Inf) = NaN, raises invalid, sets errno to EDOM,
 *  sin/cos(NaN) = NaN.
 */
 
#define COSF __cosf

#define LOADFD(rd, rs, label) \
    la.local rs, label;\
    fld.d rd, rs, 0

#define LOADFS(rd, rs, label) \
    la.local rs, label;\
    fld.s rd, rs, 0

#define FTOL(rd, rs, tmp) \
    ftintrz.l.d tmp, rs;\
    movfr2gr.d    rd, tmp

#define FTOW(rd, rs, tmp) \
    ftintrz.w.d tmp, rs;\
    movfr2gr.s  rd, tmp

#define WTOF(rd, rs, tmp) \
    movgr2fr.w  tmp, rs;\
    ffint.d.w   rd, tmp

#define LTOF(rd, rs, tmp) \
    movgr2fr.d  tmp, rs;\
    ffint.d.l   rd, tmp

LEAF(COSF, 3)
    /* fa0 is SP x; fa1 is DP x */
    movfr2gr.s  t0, fa0 /* Bits of x */
    fcvt.d.s    fa1, fa0 /* DP x */
    li.w        t1, 0x7fffffff
    and         t0, t0, t1    /* |x| */
    li.w        t1, 0x3f490fdb /* const Pi/4 */
    bltu        t0, t1, L(arg_less_pio4) /* |x| < Pi/4 branch */
    li.w        t1, 0x40e231d6 /* 9*Pi/4 */
    la.local    t4, L(DP_) /*DP_ base addr*/
    bgeu        t0, t1, L(greater_or_equal_9pio4) /* |x| >= 9*Pi/4 branch */
/* L(median_args): */    
    /* Here if Pi/4<=|x|<9*Pi/4 */
    fabs.d      fa0, fa1 /* DP |x| */
    fld.d       fa1, t4, 56 /* 4/Pi */
    fmul.d      fa1, fa1, fa0 /* DP |x|/(Pi/4) */
    FTOW( t0, fa1, fa1 ) /* k=trunc(|x|/(Pi/4)) */
    la.local    t1, L(PIO2J) /* base addr of PIO2J table */
    addi.w      t0, t0, 1 /* k+1 */
    bstrpick.d  t2, t0, 3, 1 /* j=n/2 */
    alsl.d      t1, t2, t1, 3
    fld.d       fa1, t1, 0 /* j*Pi/2 */
    addi.w      t0, t0, 2 /* n = k+3 */
    fsub.d      fa0, fa0, fa1 /* t = |x| - j * Pi/2 */
/* Input: t0=n fa0=t*/
L(reduced):
   /* Here if cos(x) calculated using cos(t) polynomial for |t|<Pi/4:
    * y = t*t; z = y*y;
    * s = sign(x) * (-1.0)^((n>>2)&1)
    * result = s * (1.0+t^2*(C0+t^2*(C1+t^2*(C2+t^2*(C3+t^2*C4)))))
    
    * Here if cos(x) calculated using sin(t) polynomial for |t|<Pi/4:
    * y = t*t; z = y*y;
    * s = sign(x) * (-1.0)^((n>>2)&1)
    * result = s * t * (1.0+t^2*(S0+t^2*(S1+t^2*(S2+t^2*(S3+t^2*S4)))))
    */
    /* TODO: what is the best order ??? */
    /* load-to-use latency, hardware module usage, integer pipeline & float pipeline */
    /* cancel branch */
    slli.w      t0, t0, 1 /* (n << 1) */
    andi        t1, t0, 4 /* (n << 1) & 4 */
    alsl.d      t2, t1, t4, 4 /* adjust to DP_C or DP_S */
    fld.d       fa3, t2, 32 /* C4 */
    andi        t0, t0, 8 /* =====> (n << 1) & 8 */
    fmul.d      fa1, fa0, fa0 /* y=x^2 */    
    fld.d       fa4, t2, 16 /* C2 */
    fmul.d      fa2, fa1, fa1 /* z=x^4 */
    fld.d       fa5, t2, 24 /* C3 */
    la.local    t3, L(DP_ONES) /* =====> DP_ONES */
    fld.d       fa6, t2, 8  /* C1 */
    fmadd.d     fa4, fa2, fa3, fa4 /* cx = C2+z*C4 */
    fld.d       fa3, t2, 0  /* C0 */
    fmadd.d     fa5, fa2, fa5, fa6 /* cy = C1+z*C3 */
    fld.d       fa6, t3, 0 /* one */
    fmadd.d     fa4, fa2, fa4, fa3 /* cx = C0+z*cx */
    add.d       t0, t0, t3 /* =====> addr */
    fmadd.d     fa4, fa1, fa5, fa4 /* cx = cx+y*cy */
    fld.d       fa2, t0, 0 /* sign */
    fmadd.d     fa4, fa4, fa1, fa6 /* 1.0+y*cx */
    fmul.d      fa1, fa2, fa4 /* sign * cx */
    bnez        t1, L_return
    fmul.d      fa1, fa1, fa0 /* t*s, where s = sign(x) * (-1.0)^((n>>2)&1) */
L_return:
    fcvt.s.d    fa0, fa1 /* SP result */
    jr          ra

L(greater_or_equal_9pio4):
    /* Here if |x|>=9*Pi/4 */
    li.w        t1, 0x7f800000 /* x is Inf or NaN?  */
    bgeu        t0, t1, L(inf_or_nan) /* |x| >= Inf branch */
    /* Here if finite |x|>=9*Pi/4 */
    li.w        t1, 0x4b000000 /* 2^23  */
    bgeu        t0, t1, L(greater_or_equal_2p23) /* |x| >= 2^23 branch */
    /* Here if 9*Pi/4<=|x|<2^23 */
    fabs.d      fa0, fa1 /* DP |x| */
    fld.d       fa1, t4, 56
    fmul.d      fa1, fa1, fa0 /* |x|/(Pi/4) */
    FTOW( t0, fa1, fa1 )  /* k=trunc(|x|/(Pi/4)) */
    addi.w      t0, t0, 1 /* k+1 */
    srli.w      t1, t0, 1 /* x=n/2 */
    WTOF( fa1, t1, fa1 ) /* DP x */
    fld.d       fa2, t4, 104 /* -PIO2HI = high part of -Pi/2 */
    fld.d       fa3, t4, 112 /* -PIO2LO = low part of -Pi/2 */
    fmadd.d     fa0, fa2, fa1, fa0 /* |x| - x*PIO2HI */
    addi.w      t0, t0, 2 /* n = k+3 */
    fmadd.d     fa0, fa3, fa1, fa0 /* |x| - x*PIO2HI - x*PIO2LO */
    b           L(reduced)

L(greater_or_equal_2p23):
    /* Here if finite |x|>=2^23 */
    fabs.s      fa5, fa0 /* SP |x| */
    /* bitpos = (ix>>23) - BIAS_32; */
    srli.w      t0, t0, 23 /*TODO???srai.w eb = biased exponent of x */
    /* bitpos = eb - 0x7f + 59, where 0x7f is exponent bias */
    addi.w      t0, t0, -124 /* t0 = bitpos */
    /* t3= j = bitpos/28 */
    /* x/28 = (x * ((0x100000000 / 28) + 1)) >> 32 */
    li.w        t1, 0x924924a
    mulh.wu     t0, t1, t0
    fcvt.d.s    fa5, fa5 /* Convert to double */
    /* TODO: what is the best order ??? */
    la.local    t1, L(invpio4_table) /* t2 */
    alsl.d      t1, t0, t1, 3
    fld.d       fa0, t1, 0  /* invpio4_table[j] */
    fld.d       fa1, t1, 8  /* invpio4_table[j+1] */
    fmul.d      fa0, fa0, fa5 /* a = invpio4_table[j]*|x| */
    fld.d       fa2, t1, 16 /* invpio4_table[j+2] */
    fmul.d      fa1, fa1, fa5 /* b = invpio4_table[j+1]*|x| */
    fld.d       fa3, t1, 24 /* invpio4_table[j+3] */
    fmul.d      fa2, fa2, fa5 /* c = invpio4_table[j+2]*|x| */
    fmul.d      fa3, fa3, fa5 /* d = invpio4_table[j+3]*|x| */
/*TODO: overflow check*/
    FTOL( t0, fa0, fa4 ) /*uint64_t l = a; TODO: change the order*/
    li.w        t1, -8   /* 0xfffffffffffffff8 */
    and         t0, t0, t1 /* l &= ~0x7; */
    LTOF( fa4, t0, fa4 ) /* DP l*/
    fsub.d      fa0, fa0, fa4 /* a -= l; */
    fadd.d      fa4, fa0, fa1 /* fa4 double e = a + b; */
/*TODO: overflow check*/
    FTOL( t0, fa4, fa4 ) /*uint64_t l = e;*/
    andi        t2, t0, 1 /* l & 1 TODO: change the order*/
    LOADFD( fa5, t1, L(DP_ONES) ) /* fa5 = 1.0 */
    LTOF( fa4, t0, fa4 ) /* fa4 DP l*/
/* critical!!!! the order */
    fsub.d      fa0, fa0, fa4
    fld.d       fa4, t4, 120 /* PI_4 */
    beqz        t2, L_even_integer
/*L_odd_integer:*/
    fsub.d      fa0, fa0, fa5
    fadd.d      fa0, fa0, fa1
    fadd.d      fa2, fa2, fa3
    fadd.d      fa0, fa0, fa2
    addi.d      t0, t0, 3
    fmul.d      fa0, fa0, fa4
    b           L(reduced)
L_even_integer:
    fadd.d      fa0, fa0, fa1
    fadd.d      fa2, fa2, fa3
    fadd.d      fa0, fa0, fa2
    fcmp.sle.d  $fcc0, fa0, fa5
    addi.d      t0, t0, 3
    bcnez       $fcc0, L_leq_one
/*L_gt_one:*/
    fld.d       fa2, t1, 16 /* 2.0 */
    addi.d      t0, t0, 1
    fsub.d      fa0, fa0, fa2
L_leq_one:
    fmul.d      fa0, fa0, fa4
    b           L(reduced)

L(arg_less_pio4):
    /* Here if |x|<Pi/4 */
    li.w        t1, 0x3d000000 /* const 2^-5 */
    blt         t0, t1, L(less_2pn5) /* |x| < 2^-5 branch */
    /* Here if 2^-5<=|x|<Pi/4 */
    /* 
     * Chebyshev polynomial of the form:
     * 1.0+x^2*(C0+x^2*(C1+x^2*(C2+x^2*(C3+x^2*C4)))).
     */
    la.local    t0, L(DP_) /*DP_ base addr*/
    fld.d       fa3, t0, 96 /* C4 */
    fmul.d      fa1, fa1, fa1 /* y=x^2 */    
    fld.d       fa4, t0, 80 /* C2 */
    fmul.d      fa2, fa1, fa1 /* z=x^4 */
    fld.d       fa5, t0, 88 /* C3 */
    fld.d       fa6, t0, 72 /* C1 */
    fmadd.d     fa0, fa2, fa3, fa4 /* cx = C2+z*C4 */
    fld.d       fa3, t0, 64 /* C0 */
    fmadd.d     fa5, fa2, fa5, fa6 /* cy = C1+z*C3 */
    la.local    t0, L(DP_ONES)
    fmadd.d     fa0, fa0, fa2, fa3 /* cx = C0+z*cx */
    fld.d       fa2, t0, 0 /* 1.0 */
    fmadd.d     fa0, fa1, fa5, fa0 /* cx = cx+y*cy */
    fmadd.d     fa0, fa0, fa1, fa2 /* 1.0+y*cx */
    /*    
    fld.d       fa6, t0, 96
    fld.d       fa5, t0, 88
    fld.d       fa4, t0, 80
    fmul.d      fa1, fa1, fa1    
    fld.d       fa3, t0, 72
    fld.d       fa2, t0, 64
    la.local    t0, L(DP_ONES)
    fld.d       fa6, t0, 0
    fmadd.d     fa0, fa1, fa5, fa0
    fmadd.d     fa0, fa1, fa4, fa0
    fmadd.d     fa0, fa1, fa3, fa0
    fmadd.d     fa0, fa1, fa2, fa0
    fmadd.d     fa0, fa1, fa5, fa4
    */
    fcvt.s.d    fa0, fa0
    jr          ra

L(less_2pn5):
    /* Here if |x|<2^-5 */
    li.w        t1, 0x32000000 /* 2^-27?  */
    blt         t0, t1, L(less_2pn27)
    /* Here if 2^-27<=|x|<2^-5 */
    fmul.d      fa0, fa1, fa1 /* theta2=x^2 */
    la.local    t0, L(DP_)
    fld.d       fa2, t0, 48  /* DP_COS2_1 */
    fmul.d      fa1, fa1, fa0 /* x*theta2 */
    fld.d       fa3, t0, 40 /* DP_COS2_0 */
    la.local    t0, L(DP_ONES)
    fld.d       fa4, t0, 0 /* 1.0 */
    fmadd.d     fa1, fa1, fa2, fa3 /* DP_COS2_0+x^2*DP_COS2_1 */
    fmadd.d     fa0, fa0, fa1, fa4 /* cx = 1.0 + theta2 * cx */
    fcvt.s.d    fa0, fa0
    jr          ra

L(less_2pn27):
    /* Here if |x|<2^-27 */
    fabs.s      fa0, fa0
    LOADFS( fa1, t0, L(SP_ONE) ) /* 1.0 */
    fsub.s      fa0, fa1, fa0 /* 1.0 - abstheta */
    /* No need to convert */
    jr          ra

L(inf_or_nan):
    /* Here if |x| is Inf or NAN */
    bne         t0, t1, L_skip_errno_setting /* in case of x is NaN */
    la.tls.ie   t0, errno
    li.w        t1, 0x21
    stx.w       t1, t0, tp
L_skip_errno_setting:
    /* Here if |x| is Inf or NAN. Continued.  */
    fsub.s      fa0, fa0, fa0 /* Result is NaN */
    jr          ra
END(COSF)

    .section .rodata
    .align 3
    .type L(PIO2J), @object
    .size L(PIO2J), 48
L(PIO2J): /* Table of j*Pi/2, for j=0,1,..,5 */
    .word   0x00000000
    .word   0x00000000
    .word   0x54442d18
    .word   0x3ff921fb
    .word   0x54442d18
    .word   0x400921fb
    .word   0x7f3321d2
    .word   0x4012d97c
    .word   0x54442d18
    .word   0x401921fb
    .word   0x2955385e
    .word   0x401f6a7a

    .align 3
    .type L(invpio4_table), @object
    .size L(invpio4_table), 64
L(invpio4_table): /* 4/Pi broken into sum of positive DP values */
    .word   0x00000000
    .word   0x00000000
    .word   0x6c000000
    .word   0x3ff45f30
    .word   0x2a000000
    .word   0x3e3c9c88
    .word   0xa8000000
    .word   0x3c54fe13
    .word   0xd0000000
    .word   0x3aaf47d4
    .word   0x6c000000
    .word   0x38fbb81b
    .word   0xe0000000
    .word   0x3714acc9
    .word   0x7c000000
    .word   0x3560e410

/* Coefficients of polynomial
    for sin(x)~=x+x^3*DP_SIN2_0+x^5*DP_SIN2_1, |x|<2^-5.  */
/* Coefficients of polynomial
    for sin(t)~=t+t^3*(S0+t^2*(S1+t^2*(S2+t^2*(S3+t^2*S4)))), |t|<Pi/4.  
    for cos(t)~=1.0+t^2*(C0+t^2*(C1+t^2*(C2+t^2*(C3+t^2*C4)))), |t|<Pi/4.
*/
    .align 3
    .type L(DP_), @object
    .size L(DP_), 128
L(DP_):
    .word   0x55551cd9
    .word   0xbfc55555 /*S0*/
    .word   0x10c2688b
    .word   0x3f811111 /*S1*/
    .word   0x8b4bd1f9
    .word   0xbf2a019f /*S2*/
    .word   0x64e6b5b4
    .word   0x3ec71d72 /*S3*/
    .word   0x1674b58a
    .word   0xbe5a947e /*S4*/
    .word   0xff5cc6fd
    .word   0xbfdfffff /*CC0 +40*/
    .word   0xb178dac5
    .word   0x3fa55514 /*CC1 +48*/
    .word   0x6dc9c883
    .word   0x3ff45f30 /* inv_PI_4 */
    .word   0xfffe98ae
    .word   0xbfdfffff /*C0*/
    .word   0x545c50c7
    .word   0x3fa55555 /*C1*/
    .word   0x348b6874
    .word   0xbf56c16b /*C2*/
    .word   0x9ac43cc0
    .word   0x3efa00eb /*C3*/
    .word   0xdd8844d7
    .word   0xbe923c97 /*C4*/
    .word   0x54400000
    .word   0xbff921fb /* PI_2_hi */
    .word   0x1a626332
    .word   0xbdd0b461 /* PI_2_lo */
    .word   0x54442d18
    .word   0x3fe921fb /* PI_4 */

    .align 3
    .type L(DP_ONES), @object
    .size L(DP_ONES), 24
L(DP_ONES):
    .word   0x00000000
    .word   0x3ff00000    /* +1.0 */
    .word   0x00000000
    .word   0xbff00000    /* -1.0 */
    .word   0x00000000
    .word   0x40000000    /* +2.0 */

    .align 2
L(SP_INVPIO4):
    .word   0x3fa2f983   /* 4/Pi */

    .align 2
L(SP_ONE):
    .word   0x3f800000   /* 1.0 */

libm_alias_float (__cos, cos)
