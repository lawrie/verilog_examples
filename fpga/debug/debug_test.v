module debug_test (
  input clk,
  input greset,
  output UART_TX);

  reg [7:0]  char = "A";

  wire [7:0] hex1, hex2;

  byte_to_hex h1(char[3:0], hex1);
  byte_to_hex h2(char[7:4], hex2);

  wire [15:0] text = {hex2, hex1};

  reg text_req = 0;
  reg text_done;

  debug #(.text_len(7)) db
          (.clk(clk), .greset(greset), .text_req(text_req), .text_done(text_done),
            .debug_text(" Hello\n"), .UART_TX(UART_TX));
 
  reg [26:0] counter = 1;

  always @(posedge clk) begin
    if (text_done) text_req <= 1'b0;
    if (counter == 0) text_req <= 1;
    counter <= counter + 1;
  end

endmodule	
