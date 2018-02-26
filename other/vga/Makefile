chip.bin: vga.v vga_text.v vga_text.pcf font8x16.v
	yosys -q -p "synth_ice40 -blif chip.blif" vga_text.v vga.v font8x16.v
	arachne-pnr -d 8k -P tq144:4k -p vga_text.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
