`timescale 1ns/1ps
module tb_mode2_correction;
 wire hold=1'b0,external_exit=1'b0;
 reg clk=0,rst_n=0,codec_ready=1,key_valid=0,audio_busy=0,audio_done=0;reg[5:0]key_id=0;
 wire audio_request,running,mode2_active,answer_stage_b,session_done;wire[7:0]audio_index;
 wire[5:0]question_id,answer_current;wire[2:0]current_stage,unlocked_stage;wire[1:0]practice_type;
 always #5 clk=~clk;mode12_controller #(.MODE2_GAP_CYCLES(1))dut(.*);
 task press;input[5:0]id;begin@(negedge clk);key_id=id;key_valid=1;@(negedge clk);key_valid=0;end endtask
 task expect_audio;input[7:0]x;integer t;begin t=0;while(!audio_request&&t<80)begin@(negedge clk);t=t+1;end if(!audio_request||audio_index!==x)$fatal(1,"want %0d got %0d q=%0d",x,audio_index,question_id);end endtask
 task done_audio;begin@(negedge clk);audio_busy=1;@(negedge clk);audio_busy=0;audio_done=1;@(negedge clk);audio_done=0;end endtask
 task enter_mask;input[5:0]m;begin if(m[0])press(8);if(m[1])press(9);if(m[2])press(10);if(m[3])press(0);if(m[4])press(1);if(m[5])press(2);end endtask
 task answer_correct;begin
  done_audio();expect_audio(64);done_audio();enter_mask(dut.standard_a);press(3);expect_audio(65);done_audio();
  enter_mask(dut.standard_b);press(3);expect_audio(4);done_audio();
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  press(15);expect_audio(0);done_audio();press(7);expect_audio(2);done_audio();expect_audio(68);done_audio();expect_audio(74);done_audio();
  // With no recorded error, reinforcement reports the empty set and waits.
  press(4);expect_audio(75);done_audio();press(3);expect_audio(104);done_audio();
  press(4);expect_audio(76);done_audio();press(4);expect_audio(74);done_audio();
  // Model two errors previously recorded by normal practice: questions 0 and 2.
  @(negedge clk);dut.wrong_mask=(42'b1<<0)|(42'b1<<2);
  press(4);expect_audio(75);done_audio();press(3);expect_audio(111);done_audio();expect_audio(64);done_audio();

  // Submit 000000/000000. Correction gives full b(1,2), full a(3,5),
  // and then asks for the whole item again, without missing/extra analysis.
  press(3);expect_audio(65);done_audio();press(3);expect_audio(5);done_audio();
  expect_audio(87);done_audio();expect_audio(89);done_audio();expect_audio(90);done_audio();
  expect_audio(88);done_audio();expect_audio(91);done_audio();expect_audio(93);done_audio();
  expect_audio(97);done_audio();

  // Corrected question 0 is removed; only recorded question 2 follows.
  enter_mask(dut.standard_a);press(3);expect_audio(65);done_audio();
  enter_mask(dut.standard_b);press(3);expect_audio(4);done_audio();expect_audio(113);
  answer_correct();expect_audio(101);done_audio();
  if(dut.wrong_mask[0]||dut.wrong_mask[2])$fatal(1,"corrected questions not removed");
  $display("PASS mode2 correction: wrong-only selection and concise full-point correction verified");$finish;
 end
endmodule
