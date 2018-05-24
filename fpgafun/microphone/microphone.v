module microphone(
   input CLK,
   output SCK,
   input MISO,
   output SS,
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
wire req;
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

reg [4:0] sck_scaler = 0;
wire valid;
reg ss;

assign SS = ss;

always @(posedge MCLK) begin
  sck_scaler <= sck_scaler + 1;
end

assign SCK = sck_scaler[4];

reg [4:0] bit_counter;

always @(negedge SCK) begin
  if (bit_counter == 0) begin
    req <= 1;
    ss <= 0;
  end 
  else if (bit_counter == 20) bit_counter <= 0;
  if (valid) begin
    req <= 0;
    ss <= 1;
  end
  bit_counter <= bit_counter + 1;
end

spi_master spim (.clk(MCLK), .SCK(SCK), .MISO(MISO), .MOSI(MOSI),
               .SSEL(SS), .DATA(data), .REQ(req), .VALID(valid));

endmodule
