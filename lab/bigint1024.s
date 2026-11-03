# RARS 1.6 / RV32I. Low words first, 32 bits per word.
# Run cases first_case..last_case; set both to the same number for a single case.
.data
.align 2 # 4-byte alignment.
first_case: .word 1
last_case:  .word 10
# uint32_t A[32], B[32], Sum[32], Sub[32], Pro[64], Q[32], R[32];
# Each normal buffer occupies 128 bytes; the full product occupies 256 bytes.
A:          .space 128
B:          .space 128
Sum:        .space 128
Sub:        .space 128
Pro:        .space 256
Q:          .space 128
R:          .space 128
# Return values saved by main: carry, borrow, multiplication status, division status.
carry:      .word 0
borrow:     .word 0
mul_status: .word 0
status:     .word 0
# Output strings: .asciz is equivalent to a zero-terminated C char array.
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
mul_text:   .asciz "mul_status: "
status_text: .asciz "status: "

.text
.globl main
.globl add1024
.globl sub1024
.globl mul1024
.globl div1024
# for(int test=first_case; test<=last_case; test++){ load_case(test); compute; print; }
# s0=test across calls. a0..a3 pass arguments; save each return value in a0 before reusing it.
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
    # mul_status = mul1024(A, B, Pro);
    jal ra, mul1024
    la t0, mul_status
    sw a0, 0(t0)

    la a0, A
    la a1, B
    la a2, Q
    la a3, R
    # status = div1024(A, B, Q, R);
    jal ra, div1024
    la t0, status
    sw a0, 0(t0)

    # printf("\nCase %d\n", test);
    la a0, case_text
    li a7, 4
    ecall
    mv a0, s0
    li a7, 1
    ecall
    la a0, newline
    li a7, 4
    ecall
    # Print all inputs/results with print_words(label, array, count).
    # Use 64 words for Pro, 32 for other arrays, and 1 for each status.
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
    la a0, mul_text
    la a1, mul_status
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
    li a7, 10
    ecall

# a0=A, a1=B, a2=Sum; return carry in a0. No stack frame.
# t0=words remaining, t1=carry, t4/t5=two carry flags.
add1024:
    li t0, 32
    li t1, 0
# for(int i=0; i<32; i++):
# partial = A[i] + B[i]; c1 = (partial < A[i]);
# Sum[i] = partial + carry; c2 = (Sum[i] < partial); carry = c1 | c2;
# sltu computes an unsigned comparison as 0/1, replacing the C if/else.
add_loop:
    lw t2, 0(a0)
    lw t3, 0(a1)
    add t3, t2, t3
    sltu t4, t3, t2
    add t2, t3, t1
    sltu t5, t2, t3
    or t1, t4, t5
    sw t2, 0(a2)
    addi a0, a0, 4
    addi a1, a1, 4
    addi a2, a2, 4
    addi t0, t0, -1
    bnez t0, add_loop
    mv a0, t1
    ret

# a0=A, a1=B, a2=Sub; return borrow in a0. No stack frame.
# t0=words remaining, t1=borrow, t4/t5=two borrow flags.
sub1024:
    li t0, 32
    li t1, 0
# for(int i=0; i<32; i++):
# b1 = (A[i] < B[i]); partial = A[i] - B[i];
# b2 = (partial < borrow); Sub[i] = partial - borrow; borrow = b1 | b2;
sub_loop:
    lw t2, 0(a0)
    lw t3, 0(a1)
    sltu t4, t2, t3
    sub t2, t2, t3
    sltu t5, t2, t1
    sub t2, t2, t1
    or t1, t4, t5
    sw t2, 0(a2)
    addi a0, a0, 4
    addi a1, a1, 4
    addi a2, a2, 4
    addi t0, t0, -1
    bnez t0, sub_loop
    mv a0, t1
    ret

