.text
.globl _start

_start:
    addi x1, x0, 64
    addi x2, x0, 85

    sw   x2, 0(x1)
    lw   x3, 0(x1)

    HALT
