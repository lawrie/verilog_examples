module decoder_7_seg_hex(
  input clk,
  input [3:0] d,
  output reg [6:0] seg
); 

always @(posedge clk) 
begin
 case(d)
  4'd0: seg <= 7'b1111110; 
  4'd1: seg <= 7'b0110000;
  4'd2: seg <= 7'b1101101;
  4'd3: seg <= 7'b1111001;
  4'd4: seg <= 7'b0110011;
  4'd5: seg <= 7'b1011011;
  4'd6: seg <= 7'b1011111;
  4'd7: seg <= 7'b1110000;
  4'd8: seg <= 7'b1111111;
  4'd9: seg <= 7'b1111011;
  4'hA: seg <= 7'b1110111;
  4'hB: seg <= 7'b0011111;
  4'hC: seg <= 7'b1001110;
  4'hD: seg <= 7'b0111101;
  4'hE: seg <= 7'b1001111;
  4'hF: seg <= 7'b1000111;
 endcase
end 
endmodule