# a0=A, a1=B, a2=Pro; return 0. s0=B, s1=Pro, s2=bit index i.
# 272-byte frame: uint32_t T[64] at sp+0..255;
# saved s0/s1/s2 at +256/+260/+264, then 4 bytes of padding. No nested calls.
mul1024:
    addi sp, sp, -272
    sw s0, 256(sp)
    sw s1, 260(sp)
    sw s2, 264(sp)
    mv s0, a1
    mv s1, a2
    li s2, 0
    li t0, 0
    mv t1, sp
    mv t2, a2
# for(int j=0; j<64; j++){ Pro[j]=0; T[j]=(j<32 ? A[j] : 0); }
# t0=j, t1=&T[j], t2=&Pro[j].
mul_init:
    sw zero, 0(t2)
    li t3, 32
    bge t0, t3, mul_init_high
    lw t4, 0(a0)
    addi a0, a0, 4
    j mul_init_store
mul_init_high:
    li t4, 0
mul_init_store:
    sw t4, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 4
    addi t0, t0, 1
    li t3, 64
    blt t0, t3, mul_init
# for(int i=0; i<1024; i++): bit_i = (B[i/32] >> (i%32)) & 1u;
# i>>5 gives i/32; i&31 gives i%32; multiply the word index by 4 for its byte offset.
mul_bit:
    srli t0, s2, 5
    slli t0, t0, 2
    add t0, s0, t0
    lw t1, 0(t0)
    andi t2, s2, 31
    srl t1, t1, t2
    andi t1, t1, 1
    beqz t1, mul_shift # if(!bit_i) skip addition;

    mv t0, s1
    mv t1, sp
    li t2, 64
    li t3, 0
# if(bit_i): add T to all 64 words of Pro, using the same two-carry logic as add1024.
# t0=&Pro[j], t1=&T[j], t2=words remaining, t3=carry.
mul_add:
    lw t4, 0(t0)
    lw t5, 0(t1)
    add t6, t4, t5
    sltu a3, t6, t4
    add t4, t6, t3
    sltu a4, t4, t6
    or t3, a3, a4
    sw t4, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, mul_add
# Regardless of bit_i: for(int j=63; j>0; j--)
#     T[j] = (T[j]<<1) | (T[j-1]>>31);
# Then T[0] <<= 1. Process high words first to preserve the lower source word.
mul_shift:
    addi t0, sp, 252
    li t1, 63
mul_shift_loop:
    lw t2, 0(t0)
    lw t3, -4(t0)
    slli t2, t2, 1
    srli t3, t3, 31
    or t2, t2, t3
    sw t2, 0(t0)
    addi t0, t0, -4
    addi t1, t1, -1
    bnez t1, mul_shift_loop
    lw t2, 0(sp)
    slli t2, t2, 1
    sw t2, 0(sp)
    addi s2, s2, 1
    li t0, 1024
    blt s2, t0, mul_bit
    # Restore saved registers and release the entire frame.
    lw s0, 256(sp)
    lw s1, 260(sp)
    lw s2, 264(sp)
    addi sp, sp, 272
    li a0, 0
    ret

