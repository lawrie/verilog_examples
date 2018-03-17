module text_field #(parameter max_len = 16) (
    input [9:0] x,
    input [9:0] y,
    input [9:0] x_offset,
    input [9:0] y_offset,
    input [0:8*max_len-1] text,
    input [9:0] text_len,
    output show_text
    );

localparam font_height = 16;
localparam font_width = 8;

wire pixel;
reg [7:0] ascii;

wire [9:0] xo, yo, to;

assign xo = x - x_offset;
assign yo = y - y_offset;

assign to = max_len - text_len;

assign ascii = (yo >= 0 && yo < font_height && 
                xo >= 0 && xo < text_len * font_width ?
                text[(to + (xo  >> 3)) << 3 +:8] : 0);

font8x16 U1 (ascii, yo[3:0], xo[2:0], pixel);

assign show_text = (ascii > 0 && pixel);

endmodule
