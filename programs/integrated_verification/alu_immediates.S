.text
.globl _start

_start:
    addi  x1,  x0, 10
    addi  x2,  x0, 3

    add   x3,  x1, x2
    sub   x4,  x1, x2
    sll   x5,  x2, x2
    srl   x6,  x5, x2

    addi  x7,  x0, -16
    sra   x8,  x7, x2

    and   x9,  x1, x2
    or    x10, x1, x2
    xor   x11, x1, x2

    slt   x12, x7, x1
    sltu  x13, x7, x1

    andi  x14, x1, 6
    ori   x15, x2, 8
    xori  x16, x1, 15

    slti  x17, x7, -1
    sltiu x18, x1, 20

    slli  x19, x2, 4
    srli  x20, x19, 2
    srai  x21, x7, 2

    lui   x22, 0x12345

    .word 0x0000000b      # HALT
    