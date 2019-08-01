#
#----------------------------------------------------------------
# 64-bit x86 assembler code (gnu as) for Skein block functions
#
# Author: Doug Whiting, Hifn/Exar
#
# This code is released to the public domain.
#----------------------------------------------------------------
# $FreeBSD$
#
    .text
    .altmacro
#    .psize 0,128                            #list file has no page boundaries
#
_MASK_ALL_  =  (256+512+1024)               #all three algorithm bits
_MAX_FRAME_ =  240
#
#################
_USE_ASM_	  = SKEIN_USE_ASM
#################
_SKEIN_LOOP       =   SKEIN_LOOP                     #default is fully unrolled for 256/512, twice for 1024
# the unroll counts (0 --> fully unrolled)
SKEIN_ASM_UNROLL  = 0
#################
#
ROUNDS_256  =   72
ROUNDS_512  =   72
ROUNDS_1024 =   80
#################
#
.ifdef SKEIN_CODE_SIZE
_SKEIN_CODE_SIZE = (1)
.else
.ifdef  SKEIN_PERF                           #use code size if SKEIN_PERF is defined
_SKEIN_CODE_SIZE = (1)
.else
_SKEIN_CODE_SIZE = (0)
.endif
.endif
#
#################
#
# define offsets of fields in hash context structure
#
HASH_BITS   =   0                   #bits of hash output
BCNT        =   8 + HASH_BITS       #number of bytes in BUFFER[]
TWEAK       =   8 + BCNT            #tweak values[0..1]
X_VARS      =  16 + TWEAK           #chaining vars
#
#(Note: buffer[] in context structure is NOT needed here :-)
#
KW_PARITY   =   0x1BD11BDAA9FC1A22  #overall parity of key schedule words
FIRST_MASK  =   ~ (1 <<  6)
FIRST_MASK64=   ~ (1 << 62)
#
# rotation constants for Skein
#
RC_256_0_0  = 14
RC_256_0_1  = 16

RC_256_1_0  = 52
RC_256_1_1  = 57

RC_256_2_0  = 23
RC_256_2_1  = 40

RC_256_3_0  =  5
RC_256_3_1  = 37

RC_256_4_0  = 25
RC_256_4_1  = 33

RC_256_5_0  = 46
RC_256_5_1  = 12

RC_256_6_0  = 58
RC_256_6_1  = 22

RC_256_7_0  = 32
RC_256_7_1  = 32

RC_512_0_0  = 46
RC_512_0_1  = 36
RC_512_0_2  = 19
RC_512_0_3  = 37

RC_512_1_0  = 33
RC_512_1_1  = 27
RC_512_1_2  = 14
RC_512_1_3  = 42

RC_512_2_0  = 17
RC_512_2_1  = 49
RC_512_2_2  = 36
RC_512_2_3  = 39

RC_512_3_0  = 44
RC_512_3_1  =  9
RC_512_3_2  = 54
RC_512_3_3  = 56

RC_512_4_0  = 39
RC_512_4_1  = 30
RC_512_4_2  = 34
RC_512_4_3  = 24

RC_512_5_0  = 13
RC_512_5_1  = 50
RC_512_5_2  = 10
RC_512_5_3  = 17

RC_512_6_0  = 25
RC_512_6_1  = 29
RC_512_6_2  = 39
RC_512_6_3  = 43

RC_512_7_0  =  8
RC_512_7_1  = 35
RC_512_7_2  = 56
RC_512_7_3  = 22

RC_1024_0_0 = 24
RC_1024_0_1 = 13
RC_1024_0_2 =  8
RC_1024_0_3 = 47
RC_1024_0_4 =  8
RC_1024_0_5 = 17
RC_1024_0_6 = 22
RC_1024_0_7 = 37

RC_1024_1_0 = 38
RC_1024_1_1 = 19
RC_1024_1_2 = 10
RC_1024_1_3 = 55
RC_1024_1_4 = 49
RC_1024_1_5 = 18
RC_1024_1_6 = 23
RC_1024_1_7 = 52

RC_1024_2_0 = 33
RC_1024_2_1 =  4
RC_1024_2_2 = 51
RC_1024_2_3 = 13
RC_1024_2_4 = 34
RC_1024_2_5 = 41
RC_1024_2_6 = 59
RC_1024_2_7 = 17

RC_1024_3_0 =  5
RC_1024_3_1 = 20
RC_1024_3_2 = 48
RC_1024_3_3 = 41
RC_1024_3_4 = 47
RC_1024_3_5 = 28
RC_1024_3_6 = 16
RC_1024_3_7 = 25

RC_1024_4_0 = 41
RC_1024_4_1 =  9
RC_1024_4_2 = 37
RC_1024_4_3 = 31
RC_1024_4_4 = 12
RC_1024_4_5 = 47
RC_1024_4_6 = 44
RC_1024_4_7 = 30

RC_1024_5_0 = 16
RC_1024_5_1 = 34
RC_1024_5_2 = 56
RC_1024_5_3 = 51
RC_1024_5_4 =  4
RC_1024_5_5 = 53
RC_1024_5_6 = 42
RC_1024_5_7 = 41

RC_1024_6_0 = 31
RC_1024_6_1 = 44
RC_1024_6_2 = 47
RC_1024_6_3 = 46
RC_1024_6_4 = 19
RC_1024_6_5 = 42
RC_1024_6_6 = 44
RC_1024_6_7 = 25

RC_1024_7_0 =  9
RC_1024_7_1 = 48
RC_1024_7_2 = 35
RC_1024_7_3 = 52
RC_1024_7_4 = 23
RC_1024_7_5 = 31
RC_1024_7_6 = 37
RC_1024_7_7 = 20
#----------------------------------------------------------------
#
# MACROS: define local vars and configure stack
#
#----------------------------------------------------------------
# declare allocated space on the stack
.macro StackVar localName,localSize
\localName  =   _STK_OFFS_
_STK_OFFS_  =   _STK_OFFS_+(\localSize)
.endm #StackVar
#
#----------------------------------------------------------------
#
# MACRO: Configure stack frame, allocate local vars
#
.macro Setup_Stack BLK_BITS,KS_CNT,debugCnt
    WCNT    =    (\BLK_BITS)/64
#
_PushCnt_   =   0                   #save nonvolatile regs on stack
  .irp _reg_,rbp,rbx,r12,r13,r14,r15
       pushq    %\_reg_
_PushCnt_ = _PushCnt_ + 1           #track count to keep alignment
  .endr
#
_STK_OFFS_  =   0                   #starting offset from rsp
    #---- local  variables         #<-- rsp
    StackVar    X_stk  ,8*(WCNT)    #local context vars
    StackVar    ksTwk  ,8*3         #key schedule: tweak words
    StackVar    ksKey  ,8*(WCNT)+8  #key schedule: key   words
  .if (SKEIN_ASM_UNROLL && (\BLK_BITS)) == 0
    StackVar    ksRot ,16*(\KS_CNT) #leave space for "rotation" to happen
  .endif
    StackVar    Wcopy  ,8*(WCNT)    #copy of input block    
  .if ((8*_PushCnt_ + _STK_OFFS_) % 8) == 0
    StackVar    align16,8           #keep 16-byte aligned (adjust for retAddr?)
tmpStk_\BLK_BITS = align16          #use this
  .endif
    #---- saved caller parameters (from regs rdi, rsi, rdx, rcx)
    StackVar    ctxPtr ,8           #context ptr
    StackVar    blkPtr ,8           #pointer to block data
    StackVar    blkCnt ,8           #number of full blocks to process
    StackVar    bitAdd ,8           #bit count to add to tweak
