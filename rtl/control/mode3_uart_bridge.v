// Surround the existing mode1/2 controller without changing its exercise FSM.
// Mode2 S8 enters mode3; mode3 S8 injects S8 into mode2 to return to mode1.
module mode3_uart_bridge(
 input wire clk,rst_n,running,mode2_active,key_valid,
 input wire[5:0]key_id,input wire audio_busy,audio_done,
 input wire old_request,input wire[7:0]old_index,
 input wire target_valid,input wire[2:0]target_id,
 input wire result_valid,input wire[4:0]result_count,input wire[95:0]result_cells,
 input wire tx_busy,tx_done,
 output reg hello_start,output wire writing_wait,
 output wire controller_key_valid,output wire[5:0]controller_key_id,
 output wire request,output wire[7:0]audio_index,output wire mode3_active,
 output wire controller_hold,output wire external_exit
);
 reg[3:0]state;
 reg learn_pending,character;
 reg[2:0]learning_target,learn_step;
 reg[5:0]dot_mask;
 reg camera_brl;
 reg[95:0] actual_cells;
 reg[4:0] actual_count;
 reg[23:0] expected_cells;
 reg[2:0] expected_count;
 reg answer_correct;
 assign writing_wait=state==7;
 wire[7:0]char_audio;wire[5:0]initial_mask,final_mask;
 wire two_characters,learning_valid;
 mode3_learning_lut learning_table(.target(learning_target),.character(character),
  .char_audio(char_audio),.initial_mask(initial_mask),.final_mask(final_mask),
  .two_characters(two_characters),.valid(learning_valid));
 function[2:0]first_dot;input[5:0]mask;begin
  if(mask[0])first_dot=0;else if(mask[1])first_dot=1;else if(mask[2])first_dot=2;
  else if(mask[3])first_dot=3;else if(mask[4])first_dot=4;else first_dot=5;
 end endfunction
 reg[2:0]pending_target,last_target;
 reg pending_valid;
 reg new_request;
 reg[7:0]new_index;
 reg[5:0]exit_key;
 // 0 normal, 1 await entry, 2 entry prompt, 3 target prompt,
 // 4 listening/playing, 5 await exit, 6 inject exit key.
 wire entering=running&&mode2_active&&key_valid&&key_id==7;
 assign mode3_active=state!=0&&state!=6;
 assign controller_hold=mode3_active||entering;
 assign external_exit=state==6;
 assign controller_key_valid=(state==6)||
  (state==0&&!entering&&key_valid);
 assign controller_key_id=(state==6)?exit_key:key_id;
 assign request=(state==0||state==6)?old_request:new_request;
 assign audio_index=(state==0||state==6)?old_index:new_index;
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=0;pending_target<=0;last_target<=0;
   learn_pending<=0;character<=0;learning_target<=0;learn_step<=0;dot_mask<=0;
   pending_valid<=0;new_request<=0;new_index<=0;exit_key<=7;
   hello_start<=0;camera_brl<=0;actual_cells<=0;actual_count<=0;
   expected_cells<=0;expected_count<=0;answer_correct<=0;end
  else begin
   new_request<=0;hello_start<=0;
   if((state==2||state==3||state==4)&&target_valid)begin
    pending_target<=target_id;pending_valid<=1;
   end
   if(state>=1&&state!=5&&state!=6&&key_valid&&(key_id==7||key_id==15))begin
    state<=5;exit_key<=key_id;pending_valid<=0;learn_pending<=0;
   end else case(state)
    0:if(entering)begin state<=1;pending_valid<=0;last_target<=0;end
    1:if(!audio_busy&&!old_request)begin new_index<=167;new_request<=1;state<=2;end
    2:if(audio_done)begin new_index<=168;new_request<=1;state<=3;end
    3:if(audio_done)state<=4;
    4:if(key_valid&&key_id==3&&!audio_busy&&!new_request&&!tx_busy&&!hello_start)begin
     pending_valid<=0;
     if(last_target==0)begin new_index<=170;new_request<=1;state<=10;end
     else begin learning_target<=last_target;hello_start<=1;camera_brl<=1;state<=11;end
    end else if(!audio_busy&&!new_request&&learn_pending)begin
     learn_pending<=0;character<=0;learn_step<=0;
     if(learning_target==0)begin new_index<=170;new_request<=1;state<=10;end
     else state<=8;
    end else if(!audio_busy&&!new_request&&pending_valid&&!target_valid)begin
     pending_valid<=0;
     if(pending_target!=last_target)begin
      new_index<=152+pending_target;new_request<=1;last_target<=pending_target;
     end
    end
    5:if(!tx_busy&&!hello_start)begin
     if(camera_brl)begin hello_start<=1;camera_brl<=0;end
     else if(!audio_busy&&!new_request&&!old_request)state<=6;
    end
    6:begin state<=0;last_target<=0;pending_valid<=0;end
    8:if(!audio_busy&&!new_request)begin
     if(!learning_valid)begin new_index<=170;new_request<=1;state<=10;end
     else case(learn_step)
      0:begin new_index<=char_audio;new_request<=1;learn_step<=1;state<=9;end
      1:begin new_index<=87;new_request<=1;dot_mask<=initial_mask;learn_step<=2;state<=9;end
      2,4:if(dot_mask!=0)begin
       new_index<=89+first_dot(dot_mask);new_request<=1;
       dot_mask<=dot_mask&~(6'b1<<first_dot(dot_mask));state<=9;
      end else learn_step<=learn_step+1;
      3:if(final_mask!=0)begin
       new_index<=88;new_request<=1;dot_mask<=final_mask;learn_step<=4;state<=9;
      end else learn_step<=5;
      5:if(two_characters&&!character)begin character<=1;learn_step<=0;end
       else begin new_index<=171;new_request<=1;state<=10;end
      default:state<=4;
     endcase
    end
    9:if(audio_done)state<=8;
    7:if(result_valid&&!tx_busy&&!hello_start)begin
     actual_cells<=result_cells;actual_count<=result_count;
     hello_start<=1;camera_brl<=0;pending_valid<=0;
     expected_cells<=0;expected_count<=0;character<=0;state<=12;
    end
    11:if(tx_done)state<=7;
    12:begin
     expected_cells[expected_count*6+:6]<=initial_mask;
     if(final_mask!=0)expected_cells[(expected_count+1)*6+:6]<=final_mask;
     expected_count<=expected_count+((final_mask!=0)?2:1);
     if(two_characters&&!character)character<=1;
     else state<=13;
    end
    13:if(!audio_busy&&!new_request)begin
     answer_correct<=(actual_count==expected_count&&actual_cells[23:0]==expected_cells);
     new_index<=(actual_count==expected_count&&actual_cells[23:0]==expected_cells)?4:5;
     new_request<=1;state<=15;
    end
    15:if(audio_done)begin
     if(answer_correct)begin last_target<=0;pending_valid<=0;state<=4;end
     else begin character<=0;learn_step<=0;dot_mask<=0;state<=8;end
    end
    10:if(audio_done)begin last_target<=0;pending_valid<=0;state<=4;end
    default:state<=0;
   endcase
  end
 end
endmodule
