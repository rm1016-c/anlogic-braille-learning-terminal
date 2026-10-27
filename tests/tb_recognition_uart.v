`timescale 1ns/1ps
module tb_recognition_uart;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,rx=1;wire valid;wire[2:0]id;
 integer count=0,bytes=0;wire byte_valid;
 recognition_uart #(.CLK_HZ(1000000),.BAUD(100000)) dut(
 .clk(clk),.rst_n(rst_n),.rx(rx),.target_valid(valid),.target_id(id),.byte_valid(byte_valid));
 always@(posedge clk)if(byte_valid)bytes=bytes+1;
 always@(posedge clk)if(valid)begin
  count=count+1;if(id!=4)$fatal(1,"wrong target");
 end
 task byte_tx;input[7:0]b;integer k;begin
 @(negedge clk);rx=0;repeat(10)@(negedge clk);
 for(k=0;k<8;k=k+1)begin rx=b[k];repeat(10)@(negedge clk);end
 rx=1;repeat(10)@(negedge clk);
 end endtask
 initial begin
 #50;rst_n=1;repeat(10)@(negedge clk);
 byte_tx(8'hAA);byte_tx(4);byte_tx(8'h55);repeat(20)@(negedge clk);
 if(count!=1)$fatal(1,"valid frame missing");
 byte_tx(8'hAA);byte_tx(0);byte_tx(8'h55);
 byte_tx(8'hAA);byte_tx(4);byte_tx(8'h54);repeat(20)@(negedge clk);
 if(count!=1)$fatal(1,"invalid frame accepted");
 if(bytes!=9)$fatal(1,"byte diagnostic pulse count %d",bytes);
 $display("PASS UART: valid and invalid frame filtering");$finish;
 end
endmodule
