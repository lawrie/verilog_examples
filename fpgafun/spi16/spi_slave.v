module SPI_slave(clk, SCK, MOSI, MISO, SSEL, DATA, VALID);
input clk;

input SCK, SSEL, MOSI;
output MISO;
output reg[15:0] DATA;
output VALID;

// sync SCK to the FPGA clock using a 3-bits shift register
reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

// same thing for SSEL
reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
wire SSEL_active = ~SSELr[1];  // SSEL is active low
wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

// and for MOSI
reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
wire MOSI_data = MOSIr[1];

// we handle SPI in 16-bits format, so we need a 4 bits counter to count the bits as they come in
reg [3:0] bitcnt;

reg word_received;  // high when a byte has been received
reg [15:0] data_received;

always @(posedge clk)
begin
  if(~SSEL_active)
    bitcnt <= 4'b0000;
  else
  if(SCK_risingedge)
  begin
    bitcnt <= bitcnt + 4'b0001;

    // implement a shift-left register (since we receive the data MSB first)
    data_received <= {data_received[14:0], MOSI_data};
  end
end

always @(posedge clk) word_received <= SSEL_active && SCK_risingedge && (bitcnt==4'b1111);

always @(posedge clk) begin
  VALID <= 0;
  if(word_received) begin
    DATA <= data_received;
    VALID <= 1;
  end
end

reg [15:0] data_sent;

reg [16:0] cnt;
always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+16'h0001;  // count the messages

always @(posedge clk)
if(SSEL_active)
begin
  if(SSEL_startmessage)
    data_sent <= cnt;  // first word sent in a message is the message count
  else
  if(SCK_fallingedge)
  begin
    if(bitcnt==4'b0000)
      data_sent <= 16'h0000;  // after that, we send 0s
    else
      data_sent <= {data_sent[14:0], 1'b0};
  end
end

assign MISO = data_sent[15];  // send MSB first
// we assume that there is only one slave on the SPI bus
// so we don't bother with a tri-state buffer for MISO
// otherwise we would need to tri-state MISO when SSEL is inactive

endmodule

