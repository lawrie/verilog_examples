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
