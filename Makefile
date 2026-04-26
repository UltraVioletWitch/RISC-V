all: flash

build:
	@$(MAKE) -C ./verilog/ build

synth:
	@$(MAKE) -C ./verilog/ synth

flash:
	@$(MAKE) -C ./verilog/ flash

upload:
	@openFPGALoader -b arty_s7_25 ./verilog/main.bit
