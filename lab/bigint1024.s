# Using RARS 1.6 / RV32I


.data
.align 2 # 4-byte alignment.
first_case: .word 1
last_case:  .word 10
# uint32_t A[32], B[32], Sum[32], Sub[32], Pro[64], Q[32], R[32];
A:          .space 128
B:          .space 128
Sum:        .space 128
Sub:        .space 128
Pro:        .space 256
Q:          .space 128
R:          .space 128

# Return values saved by main: add carry, sub borrow, div status.
carry:      .word 0
borrow:     .word 0
status:     .word 0

# Output strings for printing.
case_text:  .asciz "\nCase "
newline:    .asciz "\n"
space:      .asciz " "
a_text:     .asciz "A: "
b_text:     .asciz "B: "
sum_text:   .asciz "Sum: "
sub_text:   .asciz "Sub: "
pro_text:   .asciz "Pro: "
q_text:     .asciz "Q: "
r_text:     .asciz "R: "
carry_text: .asciz "carry: "
borrow_text: .asciz "borrow: "
status_text: .asciz "status: "

.text
.globl main
.globl add1024
.globl sub1024
.globl mul1024
.globl div1024


# main: run cases first_case..last_case; s0 = current case (kept across calls).
main:
    # Align the initial RARS stack pointer to 16 bytes.
    andi sp, sp, -16
    la t0, first_case
    lw s0, 0(t0)
main_case:
    mv a0, s0
    jal ra, load_case

    la a0, A
    la a1, B
    la a2, Sum
    # carry = add1024(A, B, Sum);
    jal ra, add1024
    la t0, carry
    sw a0, 0(t0)

    la a0, A
    la a1, B
    la a2, Sub
    # borrow = sub1024(A, B, Sub);
    jal ra, sub1024
    la t0, borrow
    sw a0, 0(t0)

    la a0, A
    la a1, B
    la a2, Pro
    # mul1024(A, B, Pro); always returns 0, so a0 is not saved.
    jal ra, mul1024

    la a0, A
    la a1, B
    la a2, Q
    la a3, R
    # status = div1024(A, B, Q, R);
    jal ra, div1024
    la t0, status
    sw a0, 0(t0)

    # printf("\nCase %d\n", test);
    # only print and main use ecall
    la a0, case_text
    li a7, 4                  # print string
    ecall
    mv a0, s0
    li a7, 1                  # print integer
    ecall
    la a0, newline
    li a7, 4                  # print string
    ecall
    # print_words(name, &X, word count) for every input and result.
    la a0, a_text
    la a1, A
    li a2, 32
    jal ra, print_words

    la a0, b_text
    la a1, B
    li a2, 32
    jal ra, print_words

    la a0, sum_text
    la a1, Sum
    li a2, 32
    jal ra, print_words

    la a0, sub_text
    la a1, Sub
    li a2, 32
    jal ra, print_words

    la a0, pro_text
    la a1, Pro
    li a2, 64
    jal ra, print_words

    la a0, q_text
    la a1, Q
    li a2, 32
    jal ra, print_words

    la a0, r_text
    la a1, R
    li a2, 32
    jal ra, print_words

    la a0, carry_text
    la a1, carry
    li a2, 1
    jal ra, print_words

    la a0, borrow_text
    la a1, borrow
    li a2, 1
    jal ra, print_words

    la a0, status_text
    la a1, status
    li a2, 1
    jal ra, print_words

    addi s0, s0, 1
    la t0, last_case
    lw t0, 0(t0)
    bge t0, s0, main_case

    li a7, 10                 # exit
    ecall

# add1024: a0=&A, a1=&B, a2=&Sum; returns carry in a0. Leaf, no stack frame.
# t0 = words left, t1 = carry.
add1024:
    li t0, 32
    li t1, 0

# for(int i=0; i<32; i++)
add_loop:
    lw t2, 0(a0)              # t2 = A[i]
    lw t3, 0(a1)              # t3 = B[i]
    add t3, t2, t3            # partial = A[i] + B[i]
    sltu t4, t3, t2           # c1 = (partial < A[i])
    add t2, t3, t1            # Sum[i] = partial + carry
    sltu t5, t2, t3           # c2 = (Sum[i] < partial)
    or t1, t4, t5             # carry = c1 | c2
    sw t2, 0(a2)              # write Sum[i]
    addi a0, a0, 4            # i++: advance &A[i], &B[i], &Sum[i]
    addi a1, a1, 4
    addi a2, a2, 4
    addi t0, t0, -1
    bnez t0, add_loop         # while(i < 32)

    mv a0, t1                 # return carry;
    ret