LOCAL_SIZE  =   _STK_OFFS_          #size of "local" vars
    #---- 
    StackVar    savRegs,8*_PushCnt_ #saved registers
    StackVar    retAddr,8           #return address
    #---- caller's stack frame (aligned mod 16)
#
# set up the stack frame pointer (rbp)
#
FRAME_OFFS  =   ksTwk + 128         #allow short (negative) offset to ksTwk, kwKey
  .if FRAME_OFFS > _STK_OFFS_       #keep rbp in the "locals" range
FRAME_OFFS  =      _STK_OFFS_
  .endif
F_O         =   -FRAME_OFFS
#
  #put some useful defines in the .lst file (for grep)
__STK_LCL_SIZE_\BLK_BITS = LOCAL_SIZE
__STK_TOT_SIZE_\BLK_BITS = _STK_OFFS_
__STK_FRM_OFFS_\BLK_BITS = FRAME_OFFS
#
# Notes on stack frame setup:
#   * the most frequently used variable is X_stk[], based at [rsp+0]
#   * the next most used is the key schedule arrays, ksKey and ksTwk
#       so rbp is "centered" there, allowing short offsets to the key 
#       schedule even in 1024-bit Skein case
#   * the Wcopy variables are infrequently accessed, but they have long 
#       offsets from both rsp and rbp only in the 1024-bit case.
#   * all other local vars and calling parameters can be accessed 
#       with short offsets, except in the 1024-bit case
#
    subq    $LOCAL_SIZE,%rsp        #make room for the locals
    leaq    FRAME_OFFS(%rsp),%rbp   #maximize use of short offsets
    movq    %rdi, ctxPtr+F_O(%rbp)  #save caller's parameters on the stack
    movq    %rsi, blkPtr+F_O(%rbp)
    movq    %rdx, blkCnt+F_O(%rbp)
    movq    %rcx, bitAdd+F_O(%rbp)
#
.endm #Setup_Stack
#
#----------------------------------------------------------------
#
.macro Reset_Stack
    addq    $LOCAL_SIZE,%rsp        #get rid of locals (wipe)
  .irp _reg_,r15,r14,r13,r12,rbx,rbp
    popq    %\_reg_                 #restore caller's regs
_PushCnt_ = _PushCnt_ - 1
  .endr
  .if _PushCnt_
    .error  "Mismatched push/pops?"
  .endif
.endm # Reset_Stack
#
#----------------------------------------------------------------
#
.macro  addReg dstReg,srcReg_A,srcReg_B,useAddOp,immOffs
  .if \immOffs + 0
       leaq    \immOffs(%\srcReg_A\srcReg_B,%\dstReg),%\dstReg
  .elseif ((\useAddOp + 0) == 0)
    .ifndef ASM_NO_LEA  #lea seems to be faster on Core 2 Duo CPUs!
       leaq   (%\srcReg_A\srcReg_B,%\dstReg),%\dstReg
    .else
       addq    %\srcReg_A\srcReg_B,%\dstReg
    .endif
  .else
       addq    %\srcReg_A\srcReg_B,%\dstReg
  .endif
.endm

# keep Intel-style ordering here, to match addReg
.macro  xorReg dstReg,srcReg_A,srcReg_B
        xorq   %\srcReg_A\srcReg_B,%\dstReg
.endm

# SkeinMix
.macro skeinMix a,b,c
	addReg	\a,\b
	rolq	\c,%\b
	xorReg	\b,\a
.endm
#
#----------------------------------------------------------------
#
.macro C_label lName
 \lName:        #use both "genders" to work across linkage conventions
_\lName:
    .global  \lName
    .global _\lName
.endm
#
#=================================== Skein_256 =============================================
#
.if _USE_ASM_ & 256
#
# void Skein_256_Process_Block(Skein_256_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)#
#
#################
#
# code
#
C_label Skein_256_Process_Block
    Setup_Stack 256,((ROUNDS_256/8)+1)
    movq    TWEAK+8(%rdi),%r14
    jmp     Skein_256_block_loop
    .p2align 4
    # main hash loop for Skein_256
