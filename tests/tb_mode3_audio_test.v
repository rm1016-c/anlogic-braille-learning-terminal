`timescale 1ns/1ps
module tb_mode3_audio_test;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,key_valid=0,audio_busy=0,audio_done=0;
 reg[5:0]key_id=0;
 wire request; wire[7:0]idx;
 mode12_controller #(.MODE3_AUDIO_TEST(1)) dut(
 .clk(clk),.rst_n(rst_n),.codec_ready(1'b1),.key_valid(key_valid),
 .key_id(key_id),.audio_busy(audio_busy),.audio_done(audio_done),
 .audio_request(request),.audio_index(idx));
 task key; input[5:0]id; begin
 @(negedge clk);key_valid=1;key_id=id;
 @(negedge clk);key_valid=0;
 end endtask
 task done; begin
 @(negedge clk);audio_done=1;
 @(negedge clk);audio_done=0;
 end endtask
 integer i;
 initial begin
 #20;rst_n=1;key(15);done();
 for(i=153;i<=171;i=i+1)begin
 key(5);if(!request||idx!=i)$fatal(1,"wrong index %d expected %d",idx,i);
 audio_busy=1;key(5);if(request)$fatal(1,"busy request");
 audio_busy=0;done();
 end
 key(5);if(idx!=153)$fatal(1,"wrap failed");done();
 rst_n=0;#20;rst_n=1;key(15);done();key(5);
 if(idx!=153)$fatal(1,"reset failed");
 $display("PASS mode3 audio test: 19 indices, busy rejection, wrap and reset");$finish;
 end
endmodule
