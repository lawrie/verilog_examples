// Pong VGA game
// (c) fpga4fun.com

module pong(
  input CLK, 
  output P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10,
  output P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10,
  input P2_1, P2_2
);

wire inDisplayArea;
wire [9:0] CounterX;
wire [9:0] CounterY;
wire clk;

//-----------------------------------------------------------------------------
// PLL.
//-----------------------------------------------------------------------------
SB_PLL40_PAD #(
  .DIVR(4'b0000),
  // 40MHz ish to be exact it is 39.750MHz
  //.DIVF(7'b0110111), // 42MHz
  .DIVF(7'b0110101), // 39.750MHz
  .DIVQ(3'b100),
  .FILTER_RANGE(3'b001),
  .FEEDBACK_PATH("SIMPLE"),
  .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
  .FDA_FEEDBACK(4'b0000),
  .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
  .FDA_RELATIVE(4'b0000),
  .SHIFTREG_DIV_MODE(2'b00),
  .PLLOUT_SELECT("GENCLK"),
  .ENABLE_ICEGATE(1'b0)
) usb_pll_inst (
  .PACKAGEPIN(CLK),
  .PLLOUTCORE(clk),
  //.PLLOUTGLOBAL(),
  .EXTFEEDBACK(),
  .DYNAMICDELAY(),
  .RESETB(1'b1),
  .BYPASS(1'b0),
  .LATCHINPUTVALUE(),
  //.LOCK(),
  //.SDI(),
  //.SDO(),
  //.SCLK()
);

wire          u0_vid_new_frame;
wire          u0_vid_new_line;
wire          vga_de;
wire          vga_ck;
wire          vga_hs;
wire          vga_vs;
  
wire [7:0]    r;
wire [7:0]    g;
wire [7:0]    b;

assign vga_ck = clk;
assign vga_de = inDisplayArea;

reg  [15:0]   u0_pel_x;
reg  [15:0]   u0_pel_y;

// 12b for dual-PMOD
assign {P1A1,   P1A2,   P1A3,   P1A4,   P1A7,   P1A8,   P1A9,   P1A10} = 
       {r[7],   r[5],   g[7],   g[5],   r[6],   r[4],   g[6],   g[4]};
assign {P1B1,   P1B2,   P1B3,   P1B4,   P1B7,   P1B8,   P1B9,   P1B10} = 
       {b[7],   vga_ck, b[4],   vga_hs, b[6],   b[5],   vga_de, vga_vs};

// ----------------------------------------------------------------------------
// VGA Timing Generator
// ----------------------------------------------------------------------------
vga_timing u0_vga_timing
(
  .reset                           ( 0                 ),
  .clk_dot                         ( clk               ),
  .vid_new_frame                   ( u0_vid_new_frame  ),
  .vid_new_line                    ( u0_vid_new_line   ),
  .vid_active                      ( inDisplayArea     ),
  .vga_hsync                       ( vga_hs            ),
  .vga_vsync                       ( vga_vs            )
);

// ----------------------------------------------------------------------------
// Raster Counters. Count the Pixel Location in X and Y
// ----------------------------------------------------------------------------
always @ ( posedge clk ) begin : proc_u0_raster_cnt
 begin
  if ( u0_vid_new_frame == 1 ) begin
    u0_pel_y <= 16'd0;
  end else if ( u0_vid_new_line == 1 ) begin
    if ( u0_pel_y == 16'hFFFF ) begin
      u0_pel_y <= 16'hFFFF;// Prevent rollover
    end else begin
      u0_pel_y <= u0_pel_y + 1;
    end
  end // if ( vid_new_frame == 1 ) begin

  if ( u0_vid_new_line == 1 ) begin
    u0_pel_x <= 16'd0;
  end else begin
    if ( u0_pel_x == 16'hFFFF ) begin
      u0_pel_x <= 16'hFFFF;// Prevent rollover
    end else begin
      u0_pel_x <= u0_pel_x + 1;
    end
  end  // if ( vid_new_line  == 1 ) begin

 end // clk+reset
end // proc_u0_raster_cnt

assign CounterX = u0_pel_x;
assign CounterY = u0_pel_y;

/////////////////////////////////////////////////////////////////
reg [8:0] PaddlePosition;
reg [2:0] quadAr, quadBr;
always @(posedge clk) quadAr <= {quadAr[1:0], P2_1};
always @(posedge clk) quadBr <= {quadBr[1:0], P2_2};

always @(posedge clk)
if(quadAr[2] ^ quadAr[1] ^ quadBr[2] ^ quadBr[1])
begin
	if(quadAr[2] ^ quadBr[1])
	begin
		if(~&PaddlePosition)        // make sure the value doesn't overflow
			PaddlePosition <= PaddlePosition + 1;
	end
	else
	begin
		if(|PaddlePosition)        // make sure the value doesn't underflow
			PaddlePosition <= PaddlePosition - 1;
	end
end

/////////////////////////////////////////////////////////////////
reg [9:0] ballX;
reg [8:0] ballY;
reg ball_inX, ball_inY;

always @(posedge clk)
if(ball_inX==0) ball_inX <= (CounterX==ballX) & ball_inY; else ball_inX <= !(CounterX==ballX+16);

always @(posedge clk)
if(ball_inY==0) ball_inY <= (CounterY==ballY); else ball_inY <= !(CounterY==ballY+16);

wire ball = ball_inX & ball_inY;

/////////////////////////////////////////////////////////////////
wire border = (CounterX[9:3]==0) || (CounterX[9:3]==79) || (CounterY[8:3]==0) || (CounterY[8:3]==59);
wire paddle = (CounterX>=PaddlePosition+8) && (CounterX<=PaddlePosition+120) && (CounterY[8:4]==27);
wire BouncingObject = border | paddle; // active if the border or paddle is redrawing itself

reg ResetCollision;
always @(posedge clk) ResetCollision <= (CounterY==500) & (CounterX==0);  // active only once for every video frame

reg CollisionX1, CollisionX2, CollisionY1, CollisionY2;
always @(posedge clk) if(ResetCollision) CollisionX1<=0; else if(BouncingObject & (CounterX==ballX   ) & (CounterY==ballY+ 8)) CollisionX1<=1;
always @(posedge clk) if(ResetCollision) CollisionX2<=0; else if(BouncingObject & (CounterX==ballX+16) & (CounterY==ballY+ 8)) CollisionX2<=1;
always @(posedge clk) if(ResetCollision) CollisionY1<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY   )) CollisionY1<=1;
always @(posedge clk) if(ResetCollision) CollisionY2<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY+16)) CollisionY2<=1;

/////////////////////////////////////////////////////////////////
wire UpdateBallPosition = ResetCollision;  // update the ball position at the same time that we reset the collision detectors

reg ball_dirX, ball_dirY;
always @(posedge clk)
if(UpdateBallPosition)
begin
	if(~(CollisionX1 & CollisionX2))        // if collision on both X-sides, don't move in the X direction
	begin
		ballX <= ballX + (ball_dirX ? -1 : 1);
		if(CollisionX2) ball_dirX <= 1; else if(CollisionX1) ball_dirX <= 0;
	end

	if(~(CollisionY1 & CollisionY2))        // if collision on both Y-sides, don't move in the Y direction
	begin
		ballY <= ballY + (ball_dirY ? -1 : 1);
		if(CollisionY2) ball_dirY <= 1; else if(CollisionY1) ball_dirY <= 0;
	end
end 

/////////////////////////////////////////////////////////////////
wire R = BouncingObject | ball | (CounterX[3] ^ CounterY[3]);
wire G = BouncingObject | ball;
wire B = BouncingObject | ball;

reg vga_R, vga_G, vga_B;
always @(posedge clk)
begin
	vga_R <= R & inDisplayArea;
	vga_G <= G & inDisplayArea;
	vga_B <= B & inDisplayArea;
end

wire in_vga_area = CounterX < 640 && CounterY < 480;

assign r = in_vga_area && vga_R ? 8'hff : 8'h00;
assign g = in_vga_area && vga_G ? 8'hff : 8'h00;
assign b = in_vga_area &&  vga_B ? 8'hff : 8'h00;

endmodule
