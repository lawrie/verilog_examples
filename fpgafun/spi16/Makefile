chip.bin: microphone.v microphone.pcf spi_slave.v pll.v
	yosys -q -p "synth_ice40 -blif chip.blif" microphone.v spi_slave.v pll.v
	arachne-pnr -d 8k -P tq144:4k -p microphone.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