Skein_256_block_loop:
    #
    # general register usage:
    #   RAX..RDX        = X0..X3    
    #   R08..R12        = ks[0..4]
    #   R13..R15        = ts[0..2]
    #   RSP, RBP        = stack/frame pointers
    #   RDI             = round counter or context pointer
    #   RSI             = temp
    #
    movq    TWEAK+0(%rdi)     ,%r13
    addq    bitAdd+F_O(%rbp)  ,%r13  #computed updated tweak value T0
    movq    %r14              ,%r15
    xorq    %r13              ,%r15  #now %r13.%r15 is set as the tweak 

    movq    $KW_PARITY        ,%r12
    movq       X_VARS+ 0(%rdi),%r8
    movq       X_VARS+ 8(%rdi),%r9 
    movq       X_VARS+16(%rdi),%r10
    movq       X_VARS+24(%rdi),%r11
    movq    %r13,TWEAK+0(%rdi)       #save updated tweak value ctx->h.T[0]
    xorq    %r8               ,%r12  #start accumulating overall parity

    movq    blkPtr +F_O(%rbp) ,%rsi  #esi --> input block
    xorq    %r9               ,%r12
    movq     0(%rsi)          ,%rax  #get X[0..3]
    xorq    %r10              ,%r12
    movq     8(%rsi)          ,%rbx
    xorq    %r11              ,%r12
    movq    16(%rsi)          ,%rcx
    movq    24(%rsi)          ,%rdx

    movq    %rax,Wcopy+ 0+F_O(%rbp)  #save copy of input block
    movq    %rbx,Wcopy+ 8+F_O(%rbp)    
    movq    %rcx,Wcopy+16+F_O(%rbp)    
    movq    %rdx,Wcopy+24+F_O(%rbp)    

    addq    %r8 ,%rax                #initial key injection
    addq    %r9 ,%rbx 
    addq    %r10,%rcx
    addq    %r11,%rdx
    addq    %r13,%rbx
    addq    %r14,%rcx

    addq    $WCNT*8,%rsi             #skip the block
    movq    %rsi,blkPtr  +F_O(%rbp)  #update block pointer
    #
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_256/8


	# round 0
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r11,%r15),%rdi

	# round 1
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r10,%r14),%rsi

	#round 2
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 3
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r9, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 1(%r12,%rdx),%rdx

	# round 4
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r12,%r13),%rdi

	# round 5
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r11,%r15),%rsi

	#round 6
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 7
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r10, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 2(%r8,%rdx),%rdx

	# round 8
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r8,%r14),%rdi

	# round 9
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r12,%r13),%rsi

	#round 10
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 11
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r11, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 3(%r9,%rdx),%rdx

	# round 12
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r9,%r15),%rdi

	# round 13
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r8,%r14),%rsi

	#round 14
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 15
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r12, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 4(%r10,%rdx),%rdx

	# round 16
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r10,%r13),%rdi

	# round 17
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r9,%r15),%rsi

	#round 18
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 19
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r8, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 5(%r11,%rdx),%rdx

	# round 20
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r11,%r14),%rdi

	# round 21
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r10,%r13),%rsi

	#round 22
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 23
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r9, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 6(%r12,%rdx),%rdx

	# round 24
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r12,%r15),%rdi

	# round 25
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r11,%r14),%rsi

	#round 26
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 27
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r10, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 7(%r8,%rdx),%rdx

	# round 28
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r8,%r13),%rdi

	# round 29
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r12,%r15),%rsi

	#round 30
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 31
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r11, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 8(%r9,%rdx),%rdx

	# round 32
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r9,%r14),%rdi

	# round 33
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r8,%r13),%rsi

	#round 34
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 35
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r12, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 9(%r10,%rdx),%rdx

	# round 36
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r10,%r15),%rdi

	# round 37
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r9,%r14),%rsi

	#round 38
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 39
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r8, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 10(%r11,%rdx),%rdx

	# round 40
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r11,%r13),%rdi

	# round 41
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r10,%r15),%rsi

	#round 42
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 43
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r9, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 11(%r12,%rdx),%rdx

	# round 44
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r12,%r14),%rdi

	# round 45
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r11,%r13),%rsi

	#round 46
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 47
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r10, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 12(%r8,%rdx),%rdx

	# round 48
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r8,%r15),%rdi

	# round 49
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r12,%r14),%rsi

	#round 50
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 51
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r11, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 13(%r9,%rdx),%rdx

	# round 52
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r9,%r13),%rdi

	# round 53
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r8,%r15),%rsi

	#round 54
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 55
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r12, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 14(%r10,%rdx),%rdx

	# round 56
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r10,%r14),%rdi

	# round 57
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r9,%r13),%rsi

	#round 58
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 59
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r8, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 15(%r11,%rdx),%rdx

	# round 60
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r11,%r15),%rdi

	# round 61
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r10,%r14),%rsi

	#round 62
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 63
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r9, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 16(%r12,%rdx),%rdx

	# round 64
	leaq (%rbx, %rax),%rax
	rolq $RC_256_0_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_0_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r12,%r13),%rdi

	# round 65
	leaq (%rdx, %rax),%rax
	rolq $RC_256_1_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_1_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r11,%r15),%rsi

	#round 66
	leaq (%rbx, %rax),%rax
	rolq $RC_256_2_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_2_1,%rdx
	xorq %rcx, %rdx

	#round 67
	leaq (%rdx, %rax),%rax
	rolq $RC_256_3_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_3_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r10, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 17(%r8,%rdx),%rdx

	# round 68
	leaq (%rbx, %rax),%rax
	rolq $RC_256_4_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_4_1,%rdx
	xorq %rcx, %rdx

	#precompute key injection value for %rcx
	leaq (%r8,%r14),%rdi

	# round 69
	leaq (%rdx, %rax),%rax
	rolq $RC_256_5_0,%rdx
	xorq %rax, %rdx
	leaq (%rbx, %rcx),%rcx
	rolq $RC_256_5_1,%rbx
	xorq %rcx, %rbx

	#precompute key injection value for %rbx
	leaq (%r12,%r13),%rsi

	#round 70
	leaq (%rbx, %rax),%rax
	rolq $RC_256_6_0,%rbx
	leaq (%rdx, %rcx),%rcx
	xorq %rax, %rbx
	rolq $RC_256_6_1,%rdx
	xorq %rcx, %rdx

	#round 71
	leaq (%rdx, %rax),%rax
	rolq $RC_256_7_0,%rdx
	leaq (%rbx, %rcx),%rcx
	xorq %rax, %rdx
	rolq $RC_256_7_1,%rbx
	xorq %rcx, %rbx

	# Key injection
	leaq (%r11, %rax),%rax
	leaq (%rsi, %rbx),%rbx
	leaq (%rdi, %rcx),%rcx
	leaq 18(%r9,%rdx),%rdx

#
    movq    ctxPtr +F_O(%rbp),%rdi           #restore rdi --> context

    #----------------------------
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..3}
    movq    $FIRST_MASK64 ,%r14
    xorq    Wcopy + 0+F_O (%rbp),%rax
    xorq    Wcopy + 8+F_O (%rbp),%rbx
    xorq    Wcopy +16+F_O (%rbp),%rcx
    xorq    Wcopy +24+F_O (%rbp),%rdx
    andq    TWEAK + 8     (%rdi),%r14
    movq    %rax,X_VARS+ 0(%rdi)             #store final result
    movq    %rbx,X_VARS+ 8(%rdi)        
    movq    %rcx,X_VARS+16(%rdi)        
    movq    %rdx,X_VARS+24(%rdi)        

    # go back for more blocks, if needed
    decq    blkCnt+F_O(%rbp)
    jnz     Skein_256_block_loop
    movq    %r14,TWEAK + 8(%rdi)
    Reset_Stack
    ret
Skein_256_Process_Block_End:

#
.if _SKEIN_CODE_SIZE
C_label  Skein_256_Process_Block_CodeSize
    movq    $(Skein_256_Process_Block_End-Skein_256_Process_Block),%rax
    ret
#
C_label Skein_256_Unroll_Cnt
  .if _UNROLL_CNT <> ROUNDS_256/8
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif #_USE_ASM_ & 256
#
#=================================== Skein_512 =============================================
#
.if _USE_ASM_ & 512
#
# void Skein_512_Process_Block(Skein_512_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)
#
# X[i] == %r[8+i]          #register assignments for X[] values during rounds (i=0..7)
#
#################
# instantiated code
#
C_label Skein_512_Process_Block
    Setup_Stack 512,ROUNDS_512/8
    movq    TWEAK+ 8(%rdi),%rbx
    jmp     Skein_512_block_loop
    .p2align 4
    # main hash loop for Skein_512
