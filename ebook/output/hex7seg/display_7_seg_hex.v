module display_7_seg_hex(
  input clk,
  input [7:0] n,
  output [6:0] seg,
  output reg digit 
); 

reg [3:0] digit_data; 
reg digit_posn; 
reg [23:0] prescaler; 

decoder_7_seg_hex decoder(.clk (clk), .seg(seg), .d (digit_data)); 

always @(posedge clk) 
begin
  prescaler <= prescaler + 24'd1;
  if (prescaler == 24'd50000) // 1 kHz 
  begin 
    prescaler <= 0; 
    digit_posn <= digit_posn + 2'd1; 
    if (digit_posn == 0) 
    begin 
      digit_data <= n[3:0]; 
      digit <= 4'b0; 
    end 
    if (digit_posn == 2'd1) 
    begin
      digit_data <= n[7:4]; 
      digit <= 4'b1; 
    end 
  end 
end 
endmodule
