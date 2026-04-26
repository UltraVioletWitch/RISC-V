all: compile assemble link extract convert

compile:
	@riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 \
    	-nostdlib -nostartfiles -ffreestanding -O2 \
    	-c main.c -o main.o

assemble:
	@riscv64-unknown-elf-as -march=rv32i_zicsr -mabi=ilp32 start.s -o start.o

link:
	@riscv64-unknown-elf-ld -m elf32lriscv -T link.ld start.o main.o -o program.elf

extract:
	@riscv64-unknown-elf-objcopy -O binary program.elf program.bin

convert:
	@python3 bin_to_hex.py program.bin > program.hex
