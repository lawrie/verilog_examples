module audio_stream(
   input CLK,
   input SCK,
   input MOSI,
   output MISO,
   input SSEL,
   output MCLK,
   output LRCK,
   output SCLK,
   output SDIN
   );	

localparam OFFSET = 32;

pll pll0 (.clock_in(CLK), .clock_out(MCLK));
	
reg [7:0] data;
reg [7:0] shift_reg;
reg [9:0] lr_scaler = 0;
wire valid;
reg [7:0] buffer [0:3];
reg [7:0] saved [0:3];
reg [1:0] byte_counter;

assign LRCK = lr_scaler[9]; // Divide MCLK by 1024
assign SDIN = shift_reg[7];
assign SCLK = lr_scaler[4];

always @(posedge MCLK) begin
  if (valid) begin
    if (byte_counter == 0 || byte_counter == 2) begin
      saved[byte_counter] <= data;
    end else begin
      buffer[byte_counter] <= data;
      buffer[byte_counter-1] <= saved[byte_counter-1];
    end
    byte_counter <= byte_counter + 1;
  end
end

always @(negedge MCLK) begin
  lr_scaler <= lr_scaler + 1;

  if (lr_scaler[7:0] == OFFSET) shift_reg <= buffer[lr_scaler[9:8]];
  else if (lr_scaler[4:0] == 0) shift_reg <= {shift_reg << 1};
end

SPI_slave ss (.clk(MCLK), .SCK(SCK), .MOSI(MOSI), .MISO(MISO), 
               .SSEL(SSEL), .DATA(data), .VALID(valid));

endmodule
