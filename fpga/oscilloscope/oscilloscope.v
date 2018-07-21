module top(
  input clk_100, 
  output ad_clk, 
  input [7:0] ad,
  output [7:0] led,
  input QCK, QSS,
  inout [3:0] QD,
  output button2
);

parameter ClkFreq = 32031250; // Hz
reg [7:0] samples [0:1023];

// Clock Generator
wire clk;

SB_PLL40_PAD #(
  .FEEDBACK_PATH("SIMPLE"),
  .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
  .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
  .PLLOUT_SELECT("GENCLK"),
  .FDA_FEEDBACK(4'b1111),
  .FDA_RELATIVE(4'b1111),
  .DIVR(4'b0011),
  .DIVF(7'b0101000),
  .DIVQ(3'b101),
  .FILTER_RANGE(3'b010)
) pll (
  .PACKAGEPIN(clk_100),
  .PLLOUTGLOBAL(clk),
  .BYPASS(1'b0),
  .RESETB(1'b1)
);

assign ad_clk = counter[1];

reg [24:0] counter;
reg [7:0] trigger = 8'ha0;
reg trigger_mode;
reg waiting_for_trigger;
wire take_samples;
reg rising, falling;
reg [7:0] last_ad;
reg [7:0] mode;
reg [7:0] speed;
reg [7:0] prescaler;

reg[10:0] sample_counter; // top bit indicates sample taken

always @(posedge clk) begin
  counter <= counter + 1; // Used to request sample transfer

  last_ad <= ad;
  rising <= 0;
  falling <= 0;
  if ($signed(ad) > $signed(last_ad)) rising <= 1;
  else if ($signed(ad) < $signed(last_ad)) falling <= 1;
 
  if (take_samples) waiting_for_trigger <= 1;
  if (waiting_for_trigger && (mode != 0 || ad >= trigger)) begin
    waiting_for_trigger <= 0;
    sample_counter <= 0;
    prescaler <= 0;
  end
  if (~sample_counter[10]) begin
    prescaler <= prescaler + 1;
    if (prescaler == speed) begin
      case (mode)
      0: samples[sample_counter] <= ad;
      1: samples[sample_counter] <= sample_counter[7:0] - 128; 
      2: samples[sample_counter] <= 127 - sample_counter[7:0];
      3: samples[sample_counter] <= sample_counter[8] ? sample_counter[7:0] -128 : 127 - sample_counter[7:0];
      4: samples[sample_counter] <= sample_counter[8] ? -128 : 127;
      5: samples[sample_counter] <= speed; // debug
      6: samples[sample_counter] <= trigger; // debug
      endcase
      sample_counter <= sample_counter + 1;
      prescaler <= 0;
    end      
  end
end
  
assign led = ad;
assign button2 = ~(&counter); // Ask for samples on timer

reg writing;
reg [7:0] spi_txdata, spi_rxdata;
wire spi_txready, spi_rxready;
reg [9:0] sent; // Counter for bytes sent
reg [9:0] received;

// synchronise chip select signal, to switch from reading to writing
reg [2:0] select;
always @(posedge clk)
	select <= {select[1:0],~QSS};
wire deselect = (select[1:0] == 2'b10);

// tri-state control for QSPI data lines
wire [3:0] qdin, qdout;
assign qdin = QD;
assign QD = writing ? qdout : 4'bz;

// state machine to alternate reading and writing
always @(posedge clk) begin
        take_samples <= 0;
	case (writing)
	0: begin
		// receive byte of data
		if (spi_rxready) begin
			case (sent)
			0: mode <= spi_rxdata;
                        1: speed <= spi_rxdata;
			2: trigger <= spi_rxdata;
			endcase
			received <= received + 1;
		end
		// when chip select rises, switch to writing state
		if (deselect) begin
			sent <= sent +1;
			spi_txdata = samples[sent];
			// When all samples sent, trigger taking new samples
			if (&sent) take_samples <= 1;
			writing <= 1;
		end
	   end
	1: begin
		if (deselect)
			writing <= 0;
	   end
	endcase
end

qspislave_tx #(.DWIDTH(4)) QT (
	.clk(clk),
	.txdata(spi_txdata),
	.txready(spi_txready),
	.QCK(QCK),
	.QSS(QSS),
	.QD(qdout)
);

qspislave_rx #(.DWIDTH(4)) QR (
	.clk(clk),
	.rxdata(spi_rxdata),
	.rxready(spi_rxready),
	.QCK(QCK),
	.QSS(QSS),
	.QD(qdin)
);

endmodule
