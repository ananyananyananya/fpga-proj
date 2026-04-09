`timescale 1ns/1ps
module tb_smart_vending;
reg clk = 0;
always #10 clk = ~clk;
reg rst;
reg [2:0] product_sel;
reg confirm, cancel;
reg [1:0] pay_mode;
reg coin_insert;
reg [7:0] coin_value, rfid_balance;
reg fifo_rd_en;
wire [7:0] display_price, display_balance, display_change, low_stock_leds;
wire dispense_led, error_led;
wire [3:0] ctrl_state;
wire [2:0] pay_state;
wire fifo_empty;
wire [23:0] fifo_rd_data;
wire is_discounted;

smart_vending_top dut(
.clk(clk),
.rst(rst),
.product_sel(product_sel),
.confirm(confirm),
.cancel(cancel),
.pay_mode(pay_mode),
.coin_insert(coin_insert),
.coin_value(coin_value),
.rfid_balance(rfid_balance),
.display_price(display_price),
.display_balance(display_balance),
.display_change(display_change),
.low_stock_leds(low_stock_leds),
.dispense_led(dispense_led),
.error_led(error_led),
.ctrl_state(ctrl_state),
.pay_state(pay_state),
.fifo_empty(fifo_empty),
.fifo_rd_data(fifo_rd_data),
.fifo_rd_en(fifo_rd_en),
.is_discounted(is_discounted)
);

task do_reset;
begin
rst=1;
confirm=0;
cancel=0;
coin_insert=0;
coin_value=8'd0;
rfid_balance=8'd0;
pay_mode=2'b00;
product_sel=3'd0;
fifo_rd_en=0;
repeat(4) @(posedge clk);
rst=0;
repeat(2) @(posedge clk);
end
endtask

task select_product;
input [2:0] pid;
begin
product_sel=pid;
@(posedge clk);
confirm=1;
@(posedge clk);
confirm=0;
@(posedge clk);
end
endtask

task insert_coin;
input [7:0] denomination;
begin
coin_value=denomination;
coin_insert=1;
@(posedge clk);
coin_insert=0;
@(posedge clk);
end
endtask

task wait_for_ctrl_state;
input [3:0] target;
input integer timeout;
integer i;
begin
for(i=0;i<timeout;i=i+1)begin
@(posedge clk);
if(ctrl_state==target)begin
i=timeout;
end
end
end
endtask

task drain_fifo;
integer j;
begin
$display("\n--- FIFO Transaction Log ---");
j=0;
while(!fifo_empty && j<20)begin
fifo_rd_en=1;
@(posedge clk);
fifo_rd_en=0;
@(posedge clk);
$display("  [%0d] product=%0d  price=%0d cents  balance_rem=%0d cents",
j,
fifo_rd_data[23:21],
fifo_rd_data[20:13],
fifo_rd_data[12:5]);
j=j+1;
end
$display("----------------------------\n");
end
endtask

function [79:0] ctrl_state_name;
input [3:0] s;
case(s)
4'd0: ctrl_state_name="IDLE      ";
4'd1: ctrl_state_name="LOOKUP    ";
4'd2: ctrl_state_name="PRICING   ";
4'd3: ctrl_state_name="AWAIT_PAY ";
4'd4: ctrl_state_name="DISPENSE  ";
4'd5: ctrl_state_name="LOW_STOCK ";
4'd6: ctrl_state_name="RETURN_CHG";
4'd7: ctrl_state_name="ERROR     ";
default: ctrl_state_name="UNKNOWN   ";
endcase
endfunction

reg [3:0] prev_ctrl_state;
always @(posedge clk) begin
if(ctrl_state!==prev_ctrl_state)begin
$display("[%0t ns] CTRL_STATE -> %s | price=%0d balance=%0d change=%0d discounted=%b",
$time,ctrl_state_name(ctrl_state),
display_price,display_balance,display_change,is_discounted);
prev_ctrl_state=ctrl_state;
end
end

initial begin
$dumpfile("vending_sim.vcd");
$dumpvars(0,tb_smart_vending);

$display("========================================");
$display(" Smart Vending Machine ? ModelSim Test ");
$display("========================================\n");

do_reset;

$display("--- TEST 1: Coin payment, Product 0 (base price 100c) ---");
pay_mode=2'b00;
select_product(3'd0);
wait_for_ctrl_state(4'd3,20);
$display("  Product selected. Displayed price = %0d cents",display_price);

insert_coin(8'd50);
insert_coin(8'd50);
insert_coin(8'd25);

wait_for_ctrl_state(4'd0,50);
$display("  DONE. Change = %0d cents. Dispense LED = %b",display_change,dispense_led);
repeat(5) @(posedge clk);

$display("\n--- TEST 2: RFID payment, Product 1 (5 days expiry ? discounted) ---");
pay_mode=2'b01;
rfid_balance=8'd200;
select_product(3'd1);

wait_for_ctrl_state(4'd3,20);
$display("  Displayed price = %0d cents (discounted = %b)",display_price,is_discounted);

wait_for_ctrl_state(4'd0,50);
$display("  DONE. Change = %0d cents",display_change);
repeat(5) @(posedge clk);

$display("\n--- TEST 3: Low stock alert, Product 2 (stock=3) ---");
pay_mode=2'b01;
rfid_balance=8'd100;
select_product(3'd2);

wait_for_ctrl_state(4'd3,20);
$display("  Product 2 price = %0d cents",display_price);
wait_for_ctrl_state(4'd0,50);
$display("  After purchase: low_stock_leds = %b (bit 2 should be 1)",low_stock_leds);
repeat(5) @(posedge clk);

$display("\n--- TEST 4: Out-of-stock detection for Product 5 ---");
pay_mode=2'b01;
rfid_balance=8'd100;

select_product(3'd5);
wait_for_ctrl_state(4'd3,20);
wait_for_ctrl_state(4'd0,50);
$display("  First purchase done. error_led = %b",error_led);
repeat(3) @(posedge clk);

select_product(3'd5);
wait_for_ctrl_state(4'd3,20);
wait_for_ctrl_state(4'd0,50);
$display("  Second purchase done.");
repeat(3) @(posedge clk);

select_product(3'd5);
wait_for_ctrl_state(4'd7,20);
$display("  Third attempt: OUT OF STOCK. error_led = %b",error_led);

confirm=1; @(posedge clk); confirm=0;
wait_for_ctrl_state(4'd0,20);
repeat(5) @(posedge clk);

$display("\n--- TEST 5: Cancel during coin collection ---");
pay_mode=2'b00;
select_product(3'd3);
wait_for_ctrl_state(4'd3,20);

insert_coin(8'd25);
@(posedge clk);
cancel=1; @(posedge clk); cancel=0;
wait_for_ctrl_state(4'd0,50);
$display("  Cancel accepted. error_led = %b, refund (change) = %0d",error_led,display_change);

confirm=1; @(posedge clk); confirm=0;
repeat(5) @(posedge clk);

$display("\n--- TEST 6: FIFO transaction log ---");
drain_fifo;

$display("========================================");
$display(" All tests complete.");
$display("========================================");
$finish;
end
endmodule
