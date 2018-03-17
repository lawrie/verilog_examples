module tone(
    input CLK,
    input [31:0] time,
    input [31:0] period, // microseconds 
    output reg tone_out,
    output done
    );

parameter CLK_F = 25; // CLK freq in MHz

reg [7:0] prescaler = 0; 
reg [31:0] counter = 0;
reg [31:0] time_counter = 0;
reg [31:0] millis  = 0;

localparam clocks_per_milli = CLK_F * 1000;

always @(posedge CLK)
if (time > 0) begin
  if (time_counter == clocks_per_milli) begin
    millis <= millis + 1;
    time_counter <= 0;
  end
  else time_counter <= time_counter + 1;
  
  if (millis < time) begin  
    prescaler <= prescaler + 1;
    if (prescaler == CLK_F / 2 - 1) 
    begin
      prescaler <= 0;
      counter <= counter + 1;
      if (counter == period - 1)
      begin
        counter <= 0;
        tone_out <= ~ tone_out;
      end		
    end
  end else begin
    tone_out <= 0;
    done = 1;
  end
end 
else begin
  millis <= 0;
  done <= 0;
end

endmodule
