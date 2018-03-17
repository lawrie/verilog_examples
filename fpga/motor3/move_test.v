module move_test (
  input CLK,
  output ENABLE1,
  output DIRECTION1,
  input CHA1,
  input CHB1,
  output ENABLE2,
  output DIRECTION2,
  input CHA2,
  input CHB2,
  output [3:0] LED);

reg req, done;
wire [2:0] op;
wire [31:0] operand;

move m1 (.CLK(CLK),
         .ENABLE1(ENABLE1), .DIRECTION1(DIRECTION1), .CHA1(CHA1), .CHB1(CHB1),
         .ENABLE2(ENABLE2), .DIRECTION2(DIRECTION2), .CHA2(CHA2), .CHB2(CHB2),
         .LED(LED), .req(req), .op(op), .operand(operand), .done(done));


reg [29:0] counter = 0;
reg [1:0] state = 2'd0;
reg [24:0] wait_counter = 0;

always @(posedge CLK) begin
  if (&counter) begin // after 8 seconds
    state = 2'd0;
    op <= 3'd0; //forwards;
    operand <= 32'd1000;
    req <= 1;
  end

  counter <= counter + 1;
  
  if (state == 2'd2) begin
    op <= 3'd1;
    operand <= 32'd500;
    state <= 3'd3;
    req <= 1;  
  end

  if (state == 2'd1) begin
    if (&wait_counter) state <= 2'd2;
    else wait_counter <= wait_counter + 1;
  end

  if (done) begin
    req <= 0;
    if (state == 2'd0) begin
      wait_counter <= 0;
      state <= 2'd1;
    end
  end

end
endmodule
