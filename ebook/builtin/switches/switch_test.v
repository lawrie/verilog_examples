module switch_test(
  output [3:0] led, 
  input [3:0] switch ); 

  assign led = switch; 

endmodule
