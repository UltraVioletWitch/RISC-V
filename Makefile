all: build upload

build:
	@$(MAKE) -C ./verilog/ build

upload:
	@openFPGALoader -b arty_s7_25 ./verilog/main.bit
