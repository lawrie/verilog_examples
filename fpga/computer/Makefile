chip.bin: vga_test.v vga.v text_field.v vga_test.pcf font8x16.v ps2.v PS2ScanToAscii.v byte_to_hex.v tone.v
	yosys -q -p "synth_ice40 -blif chip.blif" text_field.v vga.v font8x16.v vga_test.v ps2.v PS2ScanToAscii.v byte_to_hex.v tone.v
	arachne-pnr -d 8k -P tq144:4k -p vga_test.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
