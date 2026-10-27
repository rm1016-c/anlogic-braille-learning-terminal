// ASCII: BRL,count,dots,...,END\n. Packed cell zero is bits[5:0].
// Strict ascending 1..6; token 0 is an empty cell. CRLF is accepted.
module braille_text_rx #(parameter integer CLK_HZ=50000000)(
 input wire clk,rst_n,enable,byte_valid,byte_error,
 input wire[7:0] byte_data,
 output reg result_valid,output reg[4:0] cell_count,
 output reg[95:0] cells
);
 localparam IDLE=0,R=1,L=2,COMMA=3,COUNT=4,DOTS=5,E=6,N=7,D=8,LF=9,AFTER_CR=10;
 reg[3:0] state;
 reg[4:0] count,index;
 reg count_digit,token,zero;
 reg[2:0] last_dot;
 reg[5:0] mask;
 reg[95:0] work;
 reg[31:0] timeout;
 wire digit=byte_data>=8'h30&&byte_data<=8'h39;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin state<=IDLE;result_valid<=0;cell_count<=0;cells<=0;
   count<=0;index<=0;count_digit<=0;token<=0;zero<=0;last_dot<=0;mask<=0;work<=0;timeout<=0;end
  else begin
   result_valid<=0;
   if(!enable||byte_error)begin state<=IDLE;timeout<=0;end
   else if(state!=IDLE&&timeout>=CLK_HZ/10)begin state<=IDLE;timeout<=0;end
   else begin
    if(state!=IDLE)timeout<=timeout+1;
    if(byte_valid)begin
     timeout<=0;
     // Any new B restarts synchronization, including after malformed lines.
     if(byte_data=="B")begin state<=R;count<=0;index<=0;count_digit<=0;work<=0;end
     else case(state)
      IDLE:;
      R:state<=(byte_data=="R")?L:IDLE;
      L:state<=(byte_data=="L")?COMMA:IDLE;
      COMMA:state<=(byte_data==",")?COUNT:IDLE;
      COUNT:begin
       if(digit&&(!count_digit||(count==1))&&((count*10+byte_data-48)<=16))begin
        count<=count*10+byte_data-48;count_digit<=1;
       end else if(byte_data==","&&count_digit&&count!=0)begin
        state<=DOTS;token<=0;zero<=0;last_dot<=0;mask<=0;
       end else state<=IDLE;
      end
      DOTS:begin
       if(byte_data=="0"&&!token)begin token<=1;zero<=1;end
       else if(byte_data>="1"&&byte_data<="6"&&!zero&&(byte_data-48)>last_dot)begin
        token<=1;last_dot<=byte_data-48;mask<=mask|(6'b1<<(byte_data-49));
       end else if(byte_data==","&&token)begin
        work[index*6+:6]<=mask;index<=index+1;
        token<=0;zero<=0;last_dot<=0;mask<=0;
        if(index+1==count)state<=E;
       end else state<=IDLE;
      end
      E:state<=(byte_data=="E")?N:IDLE;
      N:state<=(byte_data=="N")?D:IDLE;
      D:state<=(byte_data=="D")?LF:IDLE;
      LF:begin
       if(byte_data==10)begin cells<=work;cell_count<=count;result_valid<=1;state<=IDLE;end
       else state<=(byte_data==13)?AFTER_CR:IDLE;
      end
      AFTER_CR:begin
       if(byte_data==10)begin cells<=work;cell_count<=count;result_valid<=1;end
       state<=IDLE;
      end
      default:state<=IDLE;
     endcase
    end
   end
  end
 end
endmodule
