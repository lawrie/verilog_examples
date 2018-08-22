module top(
  input clk_100, 
  input ad_clk, 
  input [7:0] ad,
  output [7:0] led,
  input QCK, QSS,
  inout [3:0] QD,
  output button2,
  //output test
);

reg [7:0] samples [0:4095];

// Clock Generator
wire clk = ad_clk;

reg [24:0] counter;
reg [7:0] trigger;
reg trigger_mode;
reg waiting_for_trigger;
wire take_samples;
reg [1:0]  trigger_type;
reg [7:0] reg_ad, last_ad;
reg [7:0] mode;
reg [7:0] speed;
reg [7:0] prescaler;
reg [7:0] min, max;
reg [11:0] trigger_position;
reg [11:0] start_position = 0;

//localparam TEST_BITS = 2;

//reg [TEST_BITS:0] test_counter;

//assign test = test_counter[TEST_BITS];

//always @(posedge clk) test_counter <= test_counter + 1;

reg[12:0] sample_counter, sample_count; // top bit indicates sample taken
reg set_start;

always @(posedge clk) begin
  set_start <= 0;
  counter <= counter + 1; // Used to request sample transfer, on a timer

  // Register the add value to get stable, synchronized version
  reg_ad <= ad;

  // Use prescaler to set speed of sample acquisition
  prescaler <= prescaler + 1;
  if (prescaler == speed) begin
    last_ad <= reg_ad;
    prescaler <= 0;
  end

  // Start waiting for the trigger
  if (take_samples) begin
    waiting_for_trigger <= 1;
    sample_counter <= 0;
    sample_count <= 0;
    start_position <= 0;
    set_start <= 1;
  end

  // Take the samples, including ones before trigger
  if (~sample_count[12]) begin
    if (prescaler == speed) begin
      if (ad < min) min <= reg_ad;
      if (ad > max) max <= reg_ad;
      case (mode)
      0,1,2: samples[sample_counter] <= reg_ad;
      3: samples[sample_counter] <= sample_counter[7:0] - 128; 
      4: samples[sample_counter] <= 127 - sample_counter[7:0];
      5: samples[sample_counter] <= sample_counter[8] ? sample_counter[7:0] -128 : 127 - sample_counter[7:0];
      6: samples[sample_counter] <= sample_counter[7] ? -128 : 127;
      7: samples[sample_counter] <= speed; // debug
      8: samples[sample_counter] <= trigger; // debug
      9: samples[sample_counter] <= trigger_type; // debug
      endcase
      sample_counter <= sample_counter + 1;
      sample_count <= sample_count + 1;
    end      
  end

  // Process the trigger
  if (waiting_for_trigger && (mode > 2 || trigger_type == 2 || (mode == 0 && sample_counter[12]) || 
     (trigger_type == 0 && sample_count >= trigger_position && prescaler == speed && reg_ad >= trigger && last_ad < trigger) || 
      (trigger_type == 1 && sample_count >= trigger_position && prescaler == speed && reg_ad <= trigger && last_ad > trigger))) begin
    waiting_for_trigger <= 0;
    min <= 255;
    max <= 0;
    if (mode < 2) begin
      sample_count <= trigger_position;
      start_position <= sample_counter - trigger_position;
      set_start <= 1;
    end
  end
end
  
assign led = trigger_position[9:2]; //Diagnostics
assign button2 = ~(&counter); // Ask for samples on timer

reg writing;
reg [7:0] spi_txdata, spi_rxdata;
wire spi_txready, spi_rxready;
reg [11:0] sent, send_position; // Counter for bytes sent
reg [11:0] received;

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
        if (set_start) send_position <= start_position;
	case (writing)
	0: begin
		// receive byte of data
		if (spi_rxready) begin
			case (received)
			0: mode <= spi_rxdata;
                        1: speed <= spi_rxdata;
			2: trigger <= spi_rxdata;
			3: trigger_type <= spi_rxdata;
			4: trigger_position <= spi_rxdata << 2;
			endcase
			received <= received + 1;
		end
		// when chip select rises, switch to writing state
		if (deselect) begin
			sent <= sent +1;
			spi_txdata = samples[send_position];
			send_position <= send_position + 1;
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
