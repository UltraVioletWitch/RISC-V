.section .text
.global _start

_start:
    li sp, 0x4000
    call main
hang:
    j hang
