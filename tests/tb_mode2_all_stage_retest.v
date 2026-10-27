`timescale 1ns/1ps
module tb_mode2_all_stage_retest;
 wire hold=1'b0,external_exit=1'b0;
 reg clk=0,rst_n=0,codec_ready=1,key_valid=0,audio_busy=0,audio_done=0;reg[5:0]key_id=0;
 wire audio_request,running,mode2_active,answer_stage_b,session_done;wire[7:0]audio_index;
 wire[5:0]question_id,answer_current;wire[2:0]current_stage,unlocked_stage;wire[1:0]practice_type;
 integer i;
 always #5 clk=~clk;
 mode12_controller #(.MODE2_GAP_CYCLES(1),.INITIAL_UNLOCKED_STAGE(5))dut(.*);
 task press;input[5:0]id;begin@(negedge clk);key_id=id;key_valid=1;@(negedge clk);key_valid=0;end endtask
 task expect_audio;input[7:0]x;integer t;begin t=0;while(!audio_request&&t<200)begin@(negedge clk);t=t+1;end if(!audio_request||audio_index!==x)$fatal(1,"want %0d got %0d q=%0d stage=%0d",x,audio_index,question_id,current_stage);end endtask
 task done_audio;begin@(negedge clk);audio_busy=1;@(negedge clk);audio_busy=0;audio_done=1;@(negedge clk);audio_done=0;end endtask
 task answer_zero_wrong;begin
  done_audio();
  if(dut.has_initial)begin expect_audio(64);done_audio();press(3);expect_audio(65);done_audio();press(3);end
  else begin expect_audio(80);done_audio();press(3);end
  expect_audio(5);done_audio();
 end endtask
 task select_retest;begin
  press(4);expect_audio(75);done_audio();press(4);expect_audio(76);done_audio();
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  if(unlocked_stage!==5)$fatal(1,"validation image did not expose six stages");
  press(15);expect_audio(0);done_audio();press(7);expect_audio(2);done_audio();expect_audio(68);done_audio();expect_audio(74);done_audio();

  // Stage 2 has seven unique questions, but must still produce a ten-item
  // retest by repeating only after all seven have appeared once.
  press(12);expect_audio(69);done_audio();expect_audio(74);done_audio();
  select_retest();press(3);
  for(i=0;i<10;i=i+1)begin
   while(!audio_request)@(negedge clk);
   if(question_id<15||question_id>21)$fatal(1,"stage2 selected out-of-range q=%0d",question_id);
   if(i<7&&dut.retest_used[question_id]!==1'b1)$fatal(1,"stage2 unique selection was not marked");
   answer_zero_wrong();
  end
  expect_audio(102);done_audio();expect_audio(106);done_audio();

  // Move through stages 3 and 4 to stage 5.  Its five unique questions must
  // likewise form a complete ten-item retest without hanging or escaping.
  press(12);expect_audio(70);done_audio();expect_audio(74);done_audio();
  press(12);expect_audio(71);done_audio();expect_audio(74);done_audio();
  press(12);expect_audio(72);done_audio();expect_audio(74);done_audio();
  select_retest();press(3);
  for(i=0;i<10;i=i+1)begin
   while(!audio_request)@(negedge clk);
   if(question_id<37||question_id>41)$fatal(1,"stage5 selected out-of-range q=%0d",question_id);
   answer_zero_wrong();
  end
  expect_audio(102);done_audio();expect_audio(106);done_audio();
  $display("PASS all-stage retest: short stages produce ten in-range questions");$finish;
 end
endmodule
