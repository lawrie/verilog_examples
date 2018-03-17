module tone_tester(
    input CLK,
    output AUDIO,
    );

reg [31:0] period  = 100000; 
reg [28:0] second_counter = 1;
reg done;

always @(posedge CLK) begin
  if (second_counter == 0) time <= 500;
  second_counter <= second_counter + 1;
  if (done) time <= 0;
end

reg [31:0] time = 0;
//wire [31:0] time = 500;

tone #(12) t(.CLK (CLK), .time(time), .period (period), .tone_out (AUDIO), .done(done));

endmodule
