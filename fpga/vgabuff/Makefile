chip.bin: vgatest.v vgabuff.v hvsync_generator.v camera_read.v vgabuff.pcf 
	yosys -q -p "synth_ice40 -blif chip.blif" vgatest.v vgabuff.v hvsync_generator.v camera_read.v
	arachne-pnr -d 8k -P tq144:4k -p vgabuff.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
