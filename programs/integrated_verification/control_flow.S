.text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 5

    beq  x1, x2, beq_taken

    addi x10, x0, 99
    addi x11, x0, 99

beq_taken:
    addi x3, x0, 1

    bne  x1, x2, bne_not_taken_target
    addi x4, x0, 2

    addi x2, x0, 6

    bne  x1, x2, bne_taken

    addi x12, x0, 99
    addi x13, x0, 99

bne_taken:
    beq  x1, x2, beq_not_taken_target
    addi x5, x0, 3

    jal  x6, jal_target

    addi x14, x0, 99
    addi x15, x0, 99

jal_target:
    addi x7, x0, 83

    # (83 + 2) = 85
    # JALR debe limpiar bit 0:
    # target = 84
    jalr x8, 2(x7)

    addi x16, x0, 99
    addi x17, x0, 99

jalr_target:
    addi x9, x0, 4

    .word 0x0000000b

bne_not_taken_target:
beq_not_taken_target:
