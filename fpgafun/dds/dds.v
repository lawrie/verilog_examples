module dds(
  input clk, 
  output DAC_clk, 
  input quadA,
  input quadB,
  input button,
  output[7:0] DAC_data
);

localparam BITS = 24;

assign DAC_clk = clk; // 100Mhz

reg [BITS-1:0] phase_acc;

//wire cnt_tap = cnt[7];
//assign DAC_data = {8{cnt_tap}};  
//assign DAC_data = cnt[7:0];   
//assign DAC_data = ~cnt[7:0];  
//assign DAC_data = cnt[8] ? ~cnt[7:0] : cnt[7:0];

assign DAC_data = sin;

reg [10:0] knob;
reg [2:0] quadAr, quadBr;

always @(posedge clk) begin
  phase_acc <= phase_acc + knob;
  quadAr <= {quadAr[1:0], quadA};
  quadBr <= {quadBr[1:0], quadB};
  if(quadAr[2] ^ quadAr[1] ^ quadBr[2] ^ quadBr[1])
  begin
    if(quadAr[2] ^ quadBr[1])
    begin
      if(~&knob) knob <= knob + 1;
    end
    else
    begin
      if(|knob) knob <= knob - 1;
    end
  end
end

reg [7:0] sin;

sine s (.clk(clk), .idx(phase_acc[BITS-1:BITS-8]), .val(sin));

endmodule

