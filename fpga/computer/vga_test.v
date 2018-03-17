module vga_test(
    input CLK,
    input GRESET,
    output AUDIO,
    output HS,
    output VS,
    output [3:0] RED,
    output [3:0] GREEN,
    output [3:0] BLUE,
    input PS2_CLK,
    input PS2_DATA,
    output [3:0] LED
    );

   // Generate 25Mhz clock for the PS/2 interface
   reg [1:0]  clkpre = 2'b00;     // prescaler, from 100MHz to 25MHz

   always @(posedge CLK) begin
     clkpre <= clkpre + 1;
   end
   
   wire clk25 = clkpre[1];
 
   // Generate a negative reset signal at start up for keyboard interface
   reg [9:0] reset_counter = 0;
   wire reset_n = &reset_counter;

   // reset_n will be held low for 1ms, then stay high
   always @(posedge clk25) 
   if (!reset_n) begin
     reset_counter = reset_counter + 1;
   end
 
   // Define the VGA labels and text fields
   wire show_text0, show_text1, show_text2, show_text3, 
        show_text4, show_text5, show_text6;

   reg [40*8-1:0] buffer; // For text box
   reg [9:0] buf_len = 0;
   reg [7:0] scan_hex1, scan_hex2, ascii_hex1, ascii_hex2;

   text_field #(.max_len(13)) heading (.text("Keyboard test"), .x(x), .y(y), 
                .text_len(13), .x_offset(268), .y_offset(32), .show_text(show_text0));

   text_field #(.max_len(5)) label1 (.text("Text:"), .x(x), .y(y), .text_len(5),
                .x_offset(32), .y_offset(64), .show_text(show_text1));

   text_field #(.max_len(40)) box1 (.text(buffer), .x(x), .y(y), .text_len(buf_len),
                .x_offset(80), .y_offset(64), .show_text(show_text2));

   text_field #(.max_len(16)) label2 (.text("Last scan code :"), .x(x), .y(y), 
             .text_len(16), .x_offset(32), .y_offset(96), .show_text(show_text3));

   text_field #(.max_len(2)) box2 (.text({scan_hex1, scan_hex2}), .x(x), .y(y), 
             .text_len(2), .x_offset(160), .y_offset(96), .show_text(show_text5));

   text_field #(.max_len(16)) label3 (.text("Last character :"), .x(x), .y(y), 
             .text_len(16), .x_offset(32), .y_offset(128), .show_text(show_text4));

   text_field #(.max_len(2)) box3 (.text({ascii_hex1, ascii_hex2}), .x(x), .y(y), 
             .text_len(2), .x_offset(160), .y_offset(128), .show_text(show_text6));

   // Generate VGA sync signals and get x, y position
   wire [9:0] x, y;

   vga v(.CLK (CLK), .HS (HS), .VS (VS), .x (x), .y (y));

   // Define line, border and cursor on the screen
   wire border = (x > 0 && y < 480) && (x < 3 || x > 637 || y < 2 || y > 477);

   wire line = (y == 48 && x >= 268 && x < 372);

   wire cursor = (count[24] && y == 80 && x >= 80 + (buf_len << 3) &&
              x < 88 + (buf_len << 3));

   // Set the colours
   assign RED = (show_text1 || show_text0 || show_text3 || show_text4 || line)?15:0;
   assign GREEN = (show_text1 || show_text5 || show_text6 || border || cursor)?15:0;
   assign BLUE = (show_text1 || show_text2)?15:0;

   // Create a one second signal
   reg [24:0] count;

   always @(posedge clk25) begin
     count <= count + 1;
   end
  
   reg [7:0] scan_code, ascii, key; // Scan code and converted ascii
   wire valid, error, extended, shift, ctrl, alt, released, got_key;

   // Get a scan code from the keyboard

   ps2_intf ps2
     (
      .CLK    (clk25),
      .nRESET (reset_n),
      .PS2_CLK  (PS2_CLK),
      .PS2_DATA (PS2_DATA),
      .DATA  (key),
      .VALID (valid),
      .error (error)
      );

   // Show the last 4 bits of the scan code on the LEDs
   assign LED = scan_code[3:0];
   
   // Convert the scan code to ascii
   PS2ScanToAscii convert (.sc(scan_code), .ascii(ascii),
                           .extend(extended), .shift(shift), .ctrl(ctrl), .alt(alt));

   // Look for valid input characters and put them in the buffer
   always @(posedge clk25) begin
     if (valid) begin
       if (key == 8'hE0) extended <= 1;
       else if (key == 8'hF0) released <= 1;
       else if (key == 8'h12 || key == 8'h59) begin
         shift <= ~released;
         released <= 0;
       end
       else if (key == 8'h14) ctrl <= ~released;
       else if (key == 8'h11) alt <= ~released;
       else begin
         if (!released) begin
           scan_code <= key; 
           got_key <= 1;
         end
         released <= 0;
       end
     end
     
     if (got_key) begin
       // Process key
       if (ascii == 8'h08) begin // backspace
         if (buf_len > 0) begin
            buf_len <= buf_len - 1;
            buffer <= buffer >> 8;
         end
       end
       else if (ascii != 8'h2e)  begin // how does scan_code = 8'hF0 happen?
         if (buf_len < 40) begin
           buf_len <= buf_len + 1;
           buffer <= {buffer, ascii};
         end else beep <= 100; // beep
       end

       extended <= 0;
       got_key <= 0;
     end

     if (done) beep <= 0;

   end

   // Convert scan_code and ascii code to hex
   byte_to_hex h1(scan_code[3:0], scan_hex1);
   byte_to_hex h2(scan_code[7:4], scan_hex2);

   byte_to_hex h3(ascii[3:0], ascii_hex2);
   byte_to_hex h4(ascii[7:4], ascii_hex1);

   // Beep
   reg [31:0] beep_period  = 100000;

   reg [31:0] beep; // milliseconds
   reg done;

   tone #(12) t2(.CLK (clk25), .time(beep), .period (beep_period), 
                 .tone_out (AUDIO), .done(done));

endmodule
