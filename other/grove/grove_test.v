module chip (
    // 100MHz clock input
    input  clk,
    input  [3:0] switches,
    output [3:0] led);

assign led = switches;

endmodule
