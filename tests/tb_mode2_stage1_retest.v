`timescale 1ns/1ps
module tb_mode2_stage1_retest;
 wire hold=1'b0,external_exit=1'b0;
 reg clk=0,rst_n=0,codec_ready=1,key_valid=0,audio_busy=0,audio_done=0;reg[5:0]key_id=0;
 wire audio_request,running,mode2_active,answer_stage_b,session_done;wire[7:0]audio_index;
 wire[5:0]question_id,answer_current;wire[2:0]current_stage,unlocked_stage;wire[1:0]practice_type;
 integer i;integer expected[0:9];
 always #5 clk=~clk;mode12_controller #(.MODE2_GAP_CYCLES(1))dut(.*);
 task press;input[5:0]id;begin@(negedge clk);key_id=id;key_valid=1;@(negedge clk);key_valid=0;end endtask
 task expect_audio;input[7:0]x;integer t;begin t=0;while(!audio_request&&t<100)begin@(negedge clk);t=t+1;end if(!audio_request||audio_index!==x)$fatal(1,"want %0d got %0d q=%0d",x,audio_index,question_id);end endtask
 task expect_question;integer t;begin t=0;while(!audio_request&&t<100)begin@(negedge clk);t=t+1;end if(!audio_request||audio_index<111||audio_index>125)$fatal(1,"question request missing: %0d",audio_index);end endtask
 task done_audio;begin@(negedge clk);audio_busy=1;@(negedge clk);audio_busy=0;audio_done=1;@(negedge clk);audio_done=0;end endtask
 task enter_mask;input[5:0]m;begin if(m[0])press(8);if(m[1])press(9);if(m[2])press(10);if(m[3])press(0);if(m[4])press(1);if(m[5])press(2);end endtask
 task answer_correct;begin
  done_audio();expect_audio(64);done_audio();enter_mask(dut.standard_a);press(3);expect_audio(65);done_audio();
  enter_mask(dut.standard_b);press(3);expect_audio(4);done_audio();
 end endtask
 task answer_wrong;begin
  done_audio();expect_audio(64);done_audio();press(3);expect_audio(65);done_audio();press(3);expect_audio(5);done_audio();
 end endtask
 initial begin
  expected[0]=2;expected[1]=5;expected[2]=0;expected[3]=1;expected[4]=3;
  expected[5]=4;expected[6]=6;expected[7]=7;expected[8]=8;expected[9]=9;
  repeat(3)@(negedge clk);rst_n=1;
  press(15);expect_audio(0);done_audio();press(7);expect_audio(2);done_audio();expect_audio(68);done_audio();expect_audio(74);done_audio();
  @(negedge clk);dut.wrong_mask=(42'b1<<2)|(42'b1<<5);
  press(4);expect_audio(75);done_audio();press(4);expect_audio(76);done_audio();press(3);

  // Two live wrong-set entries are selected first; the other eight are
  // deterministic rotating regular questions.  Eight correct means pass.
  for(i=0;i<10;i=i+1)begin
   expect_audio(111+expected[i]);
   if(i<8)answer_correct();else answer_wrong();
  end
  expect_audio(102);done_audio();expect_audio(105);done_audio();expect_audio(107);done_audio();
  if(unlocked_stage!==1)$fatal(1,"passing stage-1 retest did not unlock stage 2");
  if(!dut.wrong_mask[8]||!dut.wrong_mask[9])$fatal(1,"retest errors not added to wrong set");

  // A second retest with zero correct must report not passed.  The changed
  // wrong set and rotation may change questions, so only validate range/count.
  press(3);
  for(i=0;i<10;i=i+1)begin expect_question();answer_wrong();end
  expect_audio(102);done_audio();expect_audio(106);done_audio();
  if(unlocked_stage!==1)$fatal(1,"failed retest changed unlock state");
  press(12);expect_audio(69);done_audio();expect_audio(74);done_audio();
  if(current_stage!==1)$fatal(1,"newly unlocked stage 2 is not selectable");
  $display("PASS stage1 retest: dynamic mix, 8-of-10 threshold and progressive unlock verified");$finish;
 end
endmodule
