.text
.global _start
_start:
	call main
	li a7, 94  # __NR_exit_group
	ecall
