module SimpleDDS(clk, DAC_clk, DAC_data);
input clk;
output DAC_clk;
output [7:0] DAC_data;

assign DAC_clk = clk; // 100Mhz

// let's create a 16 bits free-running binary counter
reg [15:0] cnt;
always @(posedge clk) cnt <= cnt + 16'h1;

// and use it to generate the DAC signal output
wire cnt_tap = cnt[7];     // we take one bit out of the counter (here bit 7 = the 8th bit)
//assign DAC_data = {8{cnt_tap}};  
//assign DAC_data = cnt[7:0];   
//assign DAC_data = ~cnt[7:0];  
assign DAC_data = cnt[8] ? ~cnt[7:0] : cnt[7:0];

endmodule

