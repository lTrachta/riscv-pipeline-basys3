.text
.globl _start

_start:
    addi x1, x0, 64
    addi x2, x0, -1

    sb   x2, 0(x1)

    lb   x3, 0(x1)
    lbu  x4, 0(x1)

    sh   x2, 2(x1)

    lh   x5, 2(x1)
    lhu  x6, 2(x1)

    lui  x7, 0x11223
    addi x7, x7, 0x344

    sw   x7, 4(x1)
    lw   x8, 4(x1)

    .word 0x0000000b      # HALT
    