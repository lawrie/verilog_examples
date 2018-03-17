module ping (
  input clk,
  input req,
  input echo,
  output trig,
  output reg [7:0] distance,
  output reg done);

reg [2:0] state = 3'd0;
reg [31:0] counter;
reg [15:0] cm_counter;
reg [7:0] cms;
reg trigger;

assign trig = trigger;

always @(posedge clk)
if (req && !done) begin // Request in progress
  if (counter == 1000000) begin // If we get to 10 milliseconds, then error
     state <= 3'd0;
     done <= 1;
     cms <= 8'd255;
     counter <= 0;
     trigger <= 0;
  end
  else case (state)
  3'd0: begin // Got a request, set trigger low for 2 microseconds
       trigger <= 0;
       if (counter == 200) begin
         trigger <= 1;
         counter <= 0;
         state <= 3'd1;
       end
       else counter <= counter + 1;
     end
  3'd1: begin // Wait for end of trigger pulse, and set it low
       if (counter == 1000) begin
         trigger <= 0;
         counter <= 0;
         state <= 3'd2;
       end
       else counter <= counter + 1;
     end
  3'd2: begin // Make sure echo is low
       if (echo == 0) begin
         counter <= 0;
         state <= 3'd3;
       end
       else counter <= counter + 1;
     end
  3'd3: begin // Wait for echo to go high
       if (echo == 1) begin
          counter <= 0;
          cms <= 0;
          state <= 3'd4;
       end 
       else counter <= counter + 1;
     end
  3'd4: begin // Wait for echo to go low
       if (cm_counter == 5800) begin
         cm_counter <= 0;
         cms <= cms + 1;
       end
       else cm_counter <= cm_counter + 1;

       if (echo == 0) state <= 3'd5;
       else counter <= counter + 1;
     end
  3'd5: begin // Echo finished, return count in centimeters
       counter <= 0;
       done <= 1;
       distance = cms;
       state <= 3'd0;
     end
  default: begin // Echo finished, return count in centimeters
       counter <= 0;
       done <= 1;
       distance = cms;
       state <= 3'd0;
     end
  endcase
end
else begin
  state <= 3'd0;
  done <= 0;
  counter <= 0;
  trigger <= 0;
end
endmodule
