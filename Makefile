all: build upload

build:
	@$(MAKE) -C ./verilog/ build

synth:
	@$(MAKE) -C ./verilog/ synth

upload:
	@openFPGALoader -b arty_s7_25 ./verilog/main.bit
