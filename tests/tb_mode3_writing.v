`timescale 1ns/1ps
module tb_mode3_writing;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,rx=1,kv=0;reg[5:0]key=0;
 wire tv,bv,be,rv,wait_brl,start,busy,done,tx,request,active;
 wire[2:0]tid;wire[7:0]bd,idx;wire[4:0]count;wire[95:0]cells;
 reg audio_busy=0,audio_done=0;integer remaining=0,n=0,hello_bytes=0;
 reg[7:0]played[0:255];wire tx_bv;wire[7:0]tx_bd;
 recognition_uart #(.CLK_HZ(1000000),.BAUD(100000)) rx_inst(
  .clk(clk),.rst_n(rst_n),.rx(rx),.target_valid(tv),.target_id(tid),
  .byte_valid(bv),.byte_data(bd),.byte_error(be));
 braille_text_rx #(.CLK_HZ(1000000)) parser(.clk(clk),.rst_n(rst_n),.enable(wait_brl),
  .byte_valid(bv),.byte_error(be),.byte_data(bd),.result_valid(rv),.cell_count(count),.cells(cells));
 uart_hello_tx #(.CLK_HZ(1000000),.BAUD(100000)) sender(
  .clk(clk),.rst_n(rst_n),.start(start),.tx(tx),.busy(busy),.done(done));
 recognition_uart #(.CLK_HZ(1000000),.BAUD(100000)) monitor(
  .clk(clk),.rst_n(rst_n),.rx(tx),.byte_valid(tx_bv),.byte_data(tx_bd));
 mode3_uart_bridge dut(.clk(clk),.rst_n(rst_n),.running(1'b1),.mode2_active(1'b1),
  .key_valid(kv),.key_id(key),.audio_busy(audio_busy),.audio_done(audio_done),
  .old_request(1'b0),.old_index(8'd0),.target_valid(tv),.target_id(tid),
  .result_valid(rv),.result_count(count),.result_cells(cells),.tx_busy(busy),.tx_done(done),
  .hello_start(start),.writing_wait(wait_brl),.request(request),.audio_index(idx),.mode3_active(active));
 always @(posedge clk)begin
  audio_done<=0;
  if(request)begin
   if(audio_busy)$fatal(1,"overlapping audio");
   played[n]=idx;n=n+1;audio_busy<=1;remaining<=20;
  end else if(remaining>0)begin
   remaining<=remaining-1;
   if(remaining==1)begin audio_busy<=0;audio_done<=1;end
  end
  if(tx_bv)begin
   case(hello_bytes%5)
    0:if(tx_bd!="h")$fatal(1,"hello h");
    1:if(tx_bd!="e")$fatal(1,"hello e");
    2,3:if(tx_bd!="l")$fatal(1,"hello l");
    4:if(tx_bd!="o")$fatal(1,"hello o");
   endcase
   hello_bytes=hello_bytes+1;
  end
 end
 task keypress;input[5:0]k;begin @(negedge clk);key=k;kv=1;@(negedge clk);kv=0;end endtask
 task byte_send;input[7:0]b;integer i;begin
  @(negedge clk);rx=0;repeat(10)@(negedge clk);
  for(i=0;i<8;i=i+1)begin rx=b[i];repeat(10)@(negedge clk);end
  rx=1;repeat(12)@(negedge clk);
 end endtask
 task line_send;input[1023:0]s;integer i;begin
  for(i=127;i>=0;i=i-1)if(s[i*8+:8]!=0)byte_send(s[i*8+:8]);
 end endtask
 task object_send;input[7:0]id;begin byte_send(8'haa);byte_send(id);byte_send(8'h55);repeat(100)@(negedge clk);end endtask
 task start_writing;begin keypress(3);repeat(700)@(negedge clk);if(!wait_brl)$fatal(1,"not waiting for braille");end endtask
 integer before_n,h,t;
 initial begin
  #100;rst_n=1;keypress(7);repeat(100)@(negedge clk);
  if(n!=2||played[0]!=167||played[1]!=168)$fatal(1,"entry");
  object_send(4);if(played[n-1]!=156)$fatal(1,"cup");
  start_writing();if(hello_bytes!=5)$fatal(1,"first hello");
  before_n=n;
  line_send("BRL,ERROR,END\n");line_send("BRL,3,21,2346,1356,END\n");
  line_send("BRL,2,12,2346,1356,END\n");
  line_send("BRL,3,12,2346,1356,ENDx\n");
  if(n!=before_n||!wait_brl)$fatal(1,"malformed frame judged");
  object_send(5); // Incoming new objects cannot change the locked cup answer.
  line_send("BRL,3,12,2346,1356,END");byte_send(13);byte_send(10);repeat(700)@(negedge clk);
  if(played[n-1]!=4||hello_bytes!=10||wait_brl)begin
   $display("debug state=%d last=%d hello=%d wait=%b actual=%h expected=%h count=%d/%d",dut.state,played[n-1],hello_bytes,wait_brl,dut.actual_cells,dut.expected_cells,dut.actual_count,dut.expected_count);
   $fatal(1,"correct result/return hello");end
  before_n=n;line_send("BRL,3,12,2346,1356,END\n");repeat(100)@(negedge clk);
  if(n!=before_n||hello_bytes!=10)$fatal(1,"duplicate accepted");
  object_send(4);start_writing();before_n=n;
  line_send("BRL,2,12,2346,END\n");repeat(2000)@(negedge clk);
  if(played[before_n]!=5||played[before_n+1]!=160||played[n-1]!=171)$fatal(1,"wrong/correction");
  if(hello_bytes!=20)$fatal(1,"wrong hello count");
  for(t=1;t<=7;t=t+1)begin
   object_send(t);start_writing();
   case(t)
    1:line_send("BRL,2,125,256,END\n");
    2:line_send("BRL,2,123,346,END\n");
    3:line_send("BRL,2,123,1236,END\n");
    4:line_send("BRL,3,12,2346,1356,END\n");
    5:line_send("BRL,4,1234,16,1245,135,END\n");
    6:line_send("BRL,3,12345,3456,1356,END\n");
    7:line_send("BRL,4,156,136,12,345,END\n");
   endcase
   repeat(700)@(negedge clk);
   if(played[n-1]!=4)$fatal(1,"standard target %d failed",t);
  end
  object_send(4);start_writing();h=hello_bytes;keypress(7);repeat(800)@(negedge clk);
  if(active||hello_bytes!=h+5)$fatal(1,"exit must restore object mode");
  $display("PASS mode3 writing: real UART, hello bytes, strict text, locked cup, correct/wrong, duplicates, exit");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
