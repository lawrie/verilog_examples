module vga_text(
    input CLK,
    output HS,
    output VS,
    output [3:0] RED,
    output [3:0] GREEN,
    output [3:0] BLUE
    );

// Text to print, size and position

parameter x_offset = 35;
parameter y_offset = 38;

localparam font_height = 16;
localparam font_width = 8;

wire [7:0] text [0:11];

initial begin
  text[0] = "H";
  text[1] = "e";
  text[2] = "l";
  text[3] = "l";
  text[4] = "o";
  text[5] = " ";
  text[6] = "W";
  text[7] = "o";
  text[8] = "r";
  text[9] = "l";
  text[10] = "d";
  text[11] = "!";
end

// Generate VGA sync signals and get x, y position
wire [9:0] x, y;

vga v(.CLK (CLK), .HS (HS), .VS (VS), .x (x), .y (y));

// Print the text in white

wire pixel;
reg [7:0] ascii;

wire [9:0] xo, yo;

assign xo = x - x_offset;
assign yo = y - y_offset;

assign ascii = (yo >= 0 && yo < font_height && 
                xo >= 0 && xo < $size(text) * font_width ?
                 text[xo >> 3] : 0);

font8x16 U1 (CLK, ascii, yo[3:0], xo[2:0], pixel);

wire border = (x < 10 || x > 630 || y < 10 || y > 470);
wire show_text = (ascii > 0 && pixel);

assign RED = (show_text)?15:0;
assign GREEN = (show_text | border) ? 15 : 0;
assign BLUE = (show_text)?15:0;

endmodule
