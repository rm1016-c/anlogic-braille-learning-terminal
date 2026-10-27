// Frame: ASCII IMG1, count byte 1..16, count*64*96 RGB565 big endian,
// additive sum16(count+all payload bytes), big endian, CR LF.
// Only a fully checked frame publishes computed masks. No entire-frame RAM.
module braille_image_rx #(parameter integer CLK_HZ=50000000)(
 input wire clk,rst_n,enable,byte_valid,byte_error,input wire[7:0]byte_data,
 output wire active,output reg result_valid,output reg frame_error,
 output reg[4:0]cell_count,output reg[95:0]cells
);
 localparam IDLE=0,M=1,G=2,ONE=3,COUNT=4,PAYLOAD=5,CS_H=6,CS_L=7,CR=8,LF=9,COMMIT=10;
 reg[3:0]state;
 reg[31:0]timeout;
 reg[4:0]count,index,completed;
 reg[12:0]pixel_index;
 reg half;
 reg[7:0]high_byte;
 reg[15:0]checksum,received_checksum;
 reg[95:0]work;
 reg core_start,pixel_valid;
 reg[15:0]pixel;
 wire core_done;wire[5:0]core_mask;
 assign active=state!=IDLE;
 braille_image_core core(.clk(clk),.rst_n(rst_n),.start(core_start),
  .pixel_valid(pixel_valid),.pixel(pixel),.done(core_done),.dot_mask(core_mask));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;timeout<=0;count<=0;index<=0;completed<=0;pixel_index<=0;
   half<=0;high_byte<=0;checksum<=0;received_checksum<=0;work<=0;
   core_start<=0;pixel_valid<=0;pixel<=0;result_valid<=0;frame_error<=0;cell_count<=0;cells<=0;
  end else begin
   result_valid<=0;frame_error<=0;core_start<=0;pixel_valid<=0;
   if(!enable||byte_error)begin
    if(enable&&active)frame_error<=1;
    state<=IDLE;timeout<=0;
   end else if(active&&timeout>=CLK_HZ/10)begin state<=IDLE;frame_error<=1;timeout<=0;end
   else begin
    if(active)timeout<=timeout+1;
    if(core_done&&active&&completed<count)begin
     work[completed*6+:6]<=core_mask;completed<=completed+1'b1;
    end
    if(state==COMMIT&&completed==count)begin
     cells<=work;cell_count<=count;result_valid<=1;state<=IDLE;
    end
    if(byte_valid)begin
     timeout<=0;
     case(state)
      IDLE:if(byte_data=="I")state<=M;
      M:if(byte_data=="M")state<=G;else begin state<=IDLE;frame_error<=1;end
      G:if(byte_data=="G")state<=ONE;else begin state<=IDLE;frame_error<=1;end
      ONE:if(byte_data=="1")state<=COUNT;else begin state<=IDLE;frame_error<=1;end
      COUNT:if(byte_data>=1&&byte_data<=16)begin
       count<=byte_data;index<=0;completed<=0;pixel_index<=0;half<=0;work<=0;
       checksum<=byte_data;core_start<=1;state<=PAYLOAD;
      end else begin state<=IDLE;frame_error<=1;end
      PAYLOAD:begin
       checksum<=checksum+byte_data;
       if(!half)begin
        high_byte<=byte_data;half<=1;
        if(pixel_index==0&&index!=0)core_start<=1;
       end else begin
        pixel<={high_byte,byte_data};pixel_valid<=1;half<=0;
        if(pixel_index==6143)begin
         pixel_index<=0;index<=index+1'b1;
         if(index+1==count)state<=CS_H;
        end else pixel_index<=pixel_index+1'b1;
       end
      end
      CS_H:begin received_checksum[15:8]<=byte_data;state<=CS_L;end
      CS_L:if({received_checksum[15:8],byte_data}==checksum)state<=CR;
       else begin state<=IDLE;frame_error<=1;end
      CR:if(byte_data==13)state<=LF;else begin state<=IDLE;frame_error<=1;end
      LF:if(byte_data==10)state<=COMMIT;else begin state<=IDLE;frame_error<=1;end
      default:;
     endcase
    end
   end
  end
 end
endmodule
