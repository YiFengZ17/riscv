# enter: a0 = n, output: a0
# fib(0) == 0, fib(1) == 1
# t0 = 2
fib:
    li t0 2
    blt a0 t0 fib_exit

    addi sp sp -16
    sw ra 4(sp)
    sw s0 8(sp)
    sw a0 12(sp)

    addi a0 a0 -1
    jal ra fib
    mv s0 a0

    lw a0 12(sp)
    addi a0 a0 -2
    jal ra fib
    add a0 s0 a0

    lw ra 4(sp)
    lw s0 8(sp)
    addi sp sp 16

fib_exit:
    ret