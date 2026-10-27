`timescale 1ns/1ps
module tb_braille_image;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,enable=1,bv=0,be=0;reg[7:0]bd;
 wire active,valid,error;wire[4:0]count;wire[95:0]cells;
 integer results=0,errors=0,gray_pos=0;
 braille_image_rx #(.CLK_HZ(10000)) dut(.clk(clk),.rst_n(rst_n),.enable(enable),
  .byte_valid(bv),.byte_error(be),.byte_data(bd),.active(active),
  .result_valid(valid),.frame_error(error),.cell_count(count),.cells(cells));
 always @(posedge clk)begin if(valid)results=results+1;if(error)errors=errors+1;end
 always @(posedge clk)begin
  if(dut.core_start)gray_pos=0;
  else if(dut.core.gray_valid)begin
   if(gray_pos==0&&dut.core.gray_debug!=149)$fatal(1,"green gray must be 149");
   if(gray_pos==1&&dut.core.gray_debug!=28)$fatal(1,"blue gray must be 28");
   gray_pos=gray_pos+1;
  end
 end
 task send;input[7:0]v;begin
  @(negedge clk);bd=v;bv=1;@(negedge clk);bv=0;repeat(12)@(negedge clk);
 end endtask
 integer checksum;
 task header;input integer n;begin
  send("I");send("M");send("G");send("1");send(n);checksum=n;
 end endtask
 // Independently synthesize black filled discs, noise and distinct RGB pixels.
 task cell_image;input[5:0]mask;input integer noise;
  integer x,y,i,dx,dy,cx,cy;reg dark;reg[15:0]pix;
  begin
   for(y=0;y<96;y=y+1)for(x=0;x<64;x=x+1)begin
    dark=0;
    for(i=0;i<6;i=i+1)begin
     cx=(i<3)?16:48;cy=16+(i%3)*32;dx=x-cx;dy=y-cy;
     if(mask[i]&&dx*dx+dy*dy<=25)dark=1;
    end
    if(noise&&x==16&&y==48)dark=1;
    pix=dark?16'h0000:16'hffff;
    // A green pixel has gray149 and a blue pixel gray28. No ROI contamination.
    if(x==0&&y==0)pix=16'h07e0;
    if(x==1&&y==0)pix=16'h001f;
    send(pix[15:8]);send(pix[7:0]);checksum=(checksum+pix[15:8]+pix[7:0])&65535;
   end
  end
 endtask
 task tail;input integer corrupt;begin
  send(checksum>>8);send((checksum&255)^corrupt);send(13);send(10);
  repeat(40)@(negedge clk);
 end endtask
 integer prior;
 initial begin
  #100;rst_n=1;
  header(3);cell_image(6'h03,1);cell_image(6'h2e,0);cell_image(6'h35,0);tail(0);
  if(results!=1||count!=3||cells[17:0]!={6'h35,6'h2e,6'h03})
   $fatal(1,"cup image mask incorrect: %h count%0d results%0d",cells,count,results);
  header(1);cell_image(0,1);tail(0);
  if(results!=2||cells!=0)$fatal(1,"white image / isolated noise");
  header(1);cell_image(63,0);tail(1);
  if(results!=2||errors==0)$fatal(1,"bad checksum accepted");
  prior=errors;header(1);send(0);repeat(1100)@(negedge clk);
  if(active||errors<=prior)$fatal(1,"truncated image timeout");
  header(1);enable=0;repeat(3)@(negedge clk);enable=1;
  if(active)$fatal(1,"exit abort");
  header(1);cell_image(63,0);tail(0);
  if(results!=3||cells[5:0]!=63)$fatal(1,"restart / all dots");
  $display("PASS image: RGB565, grayscale, mean filter, six ROIs, cup sequence, noise, checksum, timeout, abort");$finish;
 end
 initial begin #1000000000;$fatal(1,"timeout");end
endmodule
