module seg_test(
   input CLK,
   output [6:0] SEG,
   output DIGIT,
   input SCK,
   input MOSI,
   output MISO,
   input SSEL
   );	
	
reg [7:0] data;

display_7_seg display (.CLK(CLK), .SEG(SEG), .DIGIT(DIGIT), .n(data));

SPI_slave ss (.clk(CLK), .SCK(SCK), .MOSI(MOSI), .MISO(MISO), 
               .SSEL(SSEL), .DATA(data));

endmodule
