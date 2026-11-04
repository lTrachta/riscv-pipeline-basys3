.text
.globl _start

_start:
    addi x1, x0, 200

    addi x2, x0, 1
    sw   x2, 0(x1)

    addi x2, x0, 2
    sw   x2, 4(x1)

    addi x2, x0, 3
    sw   x2, 8(x1)

    addi x2, x0, 4
    sw   x2, 12(x1)

    # sum = 0
    addi x3, x0, 0

    # count = 4
    addi x4, x0, 4

    # ptr = base
    addi x5, x1, 0

loop:
    lw   x6, 0(x5)
    add  x3, x3, x6

    addi x5, x5, 4
    addi x4, x4, -1

    bne  x4, x0, loop

    # Guardar suma final.
    sw   x3, 16(x1)

    # Leerla nuevamente.
    lw   x7, 16(x1)

    .word 0x0000000b
    