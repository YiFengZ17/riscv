# RV64 Linux assembly: print a message and exit successfully.
# Arguments: a0-a5; syscall number: a7; instruction: ecall.
.section .rodata
message:
    .ascii "Hello, RISC-V!\n"
.equ message_len, . - message

.section .text
.globl _start
_start:
    # write(fd=1, buffer=message, count=message_len)
    li a0, 1
    la a1, message
    li a2, message_len
    li a7, 64
    ecall

    # exit(status=0)
    li a0, 0
    li a7, 93
    ecall
