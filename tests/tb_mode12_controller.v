`timescale 1ns/1ps
module tb_mode12_controller;
 wire hold=1'b0,external_exit=1'b0;
 reg clk=0,rst_n=0,codec_ready=1,key_valid=0,audio_busy=0,audio_done=0; reg[5:0]key_id=0;
 wire audio_request,running,mode2_active,answer_stage_b,session_done; wire[7:0]audio_index;
 wire[5:0]question_id,answer_current; wire[2:0]current_stage,unlocked_stage; wire[1:0]practice_type;
 always #5 clk=~clk;
 mode12_controller #(.MODE2_GAP_CYCLES(1)) dut(.*);
 task press;input[5:0]id;begin @(negedge clk);key_id=id;key_valid=1;@(negedge clk);key_valid=0;end endtask
 task expect_audio;input[7:0]x;integer t;begin t=0;while(!audio_request&&t<50)begin @(negedge clk);t=t+1;end if(!audio_request||audio_index!==x)$fatal(1,"want %0d got %0d",x,audio_index);end endtask
 task done_audio;begin @(negedge clk);audio_busy=1;@(negedge clk);audio_busy=0;audio_done=1;@(negedge clk);audio_done=0;end endtask
 initial begin repeat(3)@(negedge clk);rst_n=1;
  press(15);expect_audio(0);done_audio();
  press(7);expect_audio(2);done_audio();expect_audio(68);done_audio();expect_audio(74);done_audio();
  repeat(3)@(negedge clk);if(audio_request)$fatal(1,"question started before S4 confirmation");
  // The user selects reinforce explicitly. Selecting a stage afterwards must
  // reset the type to normal and return to the quiet ready state.
  press(4);expect_audio(75);done_audio();
  if(practice_type!==1)$fatal(1,"type key did not select reinforce");
  press(4);expect_audio(76);done_audio();
  if(practice_type!==2)$fatal(1,"retest must be selectable without a prerequisite");
  press(12);expect_audio(68);done_audio();expect_audio(74);done_audio();
  if(practice_type!==0)$fatal(1,"stage selection did not reset normal mode");
  repeat(3)@(negedge clk);if(audio_request)$fatal(1,"stage selection started a question without S4");
  // S5 pressed while the question audio is busy must be remembered and
  // applied immediately after that phrase, without requesting SYS_DEFER.
  press(3);expect_audio(111);
  @(negedge clk);audio_busy=1;
  press(4);
  @(negedge clk);audio_busy=0;audio_done=1;
  @(negedge clk);audio_done=0;
  expect_audio(75);done_audio();
  if(practice_type!==1)$fatal(1,"busy-time type selection was lost");
  press(4);expect_audio(76);done_audio();
  press(4);expect_audio(74);done_audio();
  // S13 must likewise be accepted during playback.  Only stage 1 is unlocked,
  // so it wraps to stage 1 and announces normal practice afterwards.
  press(3);expect_audio(111);
  @(negedge clk);audio_busy=1;
  press(12);
  @(negedge clk);audio_busy=0;audio_done=1;
  @(negedge clk);audio_done=0;
  expect_audio(68);done_audio();expect_audio(74);done_audio();
  press(3);expect_audio(111);done_audio();expect_audio(64);done_audio();
  // S5 during answer entry must switch immediately, not play SYS_DEFER (110).
  press(4);expect_audio(75);done_audio();
  if(practice_type!==1)$fatal(1,"in-question type switch failed");
  press(4);expect_audio(76);done_audio();
  press(4);expect_audio(74);done_audio();
  press(3);expect_audio(111);done_audio();expect_audio(64);
  // A learner may start entering dot keys before the input prompt has
  // finished.  These two keys must be retained instead of being discarded.
  @(negedge clk);audio_busy=1;
  press(8);press(9);
  if(answer_current!==6'b000011)$fatal(1,"point input during prompt was lost: %b",answer_current);
  @(negedge clk);audio_busy=0;audio_done=1;
  @(negedge clk);audio_done=0;
  press(3);expect_audio(65);done_audio();
  press(10);press(1);press(3);expect_audio(4);done_audio();expect_audio(112);
  if(question_id!==1||current_stage!==0||practice_type!==0)$fatal(1,"stage state mismatch");
  $display("PASS mode controller: staged entry, prompts and first correct answer verified");$finish;
 end
endmodule
