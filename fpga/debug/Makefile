chip.bin:debug_test.v  debug.v debug.pcf sync_reset.v uart_tx.v byte_to_hex.v
	yosys -q -p "synth_ice40 -blif chip.blif" debug_test.v debug.v sync_reset.v uart_tx.v byte_to_hex.v
	arachne-pnr -d 8k -P tq144:4k -p debug.pcf chip.blif -o chip.txt
	icepack chip.txt chip.bin

.PHONY: upload
upload:
	cat chip.bin >/dev/ttyUSB0

.PHONY: clean
clean:
	$(RM) -f chip.blif chip.txt chip.ex chip.bin
