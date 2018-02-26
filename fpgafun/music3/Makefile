chip.bin: music.v music.pcf divide_by12.v
	yosys -q -p "synth_ice40 -blif chip.blif" music.v divide_by12.v
	arachne-pnr -d 8k -P tq144:4k -p music.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
