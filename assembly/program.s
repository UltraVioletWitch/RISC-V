.section .text
.globl main

main:
    li x1, 0
    li x2, 1

loop:
    add x1, x1, x2
    j loop
