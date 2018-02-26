chip.bin: grove_test.v grove_test.pcf
	yosys -q -p "synth_ice40 -blif chip.blif" grove_test.v
	arachne-pnr -d 8k -P tq144:4k -p grove_test.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
