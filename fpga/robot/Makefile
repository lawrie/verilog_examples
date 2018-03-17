chip.bin: robot.v move.v robot.pcf debouncer.v pwm.v quad.v ping.v decoder_7_seg.v display_7_seg.v bcd.v
	yosys -q -p "synth_ice40 -blif chip.blif" robot.v move.v debouncer.v pwm.v quad.v ping.v decoder_7_seg.v display_7_seg.v bcd.v
	arachne-pnr -d 8k -P tq144:4k -p robot.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
