// Independent mode3 table. bit0..5 = dots1..6. No tone teaching in this stage.
module mode3_learning_lut(
 input wire[2:0]target,input wire character,
 output reg[7:0]char_audio,output reg[5:0]initial_mask,final_mask,
 output reg two_characters,valid
);
 always @* begin
  char_audio=0;initial_mask=0;final_mask=0;two_characters=0;valid=1;
  case(target)
   1:begin char_audio=153;initial_mask=6'b010011;final_mask=6'b110010;end // hong
   2:begin char_audio=154;initial_mask=6'b000111;final_mask=6'b101100;end // lv
   3:begin char_audio=155;initial_mask=6'b000111;final_mask=6'b100111;end // lan
   4:begin two_characters=1;
    if(!character)begin char_audio=160;initial_mask=6'b000011;final_mask=6'b101110;end
    else begin char_audio=161;initial_mask=6'b110101;end // zi: i omitted
   end
   5:begin two_characters=1;
    if(!character)begin char_audio=162;initial_mask=6'b001111;final_mask=6'b100001;end
    else begin char_audio=163;initial_mask=6'b011011;final_mask=6'b010101;end // guo
   end
   6:begin two_characters=1;
    if(!character)begin char_audio=164;initial_mask=6'b011111;final_mask=6'b111100;end
    else begin char_audio=161;initial_mask=6'b110101;end
   end
   7:begin two_characters=1;
    if(!character)begin char_audio=165;initial_mask=6'b110001;final_mask=6'b100101;end
    else begin char_audio=166;initial_mask=6'b000011;final_mask=6'b011100;end // biao
   end
   default:valid=0;
  endcase
 end
endmodule
