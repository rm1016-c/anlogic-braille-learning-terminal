// 50MHz, 115200 8N1. Frame: AA, target 01..07, 55.
module recognition_uart #(parameter integer CLK_HZ=50000000, BAUD=115200)(
 input wire clk,rst_n,rx,
 output reg target_valid,output reg[2:0] target_id,
 output reg byte_valid, output reg[7:0] byte_data,
 output reg byte_error
);
 localparam integer BIT_CYCLES=CLK_HZ/BAUD;
 (* ASYNC_REG="TRUE" *) reg[1:0]rx_sync;
 reg[15:0]counter;
 reg[3:0]state;
 reg[7:0]data;
 reg[1:0]frame_state;
 reg[2:0]candidate;
 reg[23:0]frame_timeout;
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin rx_sync<=3;counter<=0;state<=0;data<=0;
   frame_state<=0;candidate<=0;frame_timeout<=0;target_valid<=0;target_id<=0;byte_valid<=0;byte_data<=0;byte_error<=0;end
  else begin
   rx_sync<={rx_sync[0],rx};target_valid<=0;byte_valid<=0;byte_error<=0;
   if(frame_state!=0)begin
    if(frame_timeout>=CLK_HZ/10)begin frame_state<=0;frame_timeout<=0;end
    else frame_timeout<=frame_timeout+1;
   end else frame_timeout<=0;
   if(state==0)begin
    if(!rx_sync[1])begin state<=1;counter<=BIT_CYCLES/2-1;end
   end else if(counter!=0)counter<=counter-1;
   else if(state==1)begin
    if(rx_sync[1])state<=0;
    else begin state<=2;counter<=BIT_CYCLES-1;end
   end else if(state<=9)begin
    data[state-2]<=rx_sync[1];state<=state+1;counter<=BIT_CYCLES-1;
   end else begin
    state<=0;
    if(rx_sync[1])begin
     byte_valid<=1;byte_data<=data;
     frame_timeout<=0;
     case(frame_state)
      0:if(data==8'hAA)frame_state<=1;
      1:begin
       if(data>=1&&data<=7)begin candidate<=data[2:0];frame_state<=2;end
       else frame_state<=(data==8'hAA)?1:0;
      end
      2:begin
       if(data==8'h55)begin target_id<=candidate;target_valid<=1;end
       frame_state<=(data==8'hAA)?1:0;
      end
      default:frame_state<=0;
     endcase
    end else begin frame_state<=0;byte_error<=1;end
   end
  end
 end
endmodule
