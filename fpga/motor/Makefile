chip.bin: motor.v motor.pcf debouncer.v pwm.v quad.v
	yosys -q -p "synth_ice40 -blif chip.blif" motor.v debouncer.v pwm.v quad.v
	arachne-pnr -d 8k -P tq144:4k -p motor.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
