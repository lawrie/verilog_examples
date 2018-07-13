module PWM(input clk, input RxD_data_ready, input [7:0] RxD_data, output PWM_out);

reg [7:0] RxD_data_reg;
always @(posedge clk) if(RxD_data_ready) RxD_data_reg <= RxD_data;
////////////////////////////////////////////////////////////////////////////
reg [8:0] PWM_accumulator;
always @(posedge clk) PWM_accumulator <= PWM_accumulator[7:0] + RxD_data_reg;

assign PWM_out = PWM_accumulator[8];
endmodule
