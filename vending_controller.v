module vending_controller(
input wire clk, rst,
input wire [2:0] product_sel,
input wire confirm, cancel,
input wire [1:0] pay_mode,
input wire coin_insert,
input wire [7:0] coin_value, rfid_balance,
output reg [7:0] display_price, display_balance, display_change, low_stock_leds,
output reg dispense_led, error_led,
output wire [3:0] ctrl_state_out,
output reg ram_we,
output reg [2:0] ram_addr,
output reg [31:0] ram_wdata,
input wire [31:0] ram_rdata,
output reg [7:0] pu_base_price, pu_days_expiry, pu_demand,
input wire [7:0] pu_final_price,
input wire pu_is_discounted,
output reg pay_start,
input wire pay_ok, pay_cancel, pay_dispensing,
input wire [7:0] pay_balance, pay_change,
output reg fifo_wr_en,
output reg [23:0] fifo_wr_data,
input wire fifo_full
);

localparam IDLE=4'd0;
localparam LOOKUP=4'd1;
localparam PRICING=4'd2;
localparam AWAIT_PAY=4'd3;
localparam DISPENSE=4'd4;
localparam LOW_STOCK=4'd5;
localparam RETURN_CHG=4'd6;
localparam ERROR_ST=4'd7;

localparam STOCK_THRESHOLD=8'd3;

reg [3:0] state;
reg [2:0] selected_product;
reg [31:0] product_data;
reg [7:0] latched_price;
reg [7:0] current_stock;
reg [7:0] current_demand;
reg [7:0] current_expiry;

assign ctrl_state_out=state;

reg confirm_prev;
wire confirm_rise=confirm && !confirm_prev;

always @(posedge clk or posedge rst)
confirm_prev<=rst?1'b0:confirm;

always @(posedge clk or posedge rst) begin
if(rst) begin
state<=IDLE;
ram_we<=1'b0;
ram_addr<=3'd0;
ram_wdata<=32'd0;
pay_start<=1'b0;
fifo_wr_en<=1'b0;
fifo_wr_data<=24'd0;
display_price<=8'd0;
display_balance<=8'd0;
display_change<=8'd0;
low_stock_leds<=8'd0;
dispense_led<=1'b0;
error_led<=1'b0;
pu_base_price<=8'd0;
pu_days_expiry<=8'd0;
pu_demand<=8'd0;
latched_price<=8'd0;
selected_product<=3'd0;
end else begin
ram_we<=1'b0;
pay_start<=1'b0;
fifo_wr_en<=1'b0;
dispense_led<=1'b0;

case(state)

IDLE: begin
error_led<=1'b0;
display_change<=8'd0;
if(confirm_rise) begin
selected_product<=product_sel;
ram_addr<=product_sel;
state<=LOOKUP;
end
end

LOOKUP: begin
ram_addr<=selected_product;
state<=PRICING;
end

PRICING: begin
product_data<=ram_rdata;
current_stock<=ram_rdata[7:0];
current_demand<=ram_rdata[31:24];
current_expiry<=ram_rdata[23:16];
pu_base_price<=ram_rdata[15:8];
pu_days_expiry<=ram_rdata[23:16];
pu_demand<=ram_rdata[31:24];
if(ram_rdata[7:0]==8'd0) begin
error_led<=1'b1;
state<=ERROR_ST;
end else begin
state<=AWAIT_PAY;
end
end

AWAIT_PAY: begin
latched_price<=pu_final_price;
display_price<=pu_final_price;
display_balance<=pay_balance;
pay_start<=1'b1;
if(cancel) begin
state<=ERROR_ST;
end else if(pay_ok) begin
state<=DISPENSE;
end else if(pay_cancel) begin
error_led<=1'b1;
state<=ERROR_ST;
end
end

DISPENSE: begin
dispense_led<=1'b1;
ram_we<=1'b1;
ram_addr<=selected_product;
ram_wdata<={current_demand+8'd1,current_expiry,ram_rdata[15:8],current_stock-8'd1};

if(!fifo_full) begin
fifo_wr_en<=1'b1;
fifo_wr_data<={selected_product,latched_price,pay_balance,5'd0};
end

display_change<=pay_change;
state<=LOW_STOCK;
end

LOW_STOCK: begin
if((current_stock-8'd1)<=STOCK_THRESHOLD)
low_stock_leds[selected_product]<=1'b1;
state<=RETURN_CHG;
end

RETURN_CHG: begin
state<=IDLE;
end

ERROR_ST: begin
error_led<=1'b1;
if(confirm_rise)
state<=IDLE;
end

default: state<=IDLE;

endcase
end
end

always @(*) begin
display_balance=pay_balance;
end

endmodule
