module spi_master(
  input clk, 
  input SCK, 
  input MOSI, 
  output MISO, 
  output SSEL, 
  output reg[15:0] DATA, 
  input REQ,
  output VALID);

reg [15:0] shift_reg;

reg [3:0] bit_counter;

always @(negedge SCK) if (REQ) begin
  VALID <= 0;
  if (bit_counter == 15) begin
    DATA <= {shift_reg[14:0], MISO};
    VALID <= 1;
  end
  else if (bit_counter == 0) shift_reg <= 16'h0000;
  else shift_reg <= {shift_reg[14:0], MISO};
  bit_counter <= bit_counter + 1;
end  
endmodule

