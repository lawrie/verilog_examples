module bounce(
  input button, 
  output [3:0] leds); 

  always @(negedge button) leds<= leds+ 1; 

endmodule
