all: assemble link extract convert

assemble:
	@riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 program.s -o program.o

link:
	@riscv64-unknown-elf-ld -m elf32lriscv -Ttext=0x0 program.o -o program.elf

extract:
	@riscv64-unknown-elf-objcopy -O binary program.elf program.bin

convert:
	@python3 bin_to_hex.py program.bin > program.hex
