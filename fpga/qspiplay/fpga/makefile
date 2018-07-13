all: ../ice40bitstream.h

chip.blif: qspiplay.v PWM.v
	yosys -q -p "synth_ice40 -blif chip.blif" $^

chip.bin: chip.blif blackice.pcf
	arachne-pnr -d 8k -P tq144:4k -p blackice.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

../ice40bitstream.h: chip.bin
	od -An -t x1 -v $^ | sed 's/[^ ][^ ]/0x&,/g;s/0x00,/0,/g;s/ //g' >$@

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.bin
