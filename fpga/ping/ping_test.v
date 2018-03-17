module ping_test (
  input CLK,
  input ECHO,
  output TRIG,
  output [6:0] SEG1,
  output [6:0] SEG2,
  output [1:0] DIGIT,
  output [3:0] LED);

reg [26:0] counter = 1;
reg req = 0, done;
reg [3:0] cm_digits;
reg [3:0] cm_tens;
reg [3:0] cm_hundreds;

//assign LED = cms[3:0];

ping p1 (.clk(CLK), .led(LED), .echo(ECHO), .trig(TRIG), .req(req), 
         .cm_digits(cm_digits), .cm_tens(cm_tens), .cm_hundreds(cm_hundreds),
         .done(done));

always @(posedge CLK) begin
  if (done) req <= 0;
  if (counter == 0) req <= 1;
  counter <= counter + 1;
end

display_7_seg d1 (.CLK(CLK), .units(cm_digits), .tens(cm_tens), 
                  .SEG(SEG1), .DIGIT(DIGIT[0]));

display_7_seg d2(.CLK(CLK), .units(cm_hundreds), .tens(0), 
                  .SEG(SEG2), .DIGIT(DIGIT[1]));
endmodule
