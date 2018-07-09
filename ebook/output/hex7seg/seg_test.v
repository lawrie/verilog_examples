module seg_test(
  input clk,
   output [6:0] seg,
   output digit 
); 

  display_7_seg_hex seghex (.clk(clk), .n(8'hfb), .seg(seg), .digit(digit)); 

endmodule
