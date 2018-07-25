module paneltest(
  input clk100,
  input resetn,
  output [3:0] led,
  output reg panel_r0, panel_g0, panel_b0, panel_r1, panel_g1, panel_b1,
  output reg panel_a, panel_b, panel_c, panel_d, panel_clk, panel_stb, panel_oe);

localparam SPEED= 18, COLOR = 'hff0000;

wire [3:0] ctrl_wr;
wire ctrl_rd;
wire [15:0] ctrl_addr;
wire [31:0] ctrl_wdat;
reg [31:0] ctrl_rdat;
reg ctrl_done;

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
reg [4:0] line_counter;
reg [SPEED:0] slow_counter;

initial $readmemh("lines.hex", lines);

always @(posedge clk100) begin
  slow_counter <= slow_counter + 1;
  if (&slow_counter[SPEED-5:0]) begin
    if (&slow_counter) line_counter <= line_counter + 1;
    if (&lines[line_counter][slow_counter[SPEED:SPEED-4]]) begin
      ctrl_addr <= (((31 - slow_counter[SPEED:SPEED-4]) << 5) + line_counter)  << 2;
      ctrl_wdat <= COLOR;
      ctrl_wr[2:0] <= 3'b111;
    end
  end 
  if (ctrl_done) ctrl_wr[2:0] <= 3'b000;
end
 
endmodule



