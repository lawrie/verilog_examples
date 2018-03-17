chip.bin: ping_test.v ping_test.pcf ping.v display_7_seg.v decoder_7_seg.v
	yosys -q -p "synth_ice40 -blif chip.blif" ping_test.v ping.v display_7_seg.v decoder_7_seg.v
	arachne-pnr -d 8k -P tq144:4k -p ping_test.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyACM0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
