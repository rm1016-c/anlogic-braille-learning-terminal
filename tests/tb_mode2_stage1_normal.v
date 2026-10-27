`timescale 1ns/1ps
module tb_mode2_stage1_normal;
 wire hold=1'b0,external_exit=1'b0;
 reg clk=0,rst_n=0,codec_ready=1,key_valid=0,audio_busy=0,audio_done=0;
 reg[5:0]key_id=0; integer i;
 wire audio_request,running,mode2_active,answer_stage_b,session_done;
 wire[7:0]audio_index; wire[5:0]question_id,answer_current;
 wire[2:0]current_stage,unlocked_stage; wire[1:0]practice_type;
 always #5 clk=~clk;
 mode12_controller #(.MODE2_GAP_CYCLES(1))dut(.*);
 task press;input[5:0]id;begin@(negedge clk);key_id=id;key_valid=1;@(negedge clk);key_valid=0;end endtask
 task expect_audio;input[7:0]x;integer t;begin t=0;while(!audio_request&&t<80)begin@(negedge clk);t=t+1;end if(!audio_request||audio_index!==x)$fatal(1,"want %0d got %0d at q%0d",x,audio_index,question_id);end endtask
 task done_audio;begin@(negedge clk);audio_busy=1;@(negedge clk);audio_busy=0;audio_done=1;@(negedge clk);audio_done=0;end endtask
 task enter_mask;input[5:0]m;begin
  if(m[0])press(8);if(m[1])press(9);if(m[2])press(10);
  if(m[3])press(0);if(m[4])press(1);if(m[5])press(2);
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  press(15);expect_audio(0);done_audio();
  press(7);expect_audio(2);done_audio();expect_audio(68);done_audio();expect_audio(74);done_audio();

  // Question 0: submit no points for either symbol.  S4 must treat each as
  // 000000, advance to the next symbol/judgement, and never play SYS_EMPTY.
  press(3);expect_audio(111);done_audio();expect_audio(64);done_audio();
  press(3);expect_audio(65);done_audio();
  press(3);expect_audio(5);done_audio();
  expect_audio(112);

  // Answer questions 1..14 correctly, then verify stage 1 wraps to question 0.
  for(i=1;i<15;i=i+1)begin
   if(i!=1)expect_audio(111+i);
   done_audio();expect_audio(64);done_audio();
   enter_mask(dut.standard_a);press(3);expect_audio(65);done_audio();
   enter_mask(dut.standard_b);press(3);expect_audio(4);done_audio();
  end
  expect_audio(111);
  if(question_id!==0||practice_type!==0||current_stage!==0)$fatal(1,"stage 1 did not wrap in normal mode");
  if(!dut.wrong_mask[0])$fatal(1,"wrong question was not recorded");
  $display("PASS stage1 normal: wrong-only feedback, 15 questions and wrap verified");
  $finish;
 end
endmodule
