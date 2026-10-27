module mode12_controller #(
 parameter integer MODE2_GAP_CYCLES=25_000_000,
 parameter integer DIAGNOSTIC_MODE=0,
 parameter integer MODE3_AUDIO_TEST=0,
 parameter integer ENABLE_HOLD=0,
 // Keep this at zero for the final progressive-unlock product.  The current
 // hardware-validation image sets it to five so all six stages can be tested
 // before the unlock policy is connected.
 parameter integer INITIAL_UNLOCKED_STAGE=0
)(
 input wire clk,rst_n,codec_ready,key_valid,input wire[5:0]key_id,
 input wire hold,
 input wire external_exit,
 input wire audio_busy,audio_done,output reg audio_request,output reg[7:0]audio_index,
 output reg running,mode2_active,output reg[5:0]question_id,
 output reg[5:0]answer_current,output reg answer_stage_b,session_done,
 output reg[2:0]current_stage,unlocked_stage,output reg[1:0]practice_type
);
 localparam[5:0] P1=8,P2=9,P3=10,P4=0,P5=1,P6=2,CLEAR=11,CONFIRM=3;
 localparam[5:0] TYPE_KEY=4,MODE_KEY=7,STAGE_KEY=12,POWER=15;
 localparam[1:0] NORMAL=0,REINFORCE=1,RETEST=2;
 // Use the previously hardware-verified prompts while the newly batch-split
 // SYS_21/SYS_22 clips are audited for mislabeled spoken content.
 localparam[7:0] SYS_FIRST=64,SYS_FINAL=65,SYS_ONLY_FINAL=80,SYS_EMPTY=81;
 localparam[7:0] SYS_WRONG_A=82,SYS_WRONG_B=83,SYS_MISSING=85,SYS_EXTRA=86;
 localparam[7:0] SYS_CORRECT_A=87,SYS_CORRECT_B=88,SYS_DOT1=89;
 localparam[7:0] SYS_REENTER_A=95,SYS_REENTER_B=96,SYS_CORRECTED=99;
 localparam[7:0] SYS_NORMAL_END=100,SYS_REINFORCE_END=101,SYS_RETEST_END=102;
 localparam[7:0] SYS_PASS=105,SYS_NOT_PASS=106,SYS_UNLOCK=107,SYS_NORMAL_FIRST=108;
 localparam[7:0] SYS_COMPREHENSIVE=109,SYS_DEFER=110;
 localparam[5:0] ST_STANDBY=0,ST_WELCOME=1,ST_MODE1=2,ST_MODE1_WAIT=3;
 localparam[5:0] ST_M2_MODE=4,ST_M2_STAGE=5,ST_M2_TYPE=6,ST_GAP=7;
 localparam[5:0] ST_QREQ=8,ST_QWAIT=9,ST_PREQ=10,ST_PWAIT=11,ST_INPUT_A=12,ST_INPUT_B=13;
 localparam[5:0] ST_CLEAR_REQ=14,ST_CLEAR_WAIT=15,ST_ERR_LABEL=16,ST_ERR_MISS_HDR=17;
 localparam[5:0] ST_ERR_MISS_DOT=18,ST_ERR_EXTRA_HDR=19,ST_ERR_EXTRA_DOT=20;
 localparam[5:0] ST_ERR_CORRECT_HDR=21,ST_ERR_CORRECT_DOT=22,ST_ERR_REENTER=23;
 localparam[5:0] ST_FEEDBACK=24,ST_CORRECTED=25,ST_NEXT=26,ST_END=27,ST_END_RESULT=28;
 localparam[5:0] ST_UNLOCK=29,ST_COMPLETE=30,ST_DEFER_WAIT=31,ST_SHUTDOWN=32;
 localparam[5:0] ST_READY=33;
 localparam[5:0] ST_DIAG_WAIT=34;
 localparam[5:0] ST_RETEST_SELECT=35;
 localparam[5:0] ST_UNLOCK_ANN=36;
 reg[5:0]state,return_state; reg[31:0]gap_counter; reg clear_b,correction_b;
 reg[7:0]mode3_test_index;
 reg[5:0]submitted,missing_mask,extra_mask,correct_mask; reg[2:0]dot_cursor;
 reg question_had_error,session_had_error; reg[41:0]wrong_mask;
 reg reinforce_wrong_only;
 reg[5:0]question_pos; reg[5:0]stage_base,stage_count; reg[5:0]last_question;
 reg[5:0]answer_a_latched; reg[5:0]pending_key; reg pending_change;
 reg queued_select_valid; reg[5:0]queued_select_key;
 reg[5:0] next_q;
 reg[5:0] qbase,qcount;
 reg normal_done[0:5];
 reg[3:0]retest_pos,retest_correct;
 reg[2:0]retest_wrong_used;
 reg[41:0]retest_wrong_snapshot,retest_used;
 reg[5:0]retest_rotation[0:5];
 reg[5:0]retest_scan_index;reg[4:0]retest_scan_count;reg[1:0]retest_scan_phase;
 wire m1_valid; wire[7:0]m1_audio;
 mode1_key_lut m1(.key_id(key_id),.valid(m1_valid),.audio_index(m1_audio));
 wire[5:0]standard_a,standard_b; wire[7:0]question_audio; wire qvalid,has_initial;
 mode2_question_rom qr(.question_id(question_id),.answer_a(standard_a),.answer_b(standard_b),
  .question_audio(question_audio),.has_initial(has_initial),.valid(qvalid));
 function[5:0]pmask;input[5:0]id;begin case(id)P1:pmask=1;P2:pmask=2;P3:pmask=4;P4:pmask=8;P5:pmask=16;P6:pmask=32;default:pmask=0;endcase end endfunction
 function[5:0]base_of;input[2:0]s;begin case(s)0:base_of=0;1:base_of=15;2:base_of=22;3:base_of=29;4:base_of=37;default:base_of=0;endcase end endfunction
 function[5:0]count_of;input[2:0]s;begin case(s)0:count_of=15;1:count_of=7;2:count_of=7;3:count_of=8;4:count_of=5;default:count_of=42;endcase end endfunction
 function[2:0]first_dot;input[5:0]m;begin if(m[0])first_dot=0;else if(m[1])first_dot=1;else if(m[2])first_dot=2;else if(m[3])first_dot=3;else if(m[4])first_dot=4;else first_dot=5;end endfunction
 function has_wrong;input[41:0]m;input[5:0]b;input[5:0]n;integer k;begin has_wrong=0;for(k=0;k<42;k=k+1)if(k>=b&&k<b+n&&m[k])has_wrong=1;end endfunction
 function[5:0]first_wrong;input[41:0]m;input[5:0]b;input[5:0]n;integer k;reg found;begin first_wrong=b;found=0;for(k=0;k<42;k=k+1)if(!found&&k>=b&&k<b+n&&m[k])begin first_wrong=k;found=1;end end endfunction
 function[5:0]next_wrong_after;input[41:0]m;input[5:0]cur;input[5:0]limit;integer k;reg found;begin next_wrong_after=63;found=0;for(k=0;k<42;k=k+1)if(!found&&k>cur&&k<limit&&m[k])begin next_wrong_after=k;found=1;end end endfunction
 task req;input[7:0]i;begin audio_index<=i;audio_request<=1;end endtask
 task setup_stage;input[2:0]s;begin stage_base<=base_of(s);stage_count<=count_of(s);question_pos<=0;question_id<=base_of(s);end endtask
 integer i;
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=ST_STANDBY;audio_request<=0;audio_index<=0;running<=0;mode2_active<=0;
   mode3_test_index<=153;
   question_id<=0;answer_current<=0;answer_stage_b<=0;session_done<=0;current_stage<=0;unlocked_stage<=INITIAL_UNLOCKED_STAGE;
   practice_type<=NORMAL;gap_counter<=0;wrong_mask<=0;pending_change<=0;session_had_error<=0;reinforce_wrong_only<=0;
   queued_select_valid<=0;queued_select_key<=0;correction_b<=0;
   retest_pos<=0;retest_correct<=0;retest_wrong_used<=0;retest_wrong_snapshot<=0;retest_used<=0;
   retest_scan_index<=0;retest_scan_count<=0;retest_scan_phase<=0;
   for(i=0;i<6;i=i+1)begin normal_done[i]<=0;retest_rotation[i]<=0;end
  end else if(ENABLE_HOLD&&external_exit)begin
   queued_select_valid<=0;pending_change<=0;answer_current<=0;
   answer_stage_b<=0;mode2_active<=0;
   req(key_id==POWER?6:1);state<=(key_id==POWER)?ST_SHUTDOWN:ST_MODE1_WAIT;
  end else if(ENABLE_HOLD&&hold)begin audio_request<=0;end else begin
   audio_request<=0;
   // Keep S5/S13 responsive while PCM is playing.  The current phrase is
   // allowed to finish to avoid an I2S discontinuity; the queued selection is
   // then applied before the old state machine can request another phrase.
   if(key_valid&&audio_busy&&(key_id==TYPE_KEY||key_id==STAGE_KEY))begin
    queued_select_valid<=1;queued_select_key<=key_id;
   end else if(queued_select_valid&&!audio_busy)begin
    queued_select_valid<=0;pending_change<=0;answer_current<=0;
    answer_a_latched<=0;answer_stage_b<=0;question_had_error<=0;
    if(queued_select_key==TYPE_KEY)begin
     practice_type<=(practice_type==RETEST)?NORMAL:practice_type+1;
     req(74+((practice_type==RETEST)?NORMAL:practice_type+1));state<=ST_M2_TYPE;
    end else begin
     current_stage<=(current_stage>=unlocked_stage)?0:current_stage+1;
     practice_type<=NORMAL;
     setup_stage((current_stage>=unlocked_stage)?0:current_stage+1);
     req(68+((current_stage>=unlocked_stage)?0:current_stage+1));state<=ST_M2_STAGE;
    end
   end else case(state)
    ST_STANDBY:begin running<=0;mode2_active<=0;session_done<=0;if(codec_ready&&key_valid&&key_id==POWER&&!audio_busy)begin running<=1;req(0);state<=ST_WELCOME;end end
    ST_WELCOME:if(audio_done)state<=ST_MODE1;
    ST_MODE1:begin mode2_active<=0;if(key_valid&&!audio_busy)begin
      if(key_id==POWER)begin req(6);state<=ST_SHUTDOWN;end
      else if(key_id==MODE_KEY)begin mode2_active<=1;current_stage<=0;practice_type<=NORMAL;setup_stage(0);req(2);state<=ST_M2_MODE;end
      else if(MODE3_AUDIO_TEST&&key_id==5)begin
       req(mode3_test_index);
       mode3_test_index<=(mode3_test_index==171)?153:mode3_test_index+1;
       state<=ST_MODE1_WAIT;
      end
      else if(m1_valid)req(m1_audio);
    end end
    ST_MODE1_WAIT:if(audio_done)state<=ST_MODE1;
    ST_M2_MODE:if(audio_done)begin req(68+current_stage);state<=ST_M2_STAGE;end
    ST_M2_STAGE:if(audio_done)begin req(74+practice_type);state<=ST_M2_TYPE;end
    // Enter a quiet preparation state after announcing mode/stage/type.
    // The user explicitly presses S4 to start; this prevents the first
    // question from being glued to the announcements.
    ST_M2_TYPE:if(audio_done)state<=ST_READY;
    ST_READY:begin
     session_done<=1;
     if(key_valid&&!audio_busy)begin
      if(DIAGNOSTIC_MODE!=0&&key_id==CONFIRM)begin req(8'd111);state<=ST_DIAG_WAIT;end
      else if(DIAGNOSTIC_MODE!=0&&key_id==TYPE_KEY)begin req(8'd64);state<=ST_DIAG_WAIT;end
      else if(DIAGNOSTIC_MODE!=0&&key_id==STAGE_KEY)begin req(8'd73);state<=ST_DIAG_WAIT;end
      else if(key_id==POWER)begin req(6);state<=ST_SHUTDOWN;end
      else if(key_id==MODE_KEY)begin mode2_active<=0;req(1);state<=ST_MODE1_WAIT;end
      else if(key_id==STAGE_KEY)begin
       current_stage<=(current_stage>=unlocked_stage)?0:current_stage+1;
       // Every newly selected stage starts in normal-practice mode.
       practice_type<=NORMAL;
       setup_stage((current_stage>=unlocked_stage)?0:current_stage+1);
       req(68+((current_stage>=unlocked_stage)?0:current_stage+1));state<=ST_M2_STAGE;
      end else if(key_id==TYPE_KEY)begin
       // Practice types are freely selectable inside every unlocked stage.
       practice_type<=(practice_type==RETEST)?NORMAL:practice_type+1;
      req(74+((practice_type==RETEST)?NORMAL:practice_type+1));state<=ST_M2_TYPE;
      end else if(key_id==CONFIRM)begin
       if(practice_type==REINFORCE&&!has_wrong(wrong_mask,base_of(current_stage),count_of(current_stage)))begin
        req(8'd104);state<=ST_M2_TYPE;
       end else if(practice_type==RETEST)begin
        setup_stage(current_stage);retest_wrong_snapshot<=wrong_mask;retest_pos<=0;retest_correct<=0;retest_used<=0;retest_wrong_used<=0;
        retest_scan_index<=base_of(current_stage);retest_scan_count<=0;retest_scan_phase<=0;
        session_had_error<=0;question_had_error<=0;session_done<=0;state<=ST_RETEST_SELECT;
       end else begin
        setup_stage(current_stage);reinforce_wrong_only<=practice_type==REINFORCE;
        if(practice_type==REINFORCE)question_id<=first_wrong(wrong_mask,base_of(current_stage),count_of(current_stage));
        gap_counter<=0;session_had_error<=0;question_had_error<=0;session_done<=0;state<=ST_GAP;
       end
      end
     end
    end
    ST_DIAG_WAIT:if(audio_done)state<=ST_READY;
    // Sequential retest selector for all six stages: examine one candidate per
    // clock.  Stages with fewer than ten unique questions repeat a rotated
    // subset only after every item in that stage has appeared once.
    // phase 0 = current wrong set (maximum five), phase 1 = regular questions
    // excluding the wrong-set snapshot, phase 2 = any remaining unused item.
    ST_RETEST_SELECT:begin
     if(retest_scan_phase==0)begin
      if(retest_wrong_used<5&&retest_wrong_snapshot[retest_scan_index]&&!retest_used[retest_scan_index])begin
       question_id<=retest_scan_index;retest_used[retest_scan_index]<=1'b1;
       retest_wrong_used<=retest_wrong_used+1'b1;gap_counter<=0;state<=ST_GAP;
      end else if(retest_scan_index>=base_of(current_stage)+count_of(current_stage)-1||retest_wrong_used>=5)begin
       retest_scan_phase<=1;retest_scan_index<=base_of(current_stage)+retest_rotation[current_stage];retest_scan_count<=0;
      end else retest_scan_index<=retest_scan_index+1'b1;
     end else if(retest_scan_phase==1)begin
      if(!retest_wrong_snapshot[retest_scan_index]&&!retest_used[retest_scan_index])begin
       question_id<=retest_scan_index;retest_used[retest_scan_index]<=1'b1;gap_counter<=0;state<=ST_GAP;
      end else if(retest_scan_count>=count_of(current_stage)-1)begin
       retest_scan_phase<=2;retest_scan_index<=base_of(current_stage)+retest_rotation[current_stage];retest_scan_count<=0;
      end else begin
       retest_scan_index<=(retest_scan_index>=base_of(current_stage)+count_of(current_stage)-1)?base_of(current_stage):retest_scan_index+1'b1;
       retest_scan_count<=retest_scan_count+1'b1;
      end
     end else begin
      if(!retest_used[retest_scan_index])begin
       question_id<=retest_scan_index;retest_used[retest_scan_index]<=1'b1;gap_counter<=0;state<=ST_GAP;
      end else begin
       retest_scan_index<=(retest_scan_index>=base_of(current_stage)+count_of(current_stage)-1)?base_of(current_stage):retest_scan_index+1'b1;
       if(retest_scan_count>=count_of(current_stage)-1)begin
        // All unique items are already used.  Permit a second pass so short
        // stages can still form a ten-question retest.
        retest_used<=0;retest_scan_count<=0;
       end else retest_scan_count<=retest_scan_count+1'b1;
      end
     end
    end
    ST_GAP:if(MODE2_GAP_CYCLES==0||gap_counter>=MODE2_GAP_CYCLES-1)begin question_had_error<=0;session_had_error<=0;session_done<=0;state<=ST_QREQ;end else gap_counter<=gap_counter+1;
    ST_QREQ:if(!audio_busy&&qvalid)begin req(question_audio);state<=ST_QWAIT;end
    ST_QWAIT:if(audio_done)begin answer_current<=0;answer_stage_b<=!has_initial;if(has_initial)begin req(SYS_FIRST);state<=ST_PREQ;return_state<=ST_INPUT_A;end else begin req(SYS_ONLY_FINAL);state<=ST_PREQ;return_state<=ST_INPUT_B;end end
    ST_PREQ:state<=ST_PWAIT;
    // Accept point entry while the input prompt is still playing.  This
    // prevents a correctly pressed point from being lost merely because the
    // user starts before the phrase has completely finished.  Confirmation
    // remains active only after entering ST_INPUT_A/ST_INPUT_B.
    ST_PWAIT:begin
     if(key_valid)begin
      if(|pmask(key_id))answer_current<=answer_current|pmask(key_id);
      else if(key_id==CLEAR)answer_current<=0;
     end
     if(audio_done)state<=return_state;
    end
    ST_INPUT_A,ST_INPUT_B:if(key_valid&&!audio_busy)begin
      if(key_id==POWER)begin req(6);state<=ST_SHUTDOWN;end
      // Practice type selection is immediate, even while an answer is being
      // entered.  Abandon the unfinished question and return to READY after
      // announcing the newly selected type.
      else if(key_id==TYPE_KEY)begin
       answer_current<=0;answer_a_latched<=0;answer_stage_b<=0;
       question_had_error<=0;pending_change<=0;
       practice_type<=(practice_type==RETEST)?NORMAL:practice_type+1;
       req(74+((practice_type==RETEST)?NORMAL:practice_type+1));state<=ST_M2_TYPE;
      end
      else if(key_id==STAGE_KEY)begin
       // Stage selection is immediate while entering an answer.  Abandon the
       // unfinished item; do not play the old deferred-switch prompt.
       answer_current<=0;answer_a_latched<=0;answer_stage_b<=0;
       question_had_error<=0;pending_change<=0;
       current_stage<=(current_stage>=unlocked_stage)?0:current_stage+1;
       practice_type<=NORMAL;
       setup_stage((current_stage>=unlocked_stage)?0:current_stage+1);
       req(68+((current_stage>=unlocked_stage)?0:current_stage+1));state<=ST_M2_STAGE;
      end
      else if(key_id==MODE_KEY)begin pending_change<=1;pending_key<=key_id;return_state<=state;req(SYS_DEFER);state<=ST_DEFER_WAIT;end
      else if(key_id==CLEAR)begin answer_current<=0;clear_b<=(state==ST_INPUT_B);state<=ST_CLEAR_REQ;end
      else if(key_id==CONFIRM)begin
       // S4 always submits the six-bit value.  With no point selected the
       // submitted Braille symbol is 6'b000000, rather than an empty-input
       // command that blocks progress.
       if(state==ST_INPUT_A)begin
        // Judge only after the complete initial/final pair is submitted.
        answer_a_latched<=answer_current;
        if(practice_type!=REINFORCE&&answer_current!=standard_a)begin question_had_error<=1;session_had_error<=1;wrong_mask[question_id]<=1;end
        answer_current<=0;answer_stage_b<=1;req(SYS_FINAL);return_state<=ST_INPUT_B;state<=ST_PREQ;
       end else begin
        if(practice_type==REINFORCE)begin
         answer_current<=0;answer_stage_b<=0;
         if(answer_a_latched==standard_a&&answer_current==standard_b)begin
          question_had_error<=0;state<=ST_FEEDBACK;
         end else begin
          question_had_error<=1;session_had_error<=1;wrong_mask[question_id]<=1;state<=ST_ERR_LABEL;
         end
        end else begin
         if(answer_current!=standard_b)begin question_had_error<=1;session_had_error<=1;wrong_mask[question_id]<=1;end
         answer_current<=0;answer_stage_b<=0;state<=ST_FEEDBACK;
        end
       end
      end else if(|pmask(key_id))answer_current<=answer_current|pmask(key_id);
    end
    ST_CLEAR_REQ:if(!audio_busy)begin req(66);state<=ST_CLEAR_WAIT;end
    ST_CLEAR_WAIT:if(audio_done)state<=clear_b?ST_INPUT_B:ST_INPUT_A;
    ST_DEFER_WAIT:if(audio_done)state<=return_state;
    // Reinforcement correction: no missing/extra analysis.  Give the complete
    // correct initial points, then complete final points, and re-enter item.
    ST_ERR_LABEL:if(!audio_busy)begin req(5);state<=ST_ERR_CORRECT_HDR;end
    ST_ERR_CORRECT_HDR:if(audio_done)begin
      if(has_initial)begin correct_mask<=standard_a;correction_b<=0;req(SYS_CORRECT_A);state<=ST_ERR_CORRECT_DOT;end
      else begin correct_mask<=standard_b;correction_b<=1;req(SYS_CORRECT_B);state<=ST_ERR_CORRECT_DOT;end
    end
    ST_ERR_CORRECT_DOT:if(audio_done)begin
      dot_cursor=first_dot(correct_mask);req(SYS_DOT1+first_dot(correct_mask));correct_mask[first_dot(correct_mask)]<=0;
      if((correct_mask&~(6'b1<<first_dot(correct_mask)))==0)state<=correction_b?ST_ERR_REENTER:ST_ERR_EXTRA_HDR;
    end
    ST_ERR_EXTRA_HDR:if(audio_done)begin correct_mask<=standard_b;correction_b<=1;req(SYS_CORRECT_B);state<=ST_ERR_CORRECT_DOT;end
    ST_ERR_REENTER:if(audio_done)begin
      answer_current<=0;answer_a_latched<=0;answer_stage_b<=0;
      req(8'd97);return_state<=ST_INPUT_A;state<=ST_PREQ;
    end
    ST_FEEDBACK:if(!audio_busy)begin
      if(practice_type==REINFORCE&&!question_had_error)wrong_mask[question_id]<=0;
      if(practice_type==RETEST&&!question_had_error)retest_correct<=retest_correct+1'b1;
      req(question_had_error?5:4);state<=ST_NEXT;
    end
    ST_CORRECTED:if(audio_done)begin req(SYS_CORRECTED);state<=ST_NEXT;end
    ST_NEXT:if(audio_done)begin
      if(pending_change)begin pending_change<=0;session_done<=1;state<=ST_COMPLETE;
       if(pending_key==MODE_KEY)begin mode2_active<=0;req(1);state<=ST_MODE1_WAIT;end
       else if(pending_key==STAGE_KEY)begin current_stage<=(current_stage>=unlocked_stage)?0:current_stage+1;practice_type<=NORMAL;setup_stage((current_stage>=unlocked_stage)?0:current_stage+1);req(68+((current_stage>=unlocked_stage)?0:current_stage+1));state<=ST_M2_STAGE;end
       else begin practice_type<=(practice_type==RETEST)?NORMAL:practice_type+1;req(74+((practice_type==RETEST)?NORMAL:practice_type+1));state<=ST_M2_TYPE;end
      end else if(practice_type==REINFORCE&&reinforce_wrong_only)begin
       next_q=next_wrong_after(wrong_mask,question_id,stage_base+stage_count);
       if(!has_wrong(wrong_mask,stage_base,stage_count)||next_q==63)state<=ST_END;
       else begin question_id<=next_q;question_had_error<=0;state<=ST_QREQ;end
      end else if(practice_type==RETEST)begin
       if(retest_pos>=9)state<=ST_END;
       else begin
        retest_pos<=retest_pos+1'b1;retest_scan_index<=base_of(current_stage);retest_scan_count<=0;retest_scan_phase<=0;
        question_had_error<=0;state<=ST_RETEST_SELECT;
       end
      end else if(practice_type==NORMAL&&question_pos+1>=stage_count)begin
       // Normal practice continuously cycles inside the selected stage.
       question_pos<=0;question_id<=stage_base;question_had_error<=0;state<=ST_QREQ;
      end else if(question_pos+1>=stage_count)state<=ST_END;
      else begin question_pos<=question_pos+1;question_id<=stage_base+question_pos+1;question_had_error<=0;state<=ST_QREQ;end
    end
    ST_END:if(!audio_busy)begin req(practice_type==NORMAL?SYS_NORMAL_END:(practice_type==REINFORCE?SYS_REINFORCE_END:SYS_RETEST_END));state<=ST_END_RESULT;end
    ST_END_RESULT:if(audio_done)begin
      if(practice_type==NORMAL)begin normal_done[current_stage]<=1;session_done<=1;state<=ST_COMPLETE;end
      else if(practice_type==RETEST)begin
       if(retest_rotation[current_stage]+3>=stage_count)retest_rotation[current_stage]<=retest_rotation[current_stage]+3-stage_count;
       else retest_rotation[current_stage]<=retest_rotation[current_stage]+3;
       if(retest_correct>=8)begin req(SYS_PASS);state<=ST_UNLOCK;end
       else begin req(SYS_NOT_PASS);session_done<=1;state<=ST_COMPLETE;end
      end
      else begin session_done<=1;state<=ST_COMPLETE;end
    end
    // Wait until "stage passed" has finished, then unlock exactly one next
    // stage.  Repeating a passed retest in an older stage cannot skip levels.
    ST_UNLOCK:if(audio_done)begin
     if(current_stage<5&&unlocked_stage==current_stage)begin
      unlocked_stage<=current_stage+1;
      req(current_stage==4?SYS_COMPREHENSIVE:SYS_UNLOCK);state<=ST_UNLOCK_ANN;
     end else begin session_done<=1;state<=ST_COMPLETE;end
    end
    ST_UNLOCK_ANN:if(audio_done)begin session_done<=1;state<=ST_COMPLETE;end
    ST_COMPLETE:if(audio_done||!audio_busy)begin session_done<=1;if(key_valid&&!audio_busy)begin
      if(key_id==POWER)begin req(6);state<=ST_SHUTDOWN;end
      else if(key_id==MODE_KEY)begin mode2_active<=0;req(1);state<=ST_MODE1_WAIT;end
      else if(key_id==STAGE_KEY)begin current_stage<=(current_stage>=unlocked_stage)?0:current_stage+1;practice_type<=NORMAL;setup_stage((current_stage>=unlocked_stage)?0:current_stage+1);req(68+((current_stage>=unlocked_stage)?0:current_stage+1));state<=ST_M2_STAGE;end
      else if(key_id==TYPE_KEY)begin
       practice_type<=(practice_type==RETEST)?NORMAL:practice_type+1;
       req(74+((practice_type==RETEST)?NORMAL:practice_type+1));state<=ST_M2_TYPE;
      end else if(key_id==CONFIRM)begin
       if(practice_type==REINFORCE&&!has_wrong(wrong_mask,base_of(current_stage),count_of(current_stage)))begin
        req(8'd104);state<=ST_M2_TYPE;
       end else if(practice_type==RETEST)begin
        setup_stage(current_stage);retest_wrong_snapshot<=wrong_mask;retest_pos<=0;retest_correct<=0;retest_used<=0;retest_wrong_used<=0;
        retest_scan_index<=base_of(current_stage);retest_scan_count<=0;retest_scan_phase<=0;
        session_had_error<=0;question_had_error<=0;session_done<=0;state<=ST_RETEST_SELECT;
       end else begin
        setup_stage(current_stage);reinforce_wrong_only<=practice_type==REINFORCE;
        if(practice_type==REINFORCE)question_id<=first_wrong(wrong_mask,base_of(current_stage),count_of(current_stage));
        session_had_error<=0;question_had_error<=0;session_done<=0;state<=ST_QREQ;
       end
      end
    end end
    ST_SHUTDOWN:if(audio_done)begin running<=0;mode2_active<=0;state<=ST_STANDBY;end
    default:state<=ST_STANDBY;
   endcase
  end
 end
endmodule
