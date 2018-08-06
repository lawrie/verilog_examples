module top(
  input clk, 
  output sck,
  input miso,
  output ss,
  output [7:0] led,
  input qck, qss,
  inout [3:0] qd,
  output button2,
  output [3:0] led2
);

reg [7:0] samples [0:16383];
reg [13:0] sample_counter;
wire take_samples;
reg [28:0] counter;
assign button2 = ~(&counter); // Ask for samples on timer

reg writing;
reg [7:0] spi_txdata, spi_rxdata;
wire spi_txready, spi_rxready;
reg [13:0] sent; // Counter for bytes sent
reg [13:0] received;

wire done;
wire req;

reg [15:0] data;

assign led = sample_counter[11:4]; //data[7:0];
assign led2 = {&sample_counter, ss, done, req};

// synchronise chip select signal, to switch from reading to writing
reg [2:0] select;
always @(posedge clk)
	select <= {select[1:0],~qss};
wire deselect = (select[1:0] == 2'b10);

// tri-state control for QSPI data lines
wire [3:0] qdin, qdout;
assign qdin = qd;
assign qd = writing ? qdout : 4'bz;

initial ss <= 1;

// state machine to alternate reading and writing
always @(posedge clk) begin
        counter <= counter + 1;
        take_samples <= 0;
	case (writing)
	0: begin
		// receive byte of data
		if (spi_rxready) begin
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
	if (done) begin
          samples[sample_counter] <= (data+15) >> 4;
          if (!(&sample_counter)) sample_counter <= sample_counter + 1;
          req <= 0;
          ss <= 1;
        end else if (!req && !(&sample_counter)) begin
          ss <= 0;
          req <= 1;
        end 

       if (take_samples) sample_counter <= 0;
end

reg[15:0] speed = 511;

spi16in spim (.clk(clk), .sck(sck), .miso(miso), .speed(speed),
               .data(data), .req(req), .done(done));


qspislave_tx #(.DWIDTH(4)) qt (
	.clk(clk),
	.txdata(spi_txdata),
	.txready(spi_txready),
	.QCK(qck),
	.QSS(qss),
	.QD(qdout)
);

qspislave_rx #(.DWIDTH(4)) qr (
	.clk(clk),
	.rxdata(spi_rxdata),
	.rxready(spi_rxready),
	.QCK(qck),
	.QSS(qss),
	.QD(qdin)
);

endmodule
