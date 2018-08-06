module spi16in(
  input clk, 
  input sck, 
  output miso, 
  output reg[15:0] data, 
  input req,
  input [15:0] speed,
  output done
);

reg [15:0] shift_reg;
reg [6:0] sck_counter;
reg [15:0] pre_scaler;

always @(posedge clk) if (req) begin
  done <= 0;
  sck <= sck_counter[0];
  if (pre_scaler == speed) begin
    pre_scaler <= 0;
    if (sck_counter == 32) begin
      data <= shift_reg;
      done <= 1;
      sck_counter <= 0;
      pre_scaler <= 0;
    end else begin
     if (sck_counter == 0) shift_reg <= 0; 
     if (sck_counter[0]) shift_reg <= {shift_reg[14:0], miso};
     sck_counter <= sck_counter + 1;
    end
  end else pre_scaler <= pre_scaler + 1;
end else sck_counter <= 0;
endmodule
