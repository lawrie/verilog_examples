module vga(
    input CLK, // 100Mz
    output HS, VS,
    output [9:0] x,
    output reg [9:0] y
    );

reg [9:0] xc;
reg [15:0] prescaler = 0;

localparam width = 640;
localparam height = 480;

localparam vfp = 9;
localparam vs = 3;
localparam vbp = 28;

localparam hfp = 24;
localparam hs = 40;
localparam hbp = 128;
 
// Horizontal 640 + fp 24 + HS 40 + bp 128 = 832 pixel clocks
// Vertical, 480 + fp 9 lines vs 3 lines bp 28 lines 
assign HS = ~ ((xc >= hfp) & (xc <= hfp + hs));
assign VS = ~ ((y > height + vfp) & (y <= height + vbp + vs));
assign x = ((xc < hfp + hs + hbp)?0:(xc - (hfp + hs + hbp)));

always @(posedge CLK)
begin
  prescaler <= prescaler + 1;
  if (prescaler == 3) // Divide clock by 4 to get 25Mhz
  begin
    prescaler <= 0;
    if (xc == width + hfp + hs + hbp)
    begin
      xc <= 0;
      y <= y + 1;
    end
    else xc <= xc + 1;

    if (y == height + vfp + vs + vbp) y <= 0; 
  end
end

endmodule
