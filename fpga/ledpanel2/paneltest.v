module paneltest(
  input clk100,
  input resetn,
  output [3:0] led,
  output reg panel_r0, panel_g0, panel_b0, panel_r1, panel_g1, panel_b1,
  output reg panel_a, panel_b, panel_c, panel_d, panel_clk, panel_stb, panel_oe);

localparam SPEED = 18, COLOR = 'h0000ff, CI_COLOR = 'hff0000,
           R_COLOR = 'h00ff00, W_COLOR = 'hffff00;

wire [3:0] ctrl_wr;
wire ctrl_rd;
wire [15:0] ctrl_addr;
wire [31:0] ctrl_wdat;
reg [31:0] ctrl_rdat;
reg ctrl_done;
wire clk = clk100;
reg [4:0] ci_line, r_line, w_line;

assign ctrl_rd = 0;
assign ctrl_wr[3] = 0;
assign led[0] = ctrl_done;

ledpanel #(.CLOCK_FREQ_HZ(100000000)) panel (.clk(clk100), .resetn(resetn),
           .ctrl_wr(ctrl_wr), .ctrl_rd(ctrl_rd), .ctrl_addr(ctrl_addr),
           .ctrl_wdat(ctrl_wdat), .ctrl_rdat(ctrl_rdat), .ctrl_done(ctrl_done),
           .panel_r0(panel_r0), .panel_g0(panel_g0), .panel_b0(panel_b0),
           .panel_r1(panel_r1), .panel_g1(panel_g1), .panel_b1(panel_b1),
           .panel_a(panel_a), .panel_b(panel_b), .panel_c(panel_c),
           .panel_d(panel_d), .panel_clk(panel_clk), .panel_stb(panel_stb),
           .panel_oe(panel_oe));

assign led[3:1] = 3'b000;

reg [31:0] lines [0:31];

initial $readmemh("lines.hex", lines);

initial begin
  ci_line <= 3;
  r_line <= 30;
  w_line <= 31;
end

task write_led_line;
  input [4:0] line_number;
  input [31:0] value;
  input [23:0] color;
begin
  led_line <= line_number;
  led_color <= color;
  led_value <= value;
  write_leds <= 1;
end
endtask

reg [4:0] led_counter;
reg [4:0] led_line;
reg [31:0] led_value;
reg [23:0] led_color;

wire write_leds, write_done;
reg done, new_write;

always @(posedge clk) begin
  write_done <= 0;
  new_write <= 0;
  if (write_leds) begin
    led_counter <= 0;
    new_write <= 1;
  end
  if (ctrl_done) begin
    ctrl_wr[2:0] <= 3'b000;
    if (&led_counter) write_done <= 1;
    else begin
      new_write <= 1;
      led_counter <= led_counter + 1;
    end
  end
  if (new_write) begin
    ctrl_addr <= (((led_counter) << 5) + 31 - led_line) << 2;
    ctrl_wdat <= led_value[led_counter] ? led_color : 0;
    ctrl_wr[2:0] <= 3'b111;
  end
end

reg[4:0] line_counter;

always @(posedge clk) begin
  write_leds <= 0;
  if (line_counter == 0 || write_done) begin
    if (!(&line_counter)) begin
      write_led_line(line_counter, lines[line_counter], 24'hff0000);
      line_counter <= line_counter + 1;
    end
  end
end

endmodule

