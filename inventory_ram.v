module inventory_ram(
input wire clk, a_we,
input wire [2:0] a_addr,
input wire [31:0] a_wdata,
output reg [31:0] a_rdata,
input wire [2:0] b_addr,
output reg [31:0] b_rdata
);

reg [31:0] mem[0:7];

integer i;
initial begin
mem[0]=32'h00_1E_64_0A;
mem[1]=32'h00_05_96_08;
mem[2]=32'h00_02_32_03;
mem[3]=32'h00_0F_78_0C;
mem[4]=32'h00_3C_B4_05;
mem[5]=32'h00_01_46_02;
mem[6]=32'h00_14_50_07;
mem[7]=32'h00_07_C8_06;
end

always @(posedge clk) begin
if(a_we)
mem[a_addr]<=a_wdata;
a_rdata<=mem[a_addr];
end

always @(posedge clk) begin
b_rdata<=mem[b_addr];
end

endmodule
