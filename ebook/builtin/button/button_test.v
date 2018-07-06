module button_test( 
  output blue_led, 
  input button1 ); 

  assign blue_led = ~button1; 

endmodule
