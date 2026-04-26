.section .text
.global _start

_start:
    li sp, 0x4000
    la t0, trap_handler
    csrw mtvec, t0
    call main
hang:
    j hang
