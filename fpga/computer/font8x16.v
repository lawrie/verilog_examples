module font8x16 (
		 input  [7:0]	ascii_code,
		 input  [3:0]	row,
		 input  [2:0]   col,
		 output wire	pixel
		 );

reg [127:0] font [0:255];

initial $readmemh("font.hex", font);
wire [7:0] r = row;

assign pixel = font[ascii_code][(r << 3) + ~col];
	 
endmodule