Skein_512_block_loop:
    # general register usage:
    #   RAX..RDX       = temps for key schedule pre-loads
    #   R8 ..R15       = X0..X7
    #   RSP, RBP       = stack/frame pointers
    #   RDI            = round counter or context pointer
    #   RSI            = temp
    #
    movq    TWEAK +  0(%rdi),%rax
    addq    bitAdd+F_O(%rbp),%rax     #computed updated tweak value T0
    movq    %rbx,%rcx
    xorq    %rax,%rcx                 #%rax/%rbx/%rcx = tweak schedule
    movq    %rax,TWEAK+ 0    (%rdi)   #save updated tweak value ctx->h.T[0]
    movq    %rax,ksTwk+ 0+F_O(%rbp)
    movq    $KW_PARITY,%rdx
    movq    blkPtr +F_O(%rbp),%rsi    #%rsi --> input block
    movq    %rbx,ksTwk+ 8+F_O(%rbp)
    movq    %rcx,ksTwk+16+F_O(%rbp)
    .irp _Rn_,8,9,10,11,12,13,14,15
      movq  X_VARS+8*(\_Rn_-8)(%rdi),%r\_Rn_
      xorq  %r\_Rn_,%rdx              #compute overall parity
      movq  %r\_Rn_,ksKey+8*(\_Rn_-8)+F_O(%rbp)
    .endr                             #load state into %r8 ..%r15, compute parity
      movq  %rdx,ksKey+8*(8)+F_O(%rbp)#save key schedule parity

    addReg   r13,rax                  #precompute key injection for tweak
    addReg   r14, rbx
    movq     0(%rsi),%rax             #load input block
    movq     8(%rsi),%rbx 
    movq    16(%rsi),%rcx 
    movq    24(%rsi),%rdx 
    addReg   r8 , rax                 #do initial key injection
    addReg   r9 , rbx
    movq    %rax,Wcopy+ 0+F_O(%rbp)   #keep local copy for feedforward
    movq    %rbx,Wcopy+ 8+F_O(%rbp)
    addReg   r10, rcx
    addReg   r11, rdx
    movq    %rcx,Wcopy+16+F_O(%rbp)
    movq    %rdx,Wcopy+24+F_O(%rbp)

    movq    32(%rsi),%rax
    movq    40(%rsi),%rbx 
    movq    48(%rsi),%rcx 
    movq    56(%rsi),%rdx
    addReg   r12, rax
    addReg   r13, rbx
    addReg   r14, rcx
    addReg   r15, rdx
    movq    %rax,Wcopy+32+F_O(%rbp)    
    movq    %rbx,Wcopy+40+F_O(%rbp)    
    movq    %rcx,Wcopy+48+F_O(%rbp)    
    movq    %rdx,Wcopy+56+F_O(%rbp)    

    addq    $8*WCNT,%rsi              #skip the block
    movq    %rsi,blkPtr+F_O(%rbp)     #update block pointer
    #
    #################
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_512/8


	#Round 0
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((1)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((1)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 1
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((1)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((1)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 2
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((1)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((1)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 3
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((1)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((1)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((1)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((1)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 1(%rsi,%r15),%r15

	#Round 4
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((2)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((2)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 5
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((2)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((2)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 6
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((2)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((2)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 7
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((2)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((2)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((2)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((2)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 2(%rsi,%r15),%r15

	#Round 8
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((3)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((3)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 9
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((3)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((3)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 10
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((3)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((3)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 11
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((3)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((3)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((3)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((3)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 3(%rsi,%r15),%r15

	#Round 12
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((4)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((4)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 13
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((4)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((4)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 14
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((4)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((4)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 15
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((4)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((4)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((4)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((4)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 4(%rsi,%r15),%r15

	#Round 16
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((5)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((5)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 17
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((5)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((5)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 18
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((5)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((5)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 19
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((5)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((5)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((5)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((5)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 5(%rsi,%r15),%r15

	#Round 20
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((6)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((6)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 21
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((6)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((6)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 22
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((6)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((6)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 23
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((6)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((6)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((6)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((6)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 6(%rsi,%r15),%r15

	#Round 24
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((7)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((7)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 25
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((7)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((7)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 26
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((7)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((7)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 27
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((7)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((7)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((7)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((7)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 7(%rsi,%r15),%r15

	#Round 28
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((8)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((8)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 29
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((8)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((8)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 30
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((8)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((8)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 31
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((8)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((8)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((8)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((8)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 8(%rsi,%r15),%r15

	#Round 32
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((9)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((9)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 33
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((9)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((9)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 34
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((9)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((9)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 35
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((9)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((9)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((9)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((9)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 9(%rsi,%r15),%r15

	#Round 36
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((10)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((10)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 37
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((10)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((10)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 38
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((10)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((10)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 39
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((10)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((10)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((10)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((10)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 10(%rsi,%r15),%r15

	#Round 40
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((11)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((11)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 41
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((11)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((11)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 42
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((11)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((11)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 43
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((11)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((11)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((11)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((11)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 11(%rsi,%r15),%r15

	#Round 44
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((12)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((12)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 45
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((12)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((12)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 46
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((12)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((12)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 47
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((12)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((12)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((12)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((12)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 12(%rsi,%r15),%r15

	#Round 48
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((13)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((13)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 49
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((13)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((13)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 50
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((13)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((13)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 51
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((13)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((13)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((13)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((13)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 13(%rsi,%r15),%r15

	#Round 52
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((14)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((14)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 53
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((14)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((14)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 54
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((14)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((14)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 55
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((14)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((14)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((14)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((14)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 14(%rsi,%r15),%r15

	#Round 56
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((15)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((15)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 57
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((15)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((15)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 58
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((15)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((15)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 59
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((15)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((15)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((15)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((15)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 15(%rsi,%r15),%r15

	#Round 60
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((16)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((16)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 61
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((16)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((16)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 62
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((16)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((16)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 63
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((16)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((16)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((16)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((16)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 16(%rsi,%r15),%r15

	#Round 64
	leaq (%r9, %r8),%r8
	rolq $RC_512_0_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((17)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_0_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_0_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((17)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_0_3,%r15
	xorq %r14, %r15

	# Round 65
	leaq (%r9, %r10),%r10
	rolq $RC_512_1_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((17)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_1_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_1_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((17)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_1_3,%r11
	xorq %r8, %r11

	# Round 66
	leaq (%r9, %r12),%r12
	rolq $RC_512_2_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((17)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_2_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_2_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((17)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_2_3,%r15
	xorq %r10, %r15

	# Round 67
	leaq (%r9, %r14),%r14
	rolq $RC_512_3_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((17)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_3_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_3_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_3_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((17)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((17)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((17)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 17(%rsi,%r15),%r15

	#Round 68
	leaq (%r9, %r8),%r8
	rolq $RC_512_4_0,%r9
	xorq %r8, %r9
	movq ksKey+8*(((18)+3) % 9)+F_O(%rbp),%rax
	leaq (%r11, %r10),%r10
	rolq $RC_512_4_1,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_512_4_2,%r13
	xorq %r12, %r13
	movq ksKey+8*(((18)+4) % 9)+F_O(%rbp),%rbx
	leaq (%r15, %r14),%r14
	rolq $RC_512_4_3,%r15
	xorq %r14, %r15

	# Round 69
	leaq (%r9, %r10),%r10
	rolq $RC_512_5_0,%r9
	xorq %r10, %r9
	movq ksKey+8*(((18)+5) % 9)+F_O(%rbp),%rcx
	leaq (%r15, %r12),%r12
	rolq $RC_512_5_1,%r15
	xorq %r12, %r15
	leaq (%r13, %r14),%r14
	rolq $RC_512_5_2,%r13
	xorq %r14, %r13
	movq ksKey+8*(((18)+6) % 9)+F_O(%rbp),%rdx
	leaq (%r11, %r8),%r8
	rolq $RC_512_5_3,%r11
	xorq %r8, %r11

	# Round 70
	leaq (%r9, %r12),%r12
	rolq $RC_512_6_0,%r9
	xorq %r12, %r9
	movq ksKey+8*(((18)+7) % 9)+F_O(%rbp),%rsi
	leaq (%r11, %r14),%r14
	rolq $RC_512_6_1,%r11
	xorq %r14, %r11
	leaq (%r13, %r8),%r8
	rolq $RC_512_6_2,%r13
	xorq %r8, %r13
	addq ksTwk+8*(((18)+0) % 3)+F_O(%rbp),%rcx
	leaq (%r15, %r10),%r10
	rolq $RC_512_6_3,%r15
	xorq %r10, %r15

	# Round 71
	leaq (%r9, %r14),%r14
	rolq $RC_512_7_0,%r9
	xorq %r14, %r9
	addq ksTwk+8*(((18)+1)%3)+F_O(%rbp),%rdx
	leaq (%r15, %r8),%r8
	rolq $RC_512_7_1,%r15
	xorq %r8, %r15
	leaq (%r13, %r10),%r10
	rolq $RC_512_7_2,%r13
	xorq %r10, %r13
	leaq (%r11, %r12),%r12
	rolq $RC_512_7_3,%r11
	xorq %r12, %r11

	# inject the key schedule
	addq	ksKey+8*(((18)+0)%9)+F_O(%rbp),%r8
	leaq (%rax, %r11),%r11
	addq	ksKey+8*(((18)+1)%9)+F_O(%rbp),%r9
	leaq (%rbx, %r12),%r12
	addq	ksKey+8*(((18)+2)%9)+F_O(%rbp),%r10
	leaq (%rcx, %r13),%r13
	leaq (%rdx, %r14),%r14
	leaq 18(%rsi,%r15),%r15
    # end of rounds
    #################
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..7}
    .irp _Rn_,8,9,10,11,12,13,14,15
  .if (\_Rn_ == 8)
    movq    $FIRST_MASK64,%rbx
  .endif
      xorq  Wcopy+8*(\_Rn_-8)+F_O(%rbp),%r\_Rn_  #feedforward XOR
      movq  %r\_Rn_,X_VARS+8*(\_Rn_-8)(%rdi)     #and store result
  .if (\_Rn_ == 14)
    andq    TWEAK+ 8(%rdi),%rbx
  .endif
    .endr

    # go back for more blocks, if needed
    decq    blkCnt+F_O(%rbp)
    jnz     Skein_512_block_loop
    movq    %rbx,TWEAK + 8(%rdi)

    Reset_Stack
    ret
Skein_512_Process_Block_End:
#
#
.if _SKEIN_CODE_SIZE
C_label Skein_512_Process_Block_CodeSize
    movq    $(Skein_512_Process_Block_End-Skein_512_Process_Block),%rax
    ret
#
C_label Skein_512_Unroll_Cnt
  .if _UNROLL_CNT <> (ROUNDS_512/8)
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif # _USE_ASM_ & 512
#
#=================================== Skein1024 =============================================
.if _USE_ASM_ & 1024
#
# void Skein1024_Process_Block(Skein_1024_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)#
#
#################
# use details of permutation to make register assignments
# 
o1K_rdi =  0        #offsets in X[] associated with each register
o1K_rsi =  1 
o1K_rbp =  2 
o1K_rax =  3 
o1K_rcx =  4        #rcx is "shared" with X6, since X4/X6 alternate
o1K_rbx =  5 
o1K_rdx =  7 
o1K_r8  =  8  
o1K_r9  =  9  
o1K_r10 = 10
o1K_r11 = 11
o1K_r12 = 12
o1K_r13 = 13
o1K_r14 = 14
o1K_r15 = 15
#
rIdx_offs = tmpStk_1024
#
################
# code
#
C_label Skein1024_Process_Block
#
    Setup_Stack 1024,((ROUNDS_1024/8)+1),WCNT
    movq    TWEAK+ 8(%rdi),%r9
    jmp     Skein1024_block_loop
    # main hash loop for Skein1024
    .p2align 4
Skein1024_block_loop:
    # general register usage:
    #   RSP              = stack pointer
    #   RAX..RDX,RSI,RDI = X1, X3..X7 (state words)
    #   R8 ..R15         = X8..X15    (state words)
    #   RBP              = temp (used for X0 and X2)
    #
    movq         TWEAK+     0(%rdi),%r8
    addq         bitAdd+  F_O(%rbp),%r8    #computed updated tweak value T0
    movq    %r9 ,%r10 
    xorq    %r8 ,%r10                      #%rax/%rbx/%rcx = tweak schedule
    movq    %r8 ,TWEAK+     0(%rdi)        #save updated tweak value ctx->h.T[0]
    movq    %r8 ,ksTwk+ 0+F_O(%rbp)
    movq    %r9 ,ksTwk+ 8+F_O(%rbp)        #keep values in %r8 ,%r9  for initial tweak injection below
    movq    %r10,ksTwk+16+F_O(%rbp)
    movq         blkPtr +F_O(%rbp),%rsi    # rsi --> input block
    movq        $KW_PARITY        ,%rax    #overall key schedule parity

    # the logic here assumes the set {rdi,rsi,rbp,rax} = X[0,1,2,3]
    .irp _rN_,0,1,2,3,4,6                  #process the "initial" words, using r14/r15 as temps
      movq       X_VARS+8*\_rN_(%rdi),%r14  #get state word
      movq              8*\_rN_(%rsi),%r15  #get msg   word
      xorq  %r14,%rax                      #update key schedule overall parity
      movq  %r14,ksKey +8*\_rN_+F_O(%rbp)   #save key schedule word on stack
      movq  %r15,Wcopy +8*\_rN_+F_O(%rbp)   #save local msg Wcopy 
      addq  %r15,%r14                      #do the initial key injection
      movq  %r14,X_stk +8*\_rN_    (%rsp)   #save initial state var on stack
    .endr
    # now process the rest, using the "real" registers 
    #     (MUST do it in reverse order to inject tweaks r8/r9 first)
    .irp _rr_,r15,r14,r13,r12,r11,r10,r9,r8,rdx,rbx
_oo_ = o1K_\_rr_                           #offset assocated with the register
      movq  X_VARS+8*_oo_(%rdi),%\_rr_     #get key schedule word from context
      movq         8*_oo_(%rsi),%rcx       #get next input msg word
      movq  %\_rr_, ksKey +8*_oo_(%rsp)    #save key schedule on stack
      xorq  %\_rr_, %rax                   #accumulate key schedule parity
      movq  %rcx,Wcopy+8*_oo_+F_O(%rbp)    #save copy of msg word for feedforward
      addq  %rcx,%\_rr_                    #do the initial  key  injection
      .if    _oo_ == 13                    #do the initial tweak injection
        addReg \_rr_,r8                     #          (only in words 13/14)
      .elseif _oo_ == 14
        addReg \_rr_,r9 
      .endif
    .endr
    movq    %rax,ksKey+8*WCNT+F_O(%rbp)    #save key schedule parity
    addq     $8*WCNT,%rsi                  #bump the msg ptr
    movq     %rsi,blkPtr+F_O(%rbp)         #save bumped msg ptr
    # re-load words 0..4 from stack, enter the main loop
    .irp _rr_,rdi,rsi,rbp,rax,rcx          #(no need to re-load x6, already on stack)
      movq  X_stk+8*o1K_\_rr_(%rsp),%\_rr_ #re-load state and get ready to go!
    .endr
    #
    #################
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_1024/8


	# round 0
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 1
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 2
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 3
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((1+0) % 17)(%rsp),%rdi
	addq ksKey+8*((1+15) % 17)(%rsp),%r15
	addq	$1,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((1+2) % 17)(%rsp),%rbp
	addq ksKey+8*((1+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((1+6) % 17)(%rsp),%rcx
	addq ksKey+8*((1+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((1+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((1+14) % 17)(%rsp),%r14
	addq ksKey+8*((1+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((1+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((1+8) % 17)(%rsp),%r8
	addq ksKey+8*((1+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((1+10) % 17)(%rsp),%r10
	addq ksKey+8*((1+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((1+4) % 17)(%rsp),%rcx
	addq ksKey+8*((1+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((1+12) % 17)(%rsp),%r12
	addq ksKey+8*((1+7) % 17)(%rsp),%rdx

	# round 4
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 5
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 6
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 7
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((2+0) % 17)(%rsp),%rdi
	addq ksKey+8*((2+15) % 17)(%rsp),%r15
	addq	$2,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((2+2) % 17)(%rsp),%rbp
	addq ksKey+8*((2+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((2+6) % 17)(%rsp),%rcx
	addq ksKey+8*((2+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((2+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((2+14) % 17)(%rsp),%r14
	addq ksKey+8*((2+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((2+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((2+8) % 17)(%rsp),%r8
	addq ksKey+8*((2+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((2+10) % 17)(%rsp),%r10
	addq ksKey+8*((2+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((2+4) % 17)(%rsp),%rcx
	addq ksKey+8*((2+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((2+12) % 17)(%rsp),%r12
	addq ksKey+8*((2+7) % 17)(%rsp),%rdx

	# round 8
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 9
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 10
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 11
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((3+0) % 17)(%rsp),%rdi
	addq ksKey+8*((3+15) % 17)(%rsp),%r15
	addq	$3,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((3+2) % 17)(%rsp),%rbp
	addq ksKey+8*((3+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((3+6) % 17)(%rsp),%rcx
	addq ksKey+8*((3+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((3+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((3+14) % 17)(%rsp),%r14
	addq ksKey+8*((3+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((3+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((3+8) % 17)(%rsp),%r8
	addq ksKey+8*((3+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((3+10) % 17)(%rsp),%r10
	addq ksKey+8*((3+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((3+4) % 17)(%rsp),%rcx
	addq ksKey+8*((3+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((3+12) % 17)(%rsp),%r12
	addq ksKey+8*((3+7) % 17)(%rsp),%rdx

	# round 12
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 13
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 14
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 15
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((4+0) % 17)(%rsp),%rdi
	addq ksKey+8*((4+15) % 17)(%rsp),%r15
	addq	$4,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((4+2) % 17)(%rsp),%rbp
	addq ksKey+8*((4+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((4+6) % 17)(%rsp),%rcx
	addq ksKey+8*((4+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((4+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((4+14) % 17)(%rsp),%r14
	addq ksKey+8*((4+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((4+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((4+8) % 17)(%rsp),%r8
	addq ksKey+8*((4+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((4+10) % 17)(%rsp),%r10
	addq ksKey+8*((4+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((4+4) % 17)(%rsp),%rcx
	addq ksKey+8*((4+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((4+12) % 17)(%rsp),%r12
	addq ksKey+8*((4+7) % 17)(%rsp),%rdx

	# round 16
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 17
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 18
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 19
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((5+0) % 17)(%rsp),%rdi
	addq ksKey+8*((5+15) % 17)(%rsp),%r15
	addq	$5,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((5+2) % 17)(%rsp),%rbp
	addq ksKey+8*((5+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((5+6) % 17)(%rsp),%rcx
	addq ksKey+8*((5+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((5+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((5+14) % 17)(%rsp),%r14
	addq ksKey+8*((5+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((5+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((5+8) % 17)(%rsp),%r8
	addq ksKey+8*((5+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((5+10) % 17)(%rsp),%r10
	addq ksKey+8*((5+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((5+4) % 17)(%rsp),%rcx
	addq ksKey+8*((5+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((5+12) % 17)(%rsp),%r12
	addq ksKey+8*((5+7) % 17)(%rsp),%rdx

	# round 20
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 21
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 22
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 23
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((6+0) % 17)(%rsp),%rdi
	addq ksKey+8*((6+15) % 17)(%rsp),%r15
	addq	$6,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((6+2) % 17)(%rsp),%rbp
	addq ksKey+8*((6+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((6+6) % 17)(%rsp),%rcx
	addq ksKey+8*((6+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((6+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((6+14) % 17)(%rsp),%r14
	addq ksKey+8*((6+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((6+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((6+8) % 17)(%rsp),%r8
	addq ksKey+8*((6+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((6+10) % 17)(%rsp),%r10
	addq ksKey+8*((6+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((6+4) % 17)(%rsp),%rcx
	addq ksKey+8*((6+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((6+12) % 17)(%rsp),%r12
	addq ksKey+8*((6+7) % 17)(%rsp),%rdx

	# round 24
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 25
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 26
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 27
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((7+0) % 17)(%rsp),%rdi
	addq ksKey+8*((7+15) % 17)(%rsp),%r15
	addq	$7,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((7+2) % 17)(%rsp),%rbp
	addq ksKey+8*((7+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((7+6) % 17)(%rsp),%rcx
	addq ksKey+8*((7+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((7+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((7+14) % 17)(%rsp),%r14
	addq ksKey+8*((7+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((7+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((7+8) % 17)(%rsp),%r8
	addq ksKey+8*((7+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((7+10) % 17)(%rsp),%r10
	addq ksKey+8*((7+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((7+4) % 17)(%rsp),%rcx
	addq ksKey+8*((7+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((7+12) % 17)(%rsp),%r12
	addq ksKey+8*((7+7) % 17)(%rsp),%rdx

	# round 28
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 29
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 30
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 31
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((8+0) % 17)(%rsp),%rdi
	addq ksKey+8*((8+15) % 17)(%rsp),%r15
	addq	$8,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((8+2) % 17)(%rsp),%rbp
	addq ksKey+8*((8+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((8+6) % 17)(%rsp),%rcx
	addq ksKey+8*((8+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((8+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((8+14) % 17)(%rsp),%r14
	addq ksKey+8*((8+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((8+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((8+8) % 17)(%rsp),%r8
	addq ksKey+8*((8+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((8+10) % 17)(%rsp),%r10
	addq ksKey+8*((8+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((8+4) % 17)(%rsp),%rcx
	addq ksKey+8*((8+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((8+12) % 17)(%rsp),%r12
	addq ksKey+8*((8+7) % 17)(%rsp),%rdx

	# round 32
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 33
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 34
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 35
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((9+0) % 17)(%rsp),%rdi
	addq ksKey+8*((9+15) % 17)(%rsp),%r15
	addq	$9,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((9+2) % 17)(%rsp),%rbp
	addq ksKey+8*((9+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((9+6) % 17)(%rsp),%rcx
	addq ksKey+8*((9+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((9+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((9+14) % 17)(%rsp),%r14
	addq ksKey+8*((9+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((9+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((9+8) % 17)(%rsp),%r8
	addq ksKey+8*((9+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((9+10) % 17)(%rsp),%r10
	addq ksKey+8*((9+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((9+4) % 17)(%rsp),%rcx
	addq ksKey+8*((9+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((9+12) % 17)(%rsp),%r12
	addq ksKey+8*((9+7) % 17)(%rsp),%rdx

	# round 36
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 37
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 38
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 39
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((10+0) % 17)(%rsp),%rdi
	addq ksKey+8*((10+15) % 17)(%rsp),%r15
	addq	$10,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((10+2) % 17)(%rsp),%rbp
	addq ksKey+8*((10+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((10+6) % 17)(%rsp),%rcx
	addq ksKey+8*((10+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((10+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((10+14) % 17)(%rsp),%r14
	addq ksKey+8*((10+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((10+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((10+8) % 17)(%rsp),%r8
	addq ksKey+8*((10+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((10+10) % 17)(%rsp),%r10
	addq ksKey+8*((10+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((10+4) % 17)(%rsp),%rcx
	addq ksKey+8*((10+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((10+12) % 17)(%rsp),%r12
	addq ksKey+8*((10+7) % 17)(%rsp),%rdx

	# round 40
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 41
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 42
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 43
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((11+0) % 17)(%rsp),%rdi
	addq ksKey+8*((11+15) % 17)(%rsp),%r15
	addq	$11,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((11+2) % 17)(%rsp),%rbp
	addq ksKey+8*((11+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((11+6) % 17)(%rsp),%rcx
	addq ksKey+8*((11+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((11+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((11+14) % 17)(%rsp),%r14
	addq ksKey+8*((11+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((11+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((11+8) % 17)(%rsp),%r8
	addq ksKey+8*((11+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((11+10) % 17)(%rsp),%r10
	addq ksKey+8*((11+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((11+4) % 17)(%rsp),%rcx
	addq ksKey+8*((11+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((11+12) % 17)(%rsp),%r12
	addq ksKey+8*((11+7) % 17)(%rsp),%rdx

	# round 44
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 45
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 46
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 47
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((12+0) % 17)(%rsp),%rdi
	addq ksKey+8*((12+15) % 17)(%rsp),%r15
	addq	$12,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((12+2) % 17)(%rsp),%rbp
	addq ksKey+8*((12+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((12+6) % 17)(%rsp),%rcx
	addq ksKey+8*((12+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((12+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((12+14) % 17)(%rsp),%r14
	addq ksKey+8*((12+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((12+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((12+8) % 17)(%rsp),%r8
	addq ksKey+8*((12+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((12+10) % 17)(%rsp),%r10
	addq ksKey+8*((12+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((12+4) % 17)(%rsp),%rcx
	addq ksKey+8*((12+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((12+12) % 17)(%rsp),%r12
	addq ksKey+8*((12+7) % 17)(%rsp),%rdx

	# round 48
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 49
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 50
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 51
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((13+0) % 17)(%rsp),%rdi
	addq ksKey+8*((13+15) % 17)(%rsp),%r15
	addq	$13,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((13+2) % 17)(%rsp),%rbp
	addq ksKey+8*((13+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((13+6) % 17)(%rsp),%rcx
	addq ksKey+8*((13+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((13+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((13+14) % 17)(%rsp),%r14
	addq ksKey+8*((13+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((13+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((13+8) % 17)(%rsp),%r8
	addq ksKey+8*((13+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((13+10) % 17)(%rsp),%r10
	addq ksKey+8*((13+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((13+4) % 17)(%rsp),%rcx
	addq ksKey+8*((13+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((13+12) % 17)(%rsp),%r12
	addq ksKey+8*((13+7) % 17)(%rsp),%rdx

	# round 52
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 53
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 54
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 55
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((14+0) % 17)(%rsp),%rdi
	addq ksKey+8*((14+15) % 17)(%rsp),%r15
	addq	$14,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((14+2) % 17)(%rsp),%rbp
	addq ksKey+8*((14+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((14+6) % 17)(%rsp),%rcx
	addq ksKey+8*((14+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((14+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((14+14) % 17)(%rsp),%r14
	addq ksKey+8*((14+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((14+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((14+8) % 17)(%rsp),%r8
	addq ksKey+8*((14+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((14+10) % 17)(%rsp),%r10
	addq ksKey+8*((14+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((14+4) % 17)(%rsp),%rcx
	addq ksKey+8*((14+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((14+12) % 17)(%rsp),%r12
	addq ksKey+8*((14+7) % 17)(%rsp),%rdx

	# round 56
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 57
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 58
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 59
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((15+0) % 17)(%rsp),%rdi
	addq ksKey+8*((15+15) % 17)(%rsp),%r15
	addq	$15,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((15+2) % 17)(%rsp),%rbp
	addq ksKey+8*((15+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((15+6) % 17)(%rsp),%rcx
	addq ksKey+8*((15+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((15+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((15+14) % 17)(%rsp),%r14
	addq ksKey+8*((15+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((15+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((15+8) % 17)(%rsp),%r8
	addq ksKey+8*((15+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((15+10) % 17)(%rsp),%r10
	addq ksKey+8*((15+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((15+4) % 17)(%rsp),%rcx
	addq ksKey+8*((15+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((15+12) % 17)(%rsp),%r12
	addq ksKey+8*((15+7) % 17)(%rsp),%rdx

	# round 60
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 61
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 62
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 63
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((16+0) % 17)(%rsp),%rdi
	addq ksKey+8*((16+15) % 17)(%rsp),%r15
	addq	$16,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((16+2) % 17)(%rsp),%rbp
	addq ksKey+8*((16+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((16+6) % 17)(%rsp),%rcx
	addq ksKey+8*((16+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((16+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((16+14) % 17)(%rsp),%r14
	addq ksKey+8*((16+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((16+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((16+8) % 17)(%rsp),%r8
	addq ksKey+8*((16+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((16+10) % 17)(%rsp),%r10
	addq ksKey+8*((16+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((16+4) % 17)(%rsp),%rcx
	addq ksKey+8*((16+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((16+12) % 17)(%rsp),%r12
	addq ksKey+8*((16+7) % 17)(%rsp),%rdx

	# round 64
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 65
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 66
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 67
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((17+0) % 17)(%rsp),%rdi
	addq ksKey+8*((17+15) % 17)(%rsp),%r15
	addq	$17,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((17+2) % 17)(%rsp),%rbp
	addq ksKey+8*((17+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((17+6) % 17)(%rsp),%rcx
	addq ksKey+8*((17+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((17+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((17+14) % 17)(%rsp),%r14
	addq ksKey+8*((17+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((17+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((17+8) % 17)(%rsp),%r8
	addq ksKey+8*((17+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((17+10) % 17)(%rsp),%r10
	addq ksKey+8*((17+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((17+4) % 17)(%rsp),%rcx
	addq ksKey+8*((17+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((17+12) % 17)(%rsp),%r12
	addq ksKey+8*((17+7) % 17)(%rsp),%rdx

	# round 68
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 69
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 70
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 71
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((18+0) % 17)(%rsp),%rdi
	addq ksKey+8*((18+15) % 17)(%rsp),%r15
	addq	$18,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((18+2) % 17)(%rsp),%rbp
	addq ksKey+8*((18+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((18+6) % 17)(%rsp),%rcx
	addq ksKey+8*((18+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((18+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((18+14) % 17)(%rsp),%r14
	addq ksKey+8*((18+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((18+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((18+8) % 17)(%rsp),%r8
	addq ksKey+8*((18+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((18+10) % 17)(%rsp),%r10
	addq ksKey+8*((18+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((18+4) % 17)(%rsp),%rcx
	addq ksKey+8*((18+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((18+12) % 17)(%rsp),%r12
	addq ksKey+8*((18+7) % 17)(%rsp),%rdx

	# round 72
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_0_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_0_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_0_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_0_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_0_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_0_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_0_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_0_7,%r15
	xorq %r14, %r15

	# round 73
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_1_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_1_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_1_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_1_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_1_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_1_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_1_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_1_7,%rsi
	xorq %r8, %rsi

	# round 74
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_2_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_2_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_2_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_2_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_2_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_2_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_2_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_2_7,%r9
	xorq %r10, %r9

	# round 75
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_3_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((19+0) % 17)(%rsp),%rdi
	addq ksKey+8*((19+15) % 17)(%rsp),%r15
	addq	$19,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_3_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((19+2) % 17)(%rsp),%rbp
	addq ksKey+8*((19+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_3_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((19+6) % 17)(%rsp),%rcx
	addq ksKey+8*((19+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((19+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_3_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((19+14) % 17)(%rsp),%r14
	addq ksKey+8*((19+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((19+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_3_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((19+8) % 17)(%rsp),%r8
	addq ksKey+8*((19+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_3_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((19+10) % 17)(%rsp),%r10
	addq ksKey+8*((19+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_3_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((19+4) % 17)(%rsp),%rcx
	addq ksKey+8*((19+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_3_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((19+12) % 17)(%rsp),%r12
	addq ksKey+8*((19+7) % 17)(%rsp),%rdx

	# round 76
	leaq (%rsi, %rdi),%rdi
	rolq $RC_1024_4_0,%rsi
	xorq %rdi, %rsi
	leaq (%rax, %rbp),%rbp
	rolq $RC_1024_4_1,%rax
	xorq %rbp, %rax
	leaq (%rbx, %rcx),%rcx
	rolq $RC_1024_4_2,%rbx
	xorq %rcx, %rbx
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r9, %r8),%r8
	rolq $RC_1024_4_4,%r9
	xorq %r8, %r9
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack 
	leaq (%r11, %r10),%r10
	rolq $RC_1024_4_5,%r11
	xorq %r10, %r11
	leaq (%r13, %r12),%r12
	rolq $RC_1024_4_6,%r13
	xorq %r12, %r13
	leaq (%rdx, %rcx),%rcx
	rolq $RC_1024_4_3,%rdx
	xorq %rcx, %rdx
	leaq (%r15, %r14),%r14
	rolq $RC_1024_4_7,%r15
	xorq %r14, %r15

	# round 77
	leaq (%r9, %rdi),%rdi
	rolq $RC_1024_5_0,%r9
	xorq %rdi, %r9
	leaq (%r13, %rbp),%rbp
	rolq $RC_1024_5_1,%r13
	xorq %rbp, %r13
	leaq (%r11, %rcx),%rcx
	rolq $RC_1024_5_2,%r11
	xorq %rcx, %r11
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rdx, %r10),%r10
	rolq $RC_1024_5_4,%rdx
	xorq %r10, %rdx
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rax, %r12),%r12
	rolq $RC_1024_5_5,%rax
	xorq %r12, %rax
	leaq (%rbx, %r14),%r14
	rolq $RC_1024_5_6,%rbx
	xorq %r14, %rbx
	leaq (%r15, %rcx),%rcx
	rolq $RC_1024_5_3,%r15
	xorq %rcx, %r15
	leaq (%rsi, %r8),%r8
	rolq $RC_1024_5_7,%rsi
	xorq %r8, %rsi

	# round 78
	leaq (%rdx, %rdi),%rdi
	rolq $RC_1024_6_0,%rdx
	xorq %rdi, %rdx
	leaq (%rbx, %rbp),%rbp
	rolq $RC_1024_6_1,%rbx
	xorq %rbp, %rbx
	leaq (%rax, %rcx),%rcx
	rolq $RC_1024_6_2,%rax
	xorq %rcx, %rax
	movq %rcx,X_stk+8*4(%rsp)	#save X4  on  stack (x4/x6 alternate)
	leaq (%r15, %r12),%r12
	rolq $RC_1024_6_4,%r15
	xorq %r12, %r15
	movq X_stk+8*6(%rsp),%rcx	#load X6 from stack
	leaq (%r13, %r14),%r14
	rolq $RC_1024_6_5,%r13
	xorq %r14, %r13
	leaq (%r11, %r8),%r8
	rolq $RC_1024_6_6,%r11
	xorq %r8, %r11
	leaq (%rsi, %rcx),%rcx
	rolq $RC_1024_6_3,%rsi
	xorq %rcx, %rsi
	leaq (%r9, %r10),%r10
	rolq $RC_1024_6_7,%r9
	xorq %r10, %r9

	# round 79
	leaq (%r15, %rdi),%rdi
	rolq $RC_1024_7_0,%r15
	xorq %rdi, %r15
	addq ksKey+8*((20+0) % 17)(%rsp),%rdi
	addq ksKey+8*((20+15) % 17)(%rsp),%r15
	addq	$20,%r15
	leaq (%r11, %rbp),%rbp
	rolq $RC_1024_7_1,%r11
	xorq %rbp, %r11
	addq ksKey+8*((20+2) % 17)(%rsp),%rbp
	addq ksKey+8*((20+11) % 17)(%rsp),%r11
	leaq (%r13, %rcx),%rcx
	rolq $RC_1024_7_2,%r13
	xorq %rcx, %r13
	addq ksKey+8*((20+6) % 17)(%rsp),%rcx
	addq ksKey+8*((20+13) % 17)(%rsp),%r13
	addq	ksTwk+ 8*((20+0) %3)(%rsp),%r13
	movq %rcx,X_stk+8*6(%rsp)	#save X6  on  stack (x4/x6 alternate)
	leaq (%rsi, %r14),%r14
	rolq $RC_1024_7_4,%rsi
	xorq %r14, %rsi
	addq ksKey+8*((20+14) % 17)(%rsp),%r14
	addq ksKey+8*((20+1) % 17)(%rsp),%rsi
	addq ksTwk+ 8*((20+1)%3)(%rsp),%r14
	movq X_stk+8*4(%rsp),%rcx	#load X4 from stack
	leaq (%rbx, %r8),%r8
	rolq $RC_1024_7_5,%rbx
	xorq %r8, %rbx
	addq ksKey+8*((20+8) % 17)(%rsp),%r8
	addq ksKey+8*((20+5) % 17)(%rsp),%rbx
	leaq (%rax, %r10),%r10
	rolq $RC_1024_7_6,%rax
	xorq %r10, %rax
	addq ksKey+8*((20+10) % 17)(%rsp),%r10
	addq ksKey+8*((20+3) % 17)(%rsp),%rax
	leaq (%r9, %rcx),%rcx
	rolq $RC_1024_7_3,%r9
	xorq %rcx, %r9
	addq ksKey+8*((20+4) % 17)(%rsp),%rcx
	addq ksKey+8*((20+9) % 17)(%rsp),%r9
	leaq (%rdx, %r12),%r12
	rolq $RC_1024_7_7,%rdx
	xorq %r12, %rdx
	addq ksKey+8*((20+12) % 17)(%rsp),%r12
	addq ksKey+8*((20+7) % 17)(%rsp),%rdx

    # end of rounds
    #################
    #
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..15}
    movq    %rdx,X_stk+8*o1K_rdx(%rsp) #we need a register. x6 already on stack
    movq       ctxPtr(%rsp),%rdx
    
    .irp _rr_,rdi,rsi,rbp,rax,rcx,rbx,r8,r9,r10,r11,r12,r13,r14,r15   #do all but x6,x7
_oo_ = o1K_\_rr_
      xorq  Wcopy +8*_oo_(%rsp),%\_rr_ #feedforward XOR
      movq  %\_rr_,X_VARS+8*_oo_(%rdx) #save result into context
      .if (_oo_ ==  9)
        movq   $FIRST_MASK64 ,%r9
      .endif
      .if (_oo_ == 14)
        andq   TWEAK+ 8(%rdx),%r9
      .endif
    .endr
    # 
    movq         X_stk +8*6(%rsp),%rax #now process x6,x7 (skipped in .irp above)
    movq         X_stk +8*7(%rsp),%rbx
    xorq         Wcopy +8*6(%rsp),%rax
    xorq         Wcopy +8*7(%rsp),%rbx
    movq    %rax,X_VARS+8*6(%rdx)
    decq             blkCnt(%rsp)      #set zero flag iff done
    movq    %rbx,X_VARS+8*7(%rdx)

    # go back for more blocks, if needed
    movq             ctxPtr(%rsp),%rdi #don't muck with the flags here!
    lea          FRAME_OFFS(%rsp),%rbp
    jnz     Skein1024_block_loop
    movq    %r9 ,TWEAK+   8(%rdx)
    Reset_Stack
    ret
#
Skein1024_Process_Block_End:
#
#
.if _SKEIN_CODE_SIZE
C_label Skein1024_Process_Block_CodeSize
    movq    $(Skein1024_Process_Block_End-Skein1024_Process_Block),%rax
    ret
#
C_label Skein1024_Unroll_Cnt
  .if _UNROLL_CNT <> (ROUNDS_1024/8)
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif # _USE_ASM_ and 1024
#
#----------------------------------------------------------------
#   .section .note.GNU-stack,"",@progbits

    .end
