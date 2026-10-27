`timescale 1ns/1ps
module tb_uart_activity_diag;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,rx=1;wire seen;
 uart_activity_diag dut(.clk(clk),.rst_n(rst_n),.rx(rx),.edge_seen(seen));
 initial begin
 #20;rst_n=1;repeat(1100)@(negedge clk);
 if(seen)$fatal(1,"idle falsely triggered");
 rx=0;repeat(10)@(negedge clk);
 if(!seen)$fatal(1,"falling edge not detected");
 rx=1;repeat(10)@(negedge clk);
 if(!seen)$fatal(1,"latch not retained");
 rst_n=0;#20;rx=0;rst_n=1;repeat(1100)@(negedge clk);
 if(seen)$fatal(1,"reset/fill falsely triggered");
 rx=1;repeat(10)@(negedge clk);
 if(!seen)$fatal(1,"rising edge not detected");
 $display("PASS raw UART activity: idle, both edges, latch and reset");$finish;
 end
endmodule
