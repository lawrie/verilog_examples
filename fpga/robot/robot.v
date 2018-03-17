module robot (
  input CLK,
  input ECHO,
  output TRIG,
  output ENABLE1,
  output DIRECTION1,
  input CHA1,
  input CHB1,
  output ENABLE2,
  output DIRECTION2,
  input CHA2,
  input CHB2,
  input BUTTON1,
  output [6:0] SEG2,
  output [1:0] DIGIT,
  output [3:0] LED);

localparam waiting = 3'd0,
           going_forwards = 3'd1,
           obstacle = 3'd2,
           going_backwards = 3'd3,
           waiting_to_turn = 3'd4,
           turning = 3'd5,
           waiting_for_forwards = 3'd6;

localparam forwards = 3'd0,
           backwards = 3'd1,
           left = 3'd2,
           right = 3'd3,
           stop = 3'd4;

reg [7:0] distance;
reg ping_req, ping_done;

ping p1 (.clk(CLK), .echo(ECHO), .trig(TRIG), .req(ping_req),
         .distance(distance), .done(ping_done));

reg start;

debouncer d0 (.CLK(CLK), .switch_input(BUTTON1), .trans_up(start));

reg req, done;
wire [2:0] op;
wire [31:0] operand;

move m1 (.CLK(CLK),
         .ENABLE1(ENABLE1), .DIRECTION1(DIRECTION1), .CHA1(CHA1), .CHB1(CHB1),
         .ENABLE2(ENABLE2), .DIRECTION2(DIRECTION2), .CHA2(CHA2), .CHB2(CHB2),
         .LED(LED), .req(req), .op(op), .operand(operand), .done(done));


reg [2:0] state = waiting;
reg [25:0] wait_counter = 0;
reg [24:0] ping_counter = 0;

always @(posedge CLK) begin
  if (&ping_counter) ping_req <= 1;
  else if (ping_done) ping_req <= 0;
  ping_counter <= ping_counter + 1;

  if (distance < 50 && state != waiting) begin
    op <= stop;
    wait_counter <= 0;
    state <= obstacle;
  end

  if (start) begin //  Button pressed
    state <= going_forwards;
    op <= forwards;
    operand <= 32'd1000000;
    req <= 1;
  end

  if (state == obstacle) begin
    op <= backwards;
    if (&wait_counter) begin
      operand <= 32'd2000;
      req <= 1;
      state <= going_backwards;
    end
    else wait_counter <= wait_counter + 1;
  end

  if (state == waiting_to_turn) begin
    if (&wait_counter) begin
      state <= turning;
      op <= left;
      operand <= 32'd1000;
      req <= 1;
    end
    else wait_counter <= wait_counter + 1;
  end

  if (state == waiting_for_forwards) begin
    if (&wait_counter) begin
      state <= going_forwards;
      op <= forwards;
      operand <= 32'd1000000;
      req <= 1;
    end
    else wait_counter <= wait_counter + 1;
  end

  if (done) begin
    req <= 0;
    if (state == going_backwards) begin
      wait_counter <= 0;
      state <= waiting_to_turn;
    end 
    else if (state == turning) begin
      wait_counter <= 0;
      state <= waiting_for_forwards;
    end
  end
end

reg [3:0] h, t, u;

bcd b1 (distance, h, t, u);

display_7_seg di1 (.CLK(CLK), .units(t), .tens({1'b0, state}),
                  .SEG(SEG2), .DIGIT(DIGIT[1]));

endmodule