# sub1024: a0=&A, a1=&B, a2=&Sub; returns borrow in a0. Leaf, no stack frame.
# t0 = words left, t1 = borrow.
sub1024:
    li t0, 32
    li t1, 0

# for(int i=0; i<32; i++)
sub_loop:
    lw t2, 0(a0)              # t2 = A[i]
    lw t3, 0(a1)              # t3 = B[i]
    sltu t4, t2, t3           # b1 = (A[i] < B[i])
    sub t2, t2, t3            # partial = A[i] - B[i]
    sltu t5, t2, t1           # b2 = (partial < borrow)
    sub t2, t2, t1            # Sub[i] = partial - borrow
    or t1, t4, t5             # borrow = b1 | b2
    sw t2, 0(a2)              # write Sub[i]
    addi a0, a0, 4            # i++: advance &A[i], &B[i], &Sub[i]
    addi a1, a1, 4
    addi a2, a2, 4
    addi t0, t0, -1
    bnez t0, sub_loop         # while(i < 32)

    mv a0, t1                 # return borrow;
    ret

# mul1024: a0=&A, a1=&B, a2=&Pro; returns 0. Leaf.
# s0 = &B, s1 = &Pro, s2 = i (bit index of B).
# Frame 272 bytes: T[64] at sp+0..255, s0-s2 at sp+256..264.
mul1024:
    addi sp, sp, -272
    sw s0, 256(sp)
    sw s1, 260(sp)
    sw s2, 264(sp)

    mv s0, a1                 # s0 = B
    mv s1, a2                 # s1 = Pro
    li s2, 0                  # i = 0 (bit index of B)
    li t0, 0                  # j = 0
    mv t1, sp                 # t1 = &T[0]
    mv t2, a2                 # t2 = &Pro[0]

# for(int j=0; j<64; j++)
mul_init:
    sw zero, 0(t2)            # Pro[j] = 0
    li t3, 32
    bge t0, t3, mul_init_high # if(j >= 32) T[j] = 0
    lw t4, 0(a0)              # else T[j] = A[j]
    addi a0, a0, 4
    j mul_init_store
mul_init_high:
    li t4, 0
mul_init_store:
    sw t4, 0(t1)              # write T[j]
    addi t1, t1, 4
    addi t2, t2, 4
    addi t0, t0, 1            # j++
    li t3, 64
    blt t0, t3, mul_init      # while(j < 64)

# for(int i=0; i<1024; i++)
mul_bit:
    srli t0, s2, 5            # i / 32
    slli t0, t0, 2            # byte offset 4*(i/32)
    add t0, s0, t0            # &B[i/32]
    lw t1, 0(t0)              # B[i/32]
    andi t2, s2, 31           # i % 32
    srl t1, t1, t2            # B[i/32] >> (i%32)
    andi t1, t1, 1            # bit_i = ... & 1u
    beqz t1, mul_shift        # if(!bit_i) skip addition;

    mv t0, s1                 # t0 = &Pro[0]
    mv t1, sp                 # t1 = &T[0]
    li t2, 64                 # 64 words to add
    li t3, 0                  # carry = 0
# if(bit_i) Pro += T over 64 words; t3 = carry.
mul_add:
    lw t4, 0(t0)              # t4 = Pro[j]
    lw t5, 0(t1)              # t5 = T[j]
    add t6, t4, t5            # partial = Pro[j] + T[j]
    sltu a3, t6, t4           # c1 = (partial < Pro[j])
    add t4, t6, t3            # Pro[j] = partial + carry
    sltu a4, t4, t6           # c2 = (Pro[j] < partial)
    or t3, a3, a4             # carry = c1 | c2
    sw t4, 0(t0)              # write Pro[j]
    addi t0, t0, 4            # j++
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, mul_add          # while(j < 64)

# T <<= 1 over 64 words, high word first: for(int j=63; j>0; j--)
mul_shift:
    addi t0, sp, 252          # t0 = &T[63]
    li t1, 63                 # j = 63
mul_shift_loop:
    lw t2, 0(t0)              # T[j]
    lw t3, -4(t0)             # T[j-1]
    slli t2, t2, 1            # T[j] << 1
    srli t3, t3, 31           # T[j-1] >> 31: bit moving up
    or t2, t2, t3             # T[j] = (T[j]<<1) | (T[j-1]>>31)
    sw t2, 0(t0)
    addi t0, t0, -4           # j--
    addi t1, t1, -1
    bnez t1, mul_shift_loop   # while(j > 0)

    lw t2, 0(sp)              # T[0] <<= 1
    slli t2, t2, 1
    sw t2, 0(sp)

    addi s2, s2, 1            # i++
    li t0, 1024
    blt s2, t0, mul_bit       # while(i < 1024)

    # Restore s0-s2 and release the frame.
    lw s0, 256(sp)
    lw s1, 260(sp)
    lw s2, 264(sp)
    addi sp, sp, 272
    li a0, 0                  # return 0;
    ret

