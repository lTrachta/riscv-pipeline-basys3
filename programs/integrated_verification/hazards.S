.text
.globl _start

_start:
    addi x1, x0, 128
    addi x2, x0, 10

    sw   x2, 0(x1)

    # Forwarding ALU
    addi x3, x2, 5
    add  x4, x3, x2

    # load -> ALU
    # Debe generar un stall.
    lw   x5, 0(x1)
    add  x6, x5, x4

    # load -> store data
    # NO debe generar stall.
    lw   x7, 0(x1)
    sw   x7, 4(x1)

    # Guardamos 132 en memoria.
    addi x11, x0, 132
    sw   x11, 8(x1)

    # load -> store base
    # Sí debe generar stall.
    lw   x12, 8(x1)
    sw   x2, 0(x12)

    # ALU -> branch
    addi x13, x0, 1
    beq  x13, x13, alu_branch_target

    addi x14, x0, 99
    addi x14, x0, 98

alu_branch_target:

    # load -> branch
    # Debe generar stall.
    lw   x15, 0(x1)
    beq  x15, x2, load_branch_target

    addi x16, x0, 99
    addi x16, x0, 98

load_branch_target:
    addi x17, x6, 1

    .word 0x0000000b
    