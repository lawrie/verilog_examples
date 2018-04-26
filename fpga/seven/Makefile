chip.bin: seg_test.v seg_test.pcf decoder_7_seg.v
	yosys -q -p "synth_ice40 -blif chip.blif" seg_test.v decoder_7_seg.v
	arachne-pnr -d 8k -P tq144:4k -p seg_test.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