# div1024: a0=&A, a1=&B, a2=&Q, a3=&R; returns 0, or 1 if B==0 (Q=R=0).
# s0 = &A, s1 = &B, s2 = &Q, s3 = &R, s4 = i (bit index of A).
# Frame 160 bytes: D[32] at sp+0..127, s0-s4 at sp+128..144, ra at sp+148.
# Invariant: R < B and R <= processed prefix of A, so 2R+bit fits in 32 words.
div1024:
    addi sp, sp, -160
    sw s0, 128(sp)
    sw s1, 132(sp)
    sw s2, 136(sp)
    sw s3, 140(sp)
    sw s4, 144(sp)
    sw ra, 148(sp)

    mv s0, a0                 # s0 = A
    mv s1, a1                 # s1 = B
    mv s2, a2                 # s2 = Q
    mv s3, a3                 # s3 = R
    li t0, 0                  # j = 0 (as byte offset 4*j)
    li t1, 0                  # divisor_bits = 0
    li t2, 32

# for(int j=0; j<32; j++)
div_clear:
    add t3, s2, t0
    sw zero, 0(t3)            # Q[j] = 0
    add t3, s3, t0
    sw zero, 0(t3)            # R[j] = 0
    add t3, s1, t0
    lw t4, 0(t3)              # B[j]
    or t1, t1, t4             # divisor_bits |= B[j]
    addi t0, t0, 4            # j++
    addi t2, t2, -1
    bnez t2, div_clear        # while(j < 32)

    beqz t1, div_zero         # if(divisor_bits == 0) return 1;
    li s4, 1023               # i = 1023

# for(int i=1023; i>=0; i--): R = 2R + bit i of A
div_bit:
    addi t0, s3, 124          # t0 = &R[31]
    li t1, 31                 # j = 31
div_shift:
    lw t2, 0(t0)              # R[j]
    lw t3, -4(t0)             # R[j-1]
    slli t2, t2, 1            # R[j] << 1
    srli t3, t3, 31           # R[j-1] >> 31: bit moving up
    or t2, t2, t3             # R[j] = (R[j]<<1) | (R[j-1]>>31)
    sw t2, 0(t0)
    addi t0, t0, -4           # j--
    addi t1, t1, -1
    bnez t1, div_shift        # while(j > 0)

    srli t0, s4, 5            # i / 32
    slli t0, t0, 2            # byte offset 4*(i/32)
    add t0, s0, t0            # &A[i/32]
    lw t1, 0(t0)              # A[i/32]
    andi t2, s4, 31           # i % 32
    srl t1, t1, t2            # A[i/32] >> (i%32)
    andi t1, t1, 1            # bit = ... & 1u
    lw t3, 0(s3)              # R[0]
    slli t3, t3, 1            # R[0] << 1
    or t3, t3, t1             # R[0] = (R[0]<<1) | bit
    sw t3, 0(s3)

    li t0, 124                # j = 31 (byte offset 124)
# if(R >= B): compare from the highest word down; t0 = 4*j
div_compare:
    add t1, s3, t0
    add t2, s1, t0
    lw t3, 0(t1)              # R[j]
    lw t4, 0(t2)              # B[j]
    bltu t3, t4, div_next     # R[j] < B[j]: R < B, no subtraction
    bltu t4, t3, div_subtract # R[j] > B[j]: R > B, subtract
    addi t0, t0, -4           # R[j] == B[j]: j--, compare lower word
    bgez t0, div_compare      # while(j >= 0); falling out means R == B

# R -= B into temporary D (sub1024 buffers must not overlap)
div_subtract:
    mv a0, s3                 # a0 = R
    mv a1, s1                 # a1 = B
    mv a2, sp                 # a2 = D (on the stack)
    jal ra, sub1024           # sub1024(R, B, D);

    li t0, 0                  # j = 0 (as byte offset 4*j)
    li t1, 32
# for(int j=0; j<32; j++)
div_copy:
    add t2, sp, t0
    lw t3, 0(t2)              # D[j]
    add t2, s3, t0
    sw t3, 0(t2)              # R[j] = D[j]
    addi t0, t0, 4            # j++
    addi t1, t1, -1
    bnez t1, div_copy         # while(j < 32)

    srli t0, s4, 5            # i / 32
    slli t0, t0, 2            # byte offset 4*(i/32)
    add t0, s2, t0            # &Q[i/32]
    andi t1, s4, 31           # i % 32
    li t2, 1
    sll t2, t2, t1            # 1u << (i%32)
    lw t3, 0(t0)              # Q[i/32]
    or t3, t3, t2             # Q[i/32] |= 1u << (i%32)
    sw t3, 0(t0)

