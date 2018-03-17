module motor (
  input CLK,
  output ENABLE1,
  output DIRECTION1,
  input CHA1,
  input CHB1,
  output ENABLE2,
  output DIRECTION2,
  input CHA2,
  input CHB2,
  output [3:0] LED,
  input SWITCH1,
  input BUTTON1,
  input BUTTON2);

// Use switch 1 to set the direction of motors
reg direction1;
debouncer d0 (.CLK(CLK), .switch_input(SWITCH1), .state(direction1));

// Both motors have same direction and speed
assign DIRECTION1 = direction1;
assign DIRECTION2 = direction1;
assign ENABLE2 = ENABLE1;

// Show count of motor 1 on LEDs
assign LED = count1[3:0];

// Buttons 1 and 2 set the PWM duty cycle up and down
wire s_up, s_dn;
debouncer d1(.CLK (CLK), .switch_input (BUTTON1), .trans_up (s_up));
debouncer d2(.CLK (CLK), .switch_input (BUTTON2), .trans_up (s_dn));

// Set the frequency to 1.5 Khz
reg [7:0] duty = 0;
reg [7:0] prescaler = 0; // CLK freq / 256 / 256 = 1.5kHz
pwm p(.pwm_clk (prescaler[7]), .duty (duty), .PWM_PIN (ENABLE1));

// Use the quadrature to get the positions of each motor
reg [7:0] count1, count2;
quad q1 (.clk(CLK), .quadA(CHA1), .quadB(CHB1), .count(count1));
quad q2 (.clk(CLK), .quadA(CHA2), .quadB(CHB2), .count(count2));

// Set prescaler and duty
always @(posedge CLK)
begin
  prescaler <= prescaler + 1;
  if (s_up) duty <= duty + 5;
  if (s_dn) duty <= duty - 5;
end

endmodule

