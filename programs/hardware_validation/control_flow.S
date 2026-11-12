.text
.globl _start

_start:
    addi x1, x0, 3
    addi x2, x0, 0

loop:
    addi x2, x2, 2
    addi x1, x1, -1

    bne  x1, x0, loop

    jal  x3, after_jal

    addi x4, x0, 99

after_jal:
    addi x6, x0, 41

    jalr x7, 0(x6)

    addi x8, x0, 99

jalr_target:
    addi x5, x2, 1

    HALT

