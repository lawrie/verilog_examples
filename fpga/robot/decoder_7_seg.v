module decoder_7_seg(
	input CLK,
   input [3:0] D,
   output reg [6:0] SEG
   );

always @(posedge CLK) 
begin
	case(D)
    4'd0: SEG <= 7'b1111110;
    4'd1: SEG <= 7'b0110000; 
    4'd2: SEG <= 7'b1101101;
    4'd3: SEG <= 7'b1111001;
    4'd4: SEG <= 7'b0110011;
    4'd5: SEG <= 7'b1011011;
    4'd6: SEG <= 7'b1011111;
    4'd7: SEG <= 7'b1110000;
    4'd8: SEG <= 7'b1111111;
    4'd9: SEG <= 7'b1111011;
    default: SEG <= 7'b0000000;
	endcase
end

endmodule
