module microphone(
   input CLK,
   input SCK,
   output MISO,
   input SS,
   output MCLK,
   output LRCK,
   output SCLK,
   output SDIN,
   output [3:0] LED
   );	

localparam OFFSET = 32;

pll pll0 (.clock_in(CLK), .clock_out(MCLK));
	
reg [15:0] data;
reg [15:0] shift_reg;
reg [9:0] lr_scaler = 0;
wire valid;
reg [7:0] buffer [0:3];
reg [7:0] saved [0:3];
reg [1:0] byte_counter;
wire MOSI = 0;

assign LED = data[3:0];

assign LRCK = lr_scaler[9]; // Divide MCLK by 1024
assign SDIN = shift_reg[7];
assign SCLK = lr_scaler[4];

always @(negedge MCLK) begin
  lr_scaler <= lr_scaler + 1;

  if (lr_scaler[6:0] == OFFSET) shift_reg <= data;
  else if (lr_scaler[4:0] == 0) shift_reg <= {shift_reg << 1};
end

SPI_slave ss (.clk(MCLK), .SCK(SCK), .MISO(MISO), .MOSI(MOSI),
               .SSEL(SS), .DATA(data), .VALID(valid));

endmodule
