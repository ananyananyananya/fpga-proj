module tx_fifo#(
parameter DEPTH=16,
parameter PTR_BITS=4,
parameter DATA_BITS=24
)(
input wire clk, rst, wr_en,
input wire [DATA_BITS-1:0] wr_data,
output wire full,
input wire rd_en,
output wire [DATA_BITS-1:0] rd_data,
output wire empty,
output wire [PTR_BITS:0] count
);

reg [DATA_BITS-1:0] mem[0:DEPTH-1];
reg [PTR_BITS:0] wr_ptr,rd_ptr;

assign count=wr_ptr-rd_ptr;
assign full=(count==DEPTH[PTR_BITS:0]);
assign empty=(count==0);
assign rd_data=mem[rd_ptr[PTR_BITS-1:0]];

always @(posedge clk or posedge rst) begin
if(rst) begin
wr_ptr<=0;
rd_ptr<=0;
end else begin
if(wr_en && !full) begin
mem[wr_ptr[PTR_BITS-1:0]]<=wr_data;
wr_ptr<=wr_ptr+1;
end
if(rd_en && !empty) begin
rd_ptr<=rd_ptr+1;
end
end
end

endmodule
