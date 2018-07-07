module debounce(
  input clk,
  input button,
  output [3:0] leds); 

reg PB_state, PB_down, PB_up; 

PushButton_Debouncer pdb ( 
  .clk(clk),.PB(button), .PB_state(PB_state), 
  .PB_down(PB_down), .PB_up(PB_up));

always @(posedge clk) if (PB_down) leds <= leds + 1; 

endmodule
