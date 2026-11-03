
#include<stdio.h>
#include<stdint.h>
#include<inttypes.h>

uint32_t add1024(const uint32_t* A,const uint32_t* B,uint32_t* Sum){
    uint32_t carry = 0;
    for(int i = 0;i<32;i++){
        Sum[i] = A[i] + B[i];
        if(Sum[i] < A[i]){ // wrap around
            Sum[i] = Sum[i] + carry;
            carry = 1;
        }else{
            Sum[i] = Sum[i] + carry;
            if(Sum[i] < carry){// wrap around
                carry = 1;
            }else{
                carry = 0;
            }
        }
    }
    return carry;
}

uint32_t sub1024(const uint32_t* A, const uint32_t*B, uint32_t* Sub){
    uint32_t borrow = 0;
    for(int i = 0;i<32;i++){
        Sub[i] = A[i] - B[i];
        if(A[i] < B[i]){ // wrap around automatically, need borrow
            Sub[i] = Sub[i] - borrow;
            borrow = 1;
        }else{
            if(Sub[i] < borrow){ // wrap around automatically,need borrow
                Sub[i] = Sub[i] - borrow;
                borrow = 1;
            }else{
                Sub[i] = Sub[i] - borrow;
                borrow = 0;
            }
        }
    }
    return borrow;
}
uint32_t mul1024(const uint32_t* A,const uint32_t* B, uint32_t* Pro){
    uint32_t T[64];
    // Initialize the temporary multiplicand.
    for(int i = 0;i<64;i++){
        Pro[i] = 0;
        if(i < 32)T[i] = A[i];
        else T[i] = 0;
    }
    for(int i = 0;i<1024;i++){
        // Extract the current bit.
        uint32_t bit_i = (B[i / 32] >> (i % 32)) & 1;
        if(bit_i){//Add if the bit is 1.
            uint32_t carry = 0;
            for(int j = 0;j<64;j++){
                Pro[j] += T[j];
                if(Pro[j] < T[j]){
                    Pro[j] = Pro[j] + carry;
                    carry = 1;
                }else{
                    Pro[j] += carry;
                    if(Pro[j] < carry){
                        carry = 1;
                    }else{
                        carry = 0;
                    }
                }
            }
        }
        //Shift the entire T left by 1 regardless of the bit, equivalent to multiplying by 2.
        for(int j = 63;j>0;j--){
            T[j] = (T[j] << 1) | (T[j-1] >> 31);
        }
        T[0] <<= 1;
    }
    return 0;
}

uint32_t div1024(const uint32_t* A,const uint32_t* B, uint32_t* Q, uint32_t* R){
    // Use a temporary array to store the subtraction result.
    uint32_t D[32];
    // Use zero to check whether the divisor is zero.
    int zero = 1;
    //Initialize the quotient and remainder.
    for(int i = 0;i<32;i++){
        Q[i] = 0;
        R[i] = 0;
        if(B[i] != 0){
            zero = 0;
        }
    }
    if(zero){
        return 1;
    }

    for(int i = 1023;i>=0;i--){
        //Shift R left by 1 and insert the current dividend bit at the low end.
        for(int j = 31;j>0;j--){
            R[j] = (R[j] << 1) | (R[j-1] >> 31);
        }
        R[0] = (R[0] << 1) | ((A[i/32] >> (i%32)) & 1);

        //Check whether R is large enough to subtract B.
        int greater_equal = 1;
        for(int j = 31;j>=0;j--){
            if(R[j] > B[j]){
                break;
            }else if(R[j] < B[j]){
                greater_equal = 0;
                break;
            }
        }
        //If subtraction is possible, update the quotient and remainder.
        if(greater_equal){
            
            sub1024(R,B,D);
            for(int j = 0;j<32;j++){
                R[j] = D[j];
            }
            Q[i/32] |= 1u << (i%32);
        }
    }
    return 0;
}


void print_words(const char* name,const uint32_t* X,int count){
    int i = count-1;
    while(i > 0 && X[i] == 0){
        i--;
    }
    printf("%s = 0x%" PRIx32,name,X[i]);
    for(i = i-1;i>=0;i--){
        printf("%08" PRIx32,X[i]);
    }
    printf("\n");
}

int main(void){
    const char* cases[10] = {
        "A=0, B=1", "A=1, B=0", "A=C, B=C",
        "A=100, B=4", "A=100, B=7", "A=M, B=1",
        "A=2^992, B=1", "A=M, B=M", "A=5, B=9",
        "A=2^1023, B=3"
    };
    printf("M=2^1024-1, C=2^700+123456789\n");
    printf("All values below are hexadecimal (0x).\n");
    for(int test = 1;test<=10;test++){
        uint32_t A[32] = {0};
        uint32_t B[32] = {0};
        uint32_t Sum[32];
        uint32_t Sub[32];
        uint32_t Pro[64];
        uint32_t Q[32];
        uint32_t R[32];

        switch(test){
            case 1:
                B[0] = 1;
                break;
            case 2:
                A[0] = 1;
                break;
            case 3:
                // 700 = 21*32 + 28.
                A[21] = B[21] = 1u << 28;
                A[0] = B[0] = 123456789;
                break;
            case 4:
                A[0] = 100;
                B[0] = 4;
                break;
            case 5:
                A[0] = 100;
                B[0] = 7;
                break;
            case 6:
                for(int i = 0;i<32;i++){
                    A[i] = UINT32_MAX;
                }
                B[0] = 1;
                break;
            case 7:
                A[31] = 1; 
                B[0] = 1;
                break;
            case 8:
                for(int i = 0;i<32;i++){
                    A[i] = B[i] = UINT32_MAX;
                }
                break;
            case 9:
                A[0] = 5;
                B[0] = 9;
                break;
            case 10:
                A[31] = 1u << 31;
                B[0] = 3;
                break;
        }
        
        for(int i = 0;i<32;i++){
            Sum[i] = Sub[i] = Q[i] = R[i] = 0xa5a5a5a5u;
        }
        for(int i = 0;i<64;i++){
            Pro[i] = 0xa5a5a5a5u;
        }

        uint32_t carry = add1024(A,B,Sum);
        uint32_t borrow = sub1024(A,B,Sub);
        uint32_t mul_status = mul1024(A,B,Pro);
        uint32_t div_status = div1024(A,B,Q,R);

        printf("\nCase %d: %s\n",test,cases[test-1]);
        print_words("A",A,32);
        print_words("B",B,32);
        print_words("Sum",Sum,32);
        print_words("Sub",Sub,32);
        print_words("Pro",Pro,64);
        print_words("Q",Q,32);
        print_words("R",R,32);
        printf("carry=%" PRIu32 ", borrow=%" PRIu32
               ", mul_status=%" PRIu32 ", status=%" PRIu32 "\n",
               carry,borrow,mul_status,div_status);
    }
    return 0;
}
