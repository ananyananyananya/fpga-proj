module payment_fsm(
input wire clk, rst, pay_start,
input wire [7:0] item_price,
input wire cancel,
input wire [1:0] pay_mode,
input wire coin_insert,
input wire [7:0] coin_value, rfid_balance,
output reg [7:0] balance, change_due,
output reg pay_ok, pay_cancel, dispensing,
output wire [2:0] state_out
);

localparam IDLE=3'd0;
localparam COLLECTING=3'd1;
localparam VERIFYING=3'd2;
localparam DISPENSING=3'd3;
localparam CHANGE=3'd4;
localparam DONE=3'd5;
localparam ERROR=3'd6;

localparam TIMEOUT_LIMIT=16'd50000;

reg [15:0] timeout_cnt;
reg [2:0] state,next_state;

assign state_out=state;

always @(posedge clk or posedge rst) begin
if(rst)
state<=IDLE;
else
state<=next_state;
end

always @(posedge clk or posedge rst) begin
if(rst)
timeout_cnt<=0;
else if(state==COLLECTING)
timeout_cnt<=(coin_insert)?16'd0:timeout_cnt+1;
else
timeout_cnt<=0;
end

always @(posedge clk or posedge rst) begin
if(rst) begin
balance<=8'd0;
end else begin
case(state)
IDLE: balance<=8'd0;
COLLECTING: begin
if(pay_mode==2'b00) begin
if(coin_insert && (balance+coin_value<=8'd255))
balance<=balance+coin_value;
end else begin
balance<=rfid_balance;
end
end
DISPENSING: balance<=balance-item_price;
default: ;
endcase
end
end

always @(*) begin
next_state=state;
case(state)
IDLE:
if(pay_start)
next_state=COLLECTING;

COLLECTING: begin
if(cancel)
next_state=ERROR;
else if(timeout_cnt>=TIMEOUT_LIMIT && pay_mode==2'b00)
next_state=ERROR;
else if(pay_mode!=2'b00)
next_state=VERIFYING;
else if(balance>=item_price)
next_state=VERIFYING;
end

VERIFYING:
if(balance>=item_price)
next_state=DISPENSING;
else
next_state=ERROR;

DISPENSING:
next_state=CHANGE;

CHANGE:
next_state=DONE;

DONE:
next_state=IDLE;

ERROR:
next_state=IDLE;

default:
next_state=IDLE;
endcase
end

always @(posedge clk or posedge rst) begin
if(rst) begin
pay_ok<=1'b0;
pay_cancel<=1'b0;
dispensing<=1'b0;
change_due<=8'd0;
end else begin
pay_ok<=1'b0;
pay_cancel<=1'b0;
dispensing<=1'b0;

case(state)
DISPENSING: begin
dispensing<=1'b1;
change_due<=balance-item_price;
end
DONE: begin
pay_ok<=1'b1;
end
ERROR: begin
pay_cancel<=1'b1;
change_due<=balance;
end
default: ;
endcase
end
end

endmodule