div_next:
    addi s4, s4, -1           # i--
    bgez s4, div_bit          # while(i >= 0)

    li a0, 0                  # return 0;
    j div_return

# B == 0: Q and R are already cleared.
div_zero:
    li a0, 1                  # return 1;

# Restore s0-s4, ra and release the frame.
div_return:
    lw s0, 128(sp)
    lw s1, 132(sp)
    lw s2, 136(sp)
    lw s3, 140(sp)
    lw s4, 144(sp)
    lw ra, 148(sp)
    addi sp, sp, 160
    ret

# print_words: a0=name, a1=&X, a2=word count; prints X high word first.
# Uses ecall, so it is kept out of the arithmetic routines.
print_words:
    li a7, 4                  # print string
    ecall

    slli t0, a2, 2
    add t0, a1, t0
    addi t0, t0, -4
    mv t1, a2
# for(int i=count-1; i>=0; i--); t0 = &X[i], t1 = words left
print_loop:
    lw a0, 0(t0)
    li a7, 34                 # print word in hex
    ecall
    la a0, space
    li a7, 4                  # print string
    ecall
    addi t0, t0, -4
    addi t1, t1, -1
    bnez t1, print_loop

    la a0, newline
    li a7, 4                  # print string
    ecall
    ret

# load_case(int test): a0=test (1..10); initialize global inputs and outputs.
load_case:
    la t0, A
    la t1, B
    li t2, 32
# for(int i=0; i<32; i++) A[i]=B[i]=0;
case_clear:
    sw zero, 0(t0)
    sw zero, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, case_clear

    la t0, Sum
    la t1, carry
    li t2, 0xa5a5a5a5
# Fill Sum..R with 0xa5a5a5a5 to expose unwritten words; R ends at carry.
case_fill_outputs:
    sw t2, 0(t0)
    addi t0, t0, 4
    bltu t0, t1, case_fill_outputs

    la t0, A
    la t1, B
    # switch(test): branch to cases 1..9; valid case 10 falls through.
    li t2, 1
    beq a0, t2, case_1
    li t2, 2
    beq a0, t2, case_2
    li t2, 3
    beq a0, t2, case_3
    li t2, 4
    beq a0, t2, case_4
    li t2, 5
    beq a0, t2, case_5
    li t2, 6
    beq a0, t2, case_6
    li t2, 7
    beq a0, t2, case_7
    li t2, 8
    beq a0, t2, case_8
    li t2, 9
    beq a0, t2, case_9
    # case 10: A[31]=1u<<31; B[0]=3; // A=2^1023.
    li t2, 0x80000000
    sw t2, 124(t0)
    li t2, 3
    sw t2, 0(t1)
    ret
# case 1: A=0, B=1.
case_1:
    li t2, 1
    sw t2, 0(t1)
    ret
# case 2: A=1, B=0.
case_2:
    li t2, 1
    sw t2, 0(t0)
    ret
# case 3: A=B=2^700+123456789. 700=21*32+28, so word 21 is at byte offset 84.
case_3:
    li t2, 123456789
    sw t2, 0(t0)
    sw t2, 0(t1)
    li t2, 0x10000000
    sw t2, 84(t0)
    sw t2, 84(t1)
    ret
# case 4: A=100, B=4.
case_4:
    li t2, 100
    sw t2, 0(t0)
    li t2, 4
    sw t2, 0(t1)
    ret
# case 5: A=100, B=7.
case_5:
    li t2, 100
    sw t2, 0(t0)
    li t2, 7
    sw t2, 0(t1)
    ret
# case 6: B[0]=1; for(int i=0; i<32; i++) A[i]=UINT32_MAX;
case_6:
    li t2, 1
    sw t2, 0(t1)
    li t2, -1
    li t3, 32
case_6_loop:
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t3, t3, -1
    bnez t3, case_6_loop
    ret
# case 7: A[31]=1; B[0]=1; // A=2^992.
case_7:
    li t2, 1
    sw t2, 124(t0)
    sw t2, 0(t1)
    ret
# case 8: for(int i=0; i<32; i++) A[i]=B[i]=UINT32_MAX;
case_8:
    li t2, -1
    li t3, 32
case_8_loop:
    sw t2, 0(t0)
    sw t2, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t3, t3, -1
    bnez t3, case_8_loop
    ret
# case 9: A=5, B=9.
case_9:
    li t2, 5
    sw t2, 0(t0)
    li t2, 9
    sw t2, 0(t1)
    ret
