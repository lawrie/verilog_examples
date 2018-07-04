module vgatest(
  input clk100, 
  output vga_h_sync, 
  output vga_v_sync, 
  output reg [3:0] vga_R, 
  output reg [3:0] vga_G, 
  output reg [3:0] vga_B, 
  output [7:0] led,
  input vsync,
  input href,
  input p_clock,
  output x_clock,
  input [7:0] p_data,
  output frame_done
);

wire inDisplayArea;
wire [9:0] CounterX;
wire [8:0] CounterY;
wire clk;

reg [4:0] fudge = 31;

SB_PLL40_CORE #(
  .FEEDBACK_PATH("SIMPLE"),
  .DIVR(4'b1001),         // DIVR =  9
  .DIVF(7'b1100100),      // DIVF = 100
  .DIVQ(3'b101),          // DIVQ =  5
  .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
) uut (
  .RESETB(1'b1),
  .BYPASS(1'b0),
  .REFERENCECLK(clk100),
  .PLLOUTCORE(clk)
);

hvsync_generator syncgen(.clk(clk), .vga_h_sync(vga_h_sync), 
                         .vga_v_sync(vga_v_sync), 
                         .inDisplayArea(inDisplayArea), 
                         .CounterX(CounterX), 
                         .CounterY(CounterY));

wire [5:0] pixin;
wire [3:0] R = {pixin[5:4], 2'b0};
wire [3:0] G = {pixin[3:2], 2'b0};
wire [3:0] B = {pixin[1:0], 2'b0};

reg [5:0] pixout;
reg [7:0] xout;
reg [6:0] yout;

reg we;

assign vga_R = inDisplayArea?R:0;
assign vga_G = inDisplayArea?G:0;
assign vga_B = inDisplayArea?B:0;

wire [7:0] xin = (inDisplayArea ? (CounterX[9:2]) : 0);
wire [6:0] yin = (inDisplayArea ? (CounterY[8:2]) : 0);

wire [14:0] raddr = (yin << 7) + (yin << 5) + xin;
wire [14:0] waddr = (yout << 7) + (yout << 5) + xout;

assign led = waddr[14:8];

vgabuff vgab (.clk(clk), .raddr(raddr), .pixin(pixin),
        .we(we), .waddr(waddr), .pixout(pixout));

wire [15:0] pixel_data;
wire [9:0] row, col;

assign yout = 119 - row[8:2] + fudge;
assign xout = 150 - col[9:2];
assign pixout = {pixel_data[13:12],pixel_data[9:8], pixel_data[3:2]};

camera_read cam (.clk(clk), .vsync(vsync), .href(href), .row(row), .col(col),
                 .p_clock(p_clock), .x_clock(x_clock),
                 .p_data(p_data), .frame_done(frame_done),
                 .pixel_valid(we), .pixel_data(pixel_data));

endmodule
