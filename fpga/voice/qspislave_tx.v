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

