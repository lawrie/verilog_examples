module sine(
  input clk,
  input [7:0] idx,
  output [7:0] val);

  signed reg[7:0] rom[0:255];
  
  initial $readmemh ("sine.hex", rom);

  always @(posedge clk) begin
    val <= rom[idx];
  end

endmodule