# a0=A, a1=B, a2=Q, a3=R; return 0, or 1 for division by zero.
# s0=A, s1=B, s2=Q, s3=R, s4=bit index i.
# 160-byte frame: uint32_t D[32] at sp+0..127; saved s0..s4 at +128..144;
# saved ra at +148, then 8 bytes of padding. Save ra for the call to sub1024.
# Invariant: R is the processed prefix modulo B, so R<B after each iteration.
# With a zero initial remainder and 1024 input bits, the shifted R is bounded by
# the current input prefix and fits in 32 words.
div1024:
    addi sp, sp, -160
    sw s0, 128(sp)
    sw s1, 132(sp)
    sw s2, 136(sp)
    sw s3, 140(sp)
    sw s4, 144(sp)
    sw ra, 148(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    li t0, 0
    li t1, 0
    li t2, 32
# for(int j=0; j<32; j++){ Q[j]=R[j]=0; divisor_bits |= B[j]; }
# t0=byte offset, t1=divisor_bits, t2=words remaining.
# divisor_bits==0 is equivalent to the C zero flag being true.
 div_clear:
    add t3, s2, t0
    sw zero, 0(t3)
    add t3, s3, t0
    sw zero, 0(t3)
    add t3, s1, t0
    lw t4, 0(t3)
    or t1, t1, t4
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, div_clear
    beqz t1, div_zero # if(divisor_bits == 0) return 1;
    li s4, 1023
# for(int i=1023; i>=0; i--):
# for(int j=31; j>0; j--) R[j] = (R[j]<<1) | (R[j-1]>>31);
 div_bit:
    addi t0, s3, 124
    li t1, 31
 div_shift:
    lw t2, 0(t0)
    lw t3, -4(t0)
    slli t2, t2, 1
    srli t3, t3, 31
    or t2, t2, t3
    sw t2, 0(t0)
    addi t0, t0, -4
    addi t1, t1, -1
    bnez t1, div_shift
    # R[0] = (R[0]<<1) | ((A[i/32] >> (i%32)) & 1u);
    srli t0, s4, 5
    slli t0, t0, 2
    add t0, s0, t0
    lw t1, 0(t0)
    andi t2, s4, 31
    srl t1, t1, t2
    andi t1, t1, 1
    lw t3, 0(s3)
    slli t3, t3, 1
    or t3, t3, t1
    sw t3, 0(s3)

    li t0, 124
# Compare R and B from word 31 downward. Skip subtraction if R[j]<B[j];
# subtract if R[j]>B[j]; continue on equality. All equal also means R>=B.
# Branches encode the C greater_equal flag; t0=4*j.
 div_compare:
    add t1, s3, t0
    add t2, s1, t0
    lw t3, 0(t1)
    lw t4, 0(t2)
    bltu t3, t4, div_next
    bltu t4, t3, div_subtract
    addi t0, t0, -4
    bgez t0, div_compare
# if(greater_equal) sub1024(R, B, D); use separate D to avoid overlapping buffers.
 div_subtract:
    mv a0, s3
    mv a1, s1
    mv a2, sp
    jal ra, sub1024
    li t0, 0
    li t1, 32
# for(int j=0; j<32; j++) R[j] = D[j];
 div_copy:
    add t2, sp, t0
    lw t3, 0(t2)
    add t2, s3, t0
    sw t3, 0(t2)
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, div_copy
    # Q[i/32] |= 1u << (i%32);
    srli t0, s4, 5
    slli t0, t0, 2
    add t0, s2, t0
    andi t1, s4, 31
    li t2, 1
    sll t2, t2, t1
    lw t3, 0(t0)
    or t3, t3, t2
    sw t3, 0(t0)
 div_next:
    addi s4, s4, -1
    bgez s4, div_bit
    li a0, 0
    j div_return
# Division by zero: Q and R are already cleared; return 1.
 div_zero:
    li a0, 1
# Both return paths restore saved registers/ra and release the 160-byte frame.
 div_return:
    lw s0, 128(sp)
    lw s1, 132(sp)
    lw s2, 136(sp)
    lw s3, 140(sp)
    lw s4, 144(sp)
    lw ra, 148(sp)
    addi sp, sp, 160
    ret

# print_words(const char* name, const uint32_t* X, int count);
# a0=name, a1=X, a2=count. Print all words, including leading zeros.
# RARS services: 4=string, 1=decimal integer, 34=hex word, 10=exit;
# a7 selects the service and a0 holds its argument. These print services preserve t-registers.
print_words:
    li a7, 4
    ecall
    slli t0, a2, 2
    add t0, a1, t0
    addi t0, t0, -4
    mv t1, a2
# for(int i=count-1; i>=0; i--) printf("0x%08x ", X[i]); then print a newline.
# t0=&X[i], t1=words remaining.
print_loop:
    lw a0, 0(t0)
    li a7, 34
    ecall
    la a0, space
    li a7, 4
    ecall
    addi t0, t0, -4
    addi t1, t1, -1
    bnez t1, print_loop
    la a0, newline
    li a7, 4
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
# Prefill all output words with 0xa5a5a5a5u to detect missing writes.
# Sum/Sub/Pro/Q/R are contiguous; stop at carry, which follows the last buffer.
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
