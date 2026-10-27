// One accepted start sends exactly ASCII hello, 115200 8N1, no newline.
module uart_hello_tx #(parameter integer CLK_HZ=50000000,BAUD=115200)(
 input wire clk,rst_n,start,output wire tx,output reg busy,output reg done
);
 localparam integer BIT_CYCLES=CLK_HZ/BAUD;
 reg[31:0] counter;
 reg[3:0] bit_index;
 reg[2:0] char_index;
 reg[9:0] shift;
 function[7:0]letter;input[2:0]n;begin
  case(n)0:letter="h";1:letter="e";2,3:letter="l";default:letter="o";endcase
 end endfunction
 assign tx=busy?shift[0]:1'b1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin busy<=0;done<=0;counter<=0;bit_index<=0;char_index<=0;shift<=10'h3ff;end
  else begin
   done<=0;
   if(!busy)begin
    if(start)begin busy<=1;char_index<=0;bit_index<=0;shift<={1'b1,8'h68,1'b0};counter<=BIT_CYCLES-1;end
   end else if(counter!=0)counter<=counter-1;
   else begin
    counter<=BIT_CYCLES-1;
    if(bit_index==9)begin
     if(char_index==4)begin busy<=0;done<=1;end
     else begin char_index<=char_index+1;bit_index<=0;shift<={1'b1,letter(char_index+1'b1),1'b0};end
    end else begin shift<={1'b1,shift[9:1]};bit_index<=bit_index+1;end
   end
  end
 end
endmodule
