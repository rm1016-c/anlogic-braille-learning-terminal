`timescale 1ns/1ps
module tb_mode2_full_session;
 reg[5:0]question_id; wire[5:0]answer_a,answer_b;wire[7:0]question_audio;wire has_initial,valid;integer i;
 mode2_question_rom dut(.*);
 initial begin
  for(i=0;i<42;i=i+1)begin question_id=i;#1;if(!valid||question_audio!==111+i||answer_b==0)$fatal(1,"bad question %0d",i);if(i<41&&!has_initial)$fatal(1,"unexpected zero initial");end
  question_id=41;#1;if(has_initial||answer_a!=0||answer_b!=6'b010111)$fatal(1,"er encoding wrong");
  question_id=42;#1;if(valid)$fatal(1,"out of range accepted");
  $display("PASS full mode2 session: 42 staged questions and zero-initial entry verified");$finish;
 end
endmodule
