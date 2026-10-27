`timescale 1ns/1ps
module tb_uart_mode3_pipeline;
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,rx=1,key_valid=0;reg[5:0]key_id=0;
 reg busy=0,done=0;integer timer=0,n=0;
 reg[7:0]played[0:63];reg[7:0]expected[0:15];integer base;
 reg injected_valid=0;reg[2:0]injected_id=0;
 wire tv;wire[2:0]tid;wire request;wire[7:0]idx;wire active;
 recognition_uart uart(.clk(clk),.rst_n(rst_n),.rx(rx),.target_valid(tv),.target_id(tid));
 mode3_uart_bridge bridge(.clk(clk),.rst_n(rst_n),.running(1'b1),.mode2_active(1'b1),
 .key_valid(key_valid),.key_id(key_id),.audio_busy(busy),.audio_done(done),
 .old_request(1'b0),.old_index(8'd0),.target_valid(tv||injected_valid),.target_id(injected_valid?injected_id:tid),
 .request(request),.audio_index(idx),.mode3_active(active));
 always@(posedge clk)begin
  done<=0;
  if(request)begin
   if(busy)$fatal(1,"request while busy");
   played[n]=idx;n=n+1;busy<=1;timer<=100;
  end else if(timer>1)timer<=timer-1;
  else if(timer==1)begin timer<=0;busy<=0;done<=1;end
 end
 task tx;input[7:0]b;integer k;begin
 @(negedge clk);rx=0;#8680;
 for(k=0;k<8;k=k+1)begin rx=b[k];#8680;end
 rx=1;#8680;
 end endtask
 task frame;input[7:0]id;begin tx(8'hAA);tx(id);tx(8'h55);#10000;end endtask
 integer j;
 initial begin
 #100;rst_n=1;repeat(10)@(negedge clk);
 key_id=7;key_valid=1;@(negedge clk);key_valid=0;#10000;
 if(n!=2||played[0]!=167||played[1]!=168)$fatal(1,"mode3 entry prompts");
 for(j=1;j<=7;j=j+1)begin frame(j);if(n!=j+2||played[n-1]!=152+j)$fatal(1,"target %d missing",j);end
 frame(7);if(n!=9)$fatal(1,"duplicate played");
 frame(0);frame(8);if(n!=9)$fatal(1,"invalid played");
 frame(4);if(n!=10||played[9]!=156)$fatal(1,"cup replay missing");
 expected[0]=160;expected[1]=87;expected[2]=89;expected[3]=90;
 expected[4]=88;expected[5]=90;expected[6]=91;expected[7]=92;expected[8]=94;
 expected[9]=161;expected[10]=87;expected[11]=89;expected[12]=91;
 expected[13]=93;expected[14]=94;expected[15]=171;
 base=n;
 @(negedge clk);key_id=5;key_valid=1;@(negedge clk);key_valid=0;
 wait(n>base);@(negedge clk);injected_id=5;injected_valid=1;
 @(negedge clk);injected_valid=0;
 #100000;
 if(n!=base+17)$fatal(1,"learning/queued target count %d",n-base);
 for(j=0;j<16;j=j+1)if(played[base+j]!=expected[j])$fatal(1,"learning item %d",j);
 if(played[base+16]!=157)$fatal(1,"latest target not resumed after learning");
 // Exit and re-enter clears the learned/current target.
 @(negedge clk);key_id=7;key_valid=1;@(negedge clk);key_valid=0;#10000;
 @(negedge clk);key_valid=1;@(negedge clk);key_valid=0;#10000;
 base=n;@(negedge clk);key_id=5;key_valid=1;@(negedge clk);key_valid=0;#10000;
 if(n!=base+1||played[base]!=170)$fatal(1,"no target prompt missing");
 $display("PASS mode3 learning: cup/zi point order, locked target, queued recognition, no target");
 $display("PASS UART mode3 pipeline: 50MHz/115200, 7 targets, duplicate and invalid filtering");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
