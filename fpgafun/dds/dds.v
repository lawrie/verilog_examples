module dds(
  input clk, 
  output DAC_clk, 
  input quadA,
  input quadB,
  input button,
  output [3:0] led,
  output[7:0] DAC_data
);

localparam BITS = 24;

assign DAC_clk = clk; // 100Mhz
assign led = wave_type;

wire button_pressed;
debouncer db(.clk(clk), .button(button), .trans_up(button_pressed));

reg [BITS:0] phase_acc;
reg [2:0] wave_type;

reg [10:0] knob;
reg [2:0] quadAr, quadBr;

always @(posedge clk) begin
  if (button_pressed) begin
    if (wave_type == 4) wave_type <= 0;
    else wave_type <= wave_type + 1;
  end
  phase_acc <= phase_acc + knob;
  quadAr <= {quadAr[1:0], quadA};
  quadBr <= {quadBr[1:0], quadB};
  if(quadAr[2] ^ quadAr[1] ^ quadBr[2] ^ quadBr[1]) begin
    if(quadAr[2] ^ quadBr[1]) begin
      if(~&knob) knob <= knob + 1;
    end else begin
      if(|knob) knob <= knob - 1;
    end
  end
  case (wave_type) 
    0: DAC_data <= sin;
    1: DAC_data <= phase_acc[BITS-1:BITS-8] < 128 ? 0 : 255;
    2: DAC_data <= ~phase_acc[BITS-1:BITS-8];
    3: DAC_data <= phase_acc[BITS-1:BITS-8];
    4: DAC_data <= phase_acc[BITS] ? phase_acc[BITS-1:BITS-8] : ~phase_acc[BITS-1:BITS-8];
  endcase 
end

reg [7:0] sin;

sine s (.clk(clk), .idx(phase_acc[BITS-1:BITS-8]), .val(sin));

endmodule

