module qspiplay (
// QSPI example:

// Assume QSPI clock mode is 3 (CPOL=CPHA=1)
//   Clock idle state is high when QSS is high (deselected)
//   Both master and slave sample data on rising clock edge

	input CLK100,
	input QCK, QSS,
	inout [3:0] QD,
        output AUDIO
);

	reg writing;
	wire clk = CLK100;
	reg [7:0] spi_txdata, spi_rxdata;
	wire spi_txready, spi_rxready;
	reg [7:0] data;

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
	always @(posedge clk) case (writing)
	0: begin
		// receive byte of data
		if (spi_rxready)
			data <= spi_rxdata;
		// when chip select rises, switch to writing state
		if (deselect) begin
			spi_txdata <= data;
			writing <= 1;
		end
	   end
	1: begin
		if (deselect)
			writing <= 0;
	   end
	endcase

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

	PWM pwm (.clk(clk), .RxD_data_ready(spi_rxready), 
                 .RxD_data(data), .PWM_out(AUDIO));

endmodule

// Receive QSPI data from master to slave
// DWIDTH (1 or 4) is number of data lines
// rxready is asserted for one clk period
//   when each input byte is available in rxdata

module qspislave_rx #(parameter DWIDTH=1) (
	input clk,
	input QCK, QSS,
	input [3:0] QD,
	output rxready,
	output [7:0] rxdata
);

	// registers in QCK clock domain
	reg [8:0] shiftreg;
	reg inseq;

	// registers in main clk domain
	reg [7:0] inbuf;
	assign rxdata = inbuf;
	reg [2:0] insync;

	// synchronise inseq across clock domains
	always @(posedge clk)
		insync <= {inseq,insync[2:1]};
	assign rxready = (insync[1] != insync[0]);

	// wiring to load data from 1 or 4 data lines into shiftreg
	wire [8:0] shiftin = {shiftreg[8-DWIDTH:0],QD[DWIDTH-1:0]};

	// capture incoming data on rising SPI clock edge
	always @(posedge QCK or posedge QSS)
		if (QSS)
			shiftreg <= 0;
		else begin
			if (shiftin[8]) begin
				inbuf <= shiftin[7:0];
				inseq <= ~inseq;
				shiftreg <= 0;
			end else if (shiftreg[7:0] == 0)
				shiftreg = {1'b1,QD[DWIDTH-1:0]};
			else
				shiftreg <= shiftin;
		end

endmodule

// Transmit QSPI data from slave to master
// txready is asserted for one clk period
//   when one output byte has been sent from txdata,
//   and the next byte must be supplied before the next
//   rising edge of QCK

module qspislave_tx #(parameter DWIDTH=1) (
	input clk,
	input QCK, QSS,
	output [3:0] QD,
	output txready,
	input [7:0] txdata
);

	// registers in QCK clock domain
	reg [8:0] shiftreg;
	reg outseq;
	assign QD[3:0] = shiftreg[8:9-DWIDTH];

	// registers in main clk domain
	reg [2:0] outsync;

	// synchronise outseq across clock domains
	always @(posedge clk)
		outsync <= {outseq,outsync[2:1]};
	assign txready = (outsync[1] != outsync[0]);

	// wiring to shift data from shiftreg into 1 or 4 data lines
	wire [8:0] shiftout = shiftreg << DWIDTH;

	// shift outgoing data on falling SPI clock edge
	always @(negedge QCK or posedge QSS)
		if (QSS)
			shiftreg <= 0;
		else begin
			if (shiftout[7:0] == 0) begin
				outseq <= ~outseq;
				shiftreg <= {txdata,1'b1};
			end else
				shiftreg <= shiftout;
		end

endmodule
