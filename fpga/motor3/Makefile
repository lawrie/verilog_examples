chip.bin: move_test.v move.v move_test.pcf debouncer.v pwm.v quad.v 
	yosys -q -p "synth_ice40 -blif chip.blif" move_test.v move.v debouncer.v pwm.v quad.v
	arachne-pnr -d 8k -P tq144:4k -p move_test.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
