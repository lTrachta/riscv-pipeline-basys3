.text
.globl _start

_start:
    addi x1, x0, 0

loop:
    addi x1, x1, 1
    jal  x0, loop
