module seg_test(
   input CLK,
   output [6:0] SEG,
   output DIGIT,
   input SCK,
   input MOSI,
   output MISO,
   input SSEL,
   output PWM_out
   );	
	
reg [15:0] data;

reg [16:0] PWM_accumulator;

always @(posedge CLK) PWM_accumulator <= PWM_accumulator[15:0] + data;

assign PWM_out = PWM_accumulator[16];

display_7_seg display (.CLK(CLK), .SEG(SEG), .DIGIT(DIGIT), .n(data[7:0]));

SPI_slave ss (.clk(CLK), .SCK(SCK), .MOSI(MOSI), .MISO(MISO), 
               .SSEL(SSEL), .DATA(data));

endmodule
