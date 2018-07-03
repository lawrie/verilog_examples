chip.bin: $(VERILOG_FILES) ${PCF_FILE} 
	yosys -q -p "synth_ice40 -blif chip.blif" $(VERILOG_FILES) 
	arachne-pnr -d 8k -P tq144:4k -p ${PCF_FILE} chip.blif -o chip.txt 
	icepack chip.txt chip.bin 

.PHONY: upload 
upload: chip.bin 
	stty -F /dev/ttyACM0 raw 
	cat chip.bin >/dev/ttyACM0 
 
.PHONY: clean 
clean: 
	$(RM) -f chip.blif chip.txt chip.bin 
