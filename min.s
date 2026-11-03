# a0 = n, a1 = p, return a0.
# int min(int n, int *p){
#    int i, m = p[0];
#    for(int i = 1;i<n;i++){
#        if(p[i] < m)m = p[i];
#    }
#    return m;
#}

min:
    mv t0 ,a0           # t0 = m 
    lw a0 ,0(a1)        # a0 = p[0], a0 as answer
    addi t1, a1, 4      # t1 as the *p pointer
    li t2 ,1            # t2 as 1
loop:
    bge t2 ,t0, done    # end loop
    lw t3 ,0(t1)        # t3 as the value of p[i]
    bge t3 ,a0, else
    mv a0 ,t3
    addi t2 ,t2, 1
    addi t1 ,t1, 4
    j loop
else:
    addi t2 ,t2, 1
    addi t1 ,t1, 4
    j loop
done:
    ret


