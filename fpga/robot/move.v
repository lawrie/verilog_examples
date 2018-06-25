module move (
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
  input req,
  input [2:0] op,
  input [31:0] operand,
  output [31:0] todo,
  input [7:0] speed,
  output reg done);

localparam forwards = 3'd0,
           backwards = 3'd1,
           left = 3'd2,
           right = 3'd3,
           stop = 3'd4;

reg direction1 = 0, direction2 = 0;

assign DIRECTION1 = ~direction1;
assign DIRECTION2 = ~direction2;

initial done <= 0;

// Set the frequency to 1.5 Khz
reg [7:0] duty = 0;
reg [7:0] prescaler = 0; // CLK freq / 256 / 256 = 1.5kHz

wire enable;
pwm p1 (.pwm_clk (prescaler[7]), .duty (duty), .PWM_PIN (enable));

assign ENABLE1 = enable;  
assign ENABLE2 = enable;

assign LED[0] = req;
assign LED[1] = new_request;
assign LED[2] = req_processed;
assign LED[3] = done;
assign todo = target - count1;

// Use the quadrature to get the positions of each motor
reg [31:0] count1, count2;
quad q1 (.clk(CLK), .quadA(CHA1), .quadB(CHB1), .count(count1));
quad q2 (.clk(CLK), .quadA(CHA2), .quadB(CHB2), .count(count2));

reg [31:0] target;

reg new_request = 0, req_processed = 0;

// Set prescaler 
always @(posedge CLK)
begin
  prescaler <= prescaler + 1;
  
  if (op == stop || (req & !req_processed)) new_request <= 1;
  else new_request <= 0;

  if (new_request) begin
    case (op)
    forwards: begin
         target <= count1 + operand; // forwards
         direction1 <= 0;
         direction2 <= 0;
         duty <= speed;
       end
    
    backwards: begin
         target <= count1 - operand; // backwards
         direction1 <= 1;
         direction2 <= 1;
         duty <= speed;
       end      
    
    left: begin
         target <= count1 + operand; // left
         direction1 <= 1;
         direction2 <= 0;
         duty <= speed;
       end      
    
    right: begin
         target <= count1 - operand; // right
         direction1 <= 0;
         direction2 <= 1;
         duty <= speed;
       end      
    
    stop: begin
         target <= count1; // stop
         direction1 <= 0;
         direction2 <= 0;
         duty <= 0;
       end      
    endcase

    req_processed <= 1;
  end

  if (!req) req_processed <= 0;

  if (req && count1 == target) begin
    done <= 1;
    duty <= 0;
  end
  else done <= 0;

end
endmodule

