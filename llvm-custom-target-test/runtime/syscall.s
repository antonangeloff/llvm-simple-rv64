.text
.global sys_write
sys_write:
	# a0 = fd, a1 = buf, a2 = len -- already matches the write(2) syscall ABI
	li a7, 64  # __NR_write
	ecall
	ret
