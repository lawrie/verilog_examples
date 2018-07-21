module top(
  input clk_100, 
  output ad_clk, 
  input [7:0] ad,
  output [7:0] led
);

parameter ClkFreq = 32031250; // Hz

// Clock Generator
wire clk_32;
wire pll_locked;

SB_PLL40_PAD #(
  .FEEDBACK_PATH("SIMPLE"),
  .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
  .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
  .PLLOUT_SELECT("GENCLK"),
  .FDA_FEEDBACK(4'b1111),
  .FDA_RELATIVE(4'b1111),
  .DIVR(4'b0011),
  .DIVF(7'b0101000),
  .DIVQ(3'b101),
  .FILTER_RANGE(3'b010)
) pll (
  .PACKAGEPIN(clk_100),
  .PLLOUTGLOBAL(clk_32),
  .LOCK(pll_locked),
  .BYPASS(1'b0),
  .RESETB(1'b1)
);


assign ad_clk = clk_32;
assign led = ad;

endmodule
