// 50MHz system clock, 100kHz I2C, 7-bit address 0x10 (CE grounded).
// No clock stretching: ES8388 control port is the only slave on this bus.
// NACK is fatal until reset; never advertise ready after an unacknowledged write.
module es8388_init #(
 parameter CLK_HZ=50000000, parameter I2C_HZ=100000,
 parameter POWER_WAIT=2500000, parameter SETTLE_WAIT=5000000
)(
 input clk,input rst_n,inout scl,inout sda,
 output reg ready,output reg error,output reg [5:0] reg_index
);
 localparam DIV=CLK_HZ/(4*I2C_HZ), LAST_REG=24;
 reg [31:0] wait_count;
 reg [15:0] divider;
 reg [3:0] state;
 reg [1:0] phase;
 reg [4:0] bit_index;
 reg [23:0] packet;
 reg scl_low,sda_low,nack;
 reg [1:0] sda_sync;
 wire [15:0] reg_word;
 assign scl=scl_low ? 1'b0 : 1'bz;
 assign sda=sda_low ? 1'b0 : 1'bz;
 function [15:0] setting;
 input [5:0] index;
 begin
 case(index)
  0:setting=16'h0080; // software reset
  1:setting=16'h0016; // same ADC/DAC rate, reference on
  2:setting=16'h0100;
  3:setting=16'h0200;
  4:setting=16'h1904; // DAC muted during initialization
  5:setting=16'h0300; // retain known reference ADC power arrangement
  6:setting=16'h043C; // enable both output pairs
  7:setting=16'h0880; // master; automatic BCLK, 12MHz in USB-rate mode
  8:setting=16'h0900;
  9:setting=16'h0C00; // ADC 24bit I2S
 10:setting=16'h0D17; // ADC MCLK/750 =16kHz
 11:setting=16'h1000;
 12:setting=16'h1100;
 13:setting=16'h1700; // DAC 24bit I2S
 14:setting=16'h1817; // DAC MCLK/750 =16kHz
 15:setting=16'h1A00;
 16:setting=16'h1B00;
 17:setting=16'h27B8; // DAC to left mixer, analog bypass off
 18:setting=16'h2AB8; // DAC to right mixer, analog bypass off
 19:setting=16'h2B80; // common LRCK, use DAC LRCK
 20:setting=16'h2E18; // conservative analog output level
 21:setting=16'h2F18;
 22:setting=16'h3018;
 23:setting=16'h3118;
 24:setting=16'h1900; // unmute (FPGA still sends zero until ready)
 default:setting=16'h1904;
 endcase
 end
 endfunction
 assign reg_word=setting(reg_index);
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   ready<=0;error<=0;reg_index<=0;wait_count<=0;divider<=0;
   state<=0;phase<=0;bit_index<=23;packet<=0;
   scl_low<=0;sda_low<=0;nack<=0;sda_sync<=3;
  end else begin
   sda_sync<={sda_sync[0],sda};
   if(state==0) begin
    if(wait_count==POWER_WAIT-1) begin
     wait_count<=0;state<=1;divider<=0;
    end else wait_count<=wait_count+1'b1;
   end else if(state==7) begin
    if(wait_count==SETTLE_WAIT-1) begin ready<=1;state<=8;end
    else wait_count<=wait_count+1'b1;
   end else if(state!=8) begin
    if(divider==DIV-1) begin
     divider<=0;
     case(state)
     1:begin // start: both lines released before pulling SDA low
       if(sda_sync[1]!==1'b1) begin error<=1;state<=8;end
       else begin sda_low<=1;packet<={8'h20,reg_word};
         bit_index<=23;phase<=0;nack<=0;state<=2;end
     end
     2:begin scl_low<=1;state<=3;phase<=0;end
     3:begin
       case(phase)
        0:begin sda_low<=!packet[bit_index];phase<=1;end
        1:begin scl_low<=0;phase<=2;end
        2:phase<=3;
        3:begin scl_low<=1;phase<=0;
          if(bit_index[2:0]==0) state<=4;
          else bit_index<=bit_index-1'b1;
        end
       endcase
     end
     4:begin
       case(phase)
        0:begin sda_low<=0;phase<=1;end
        1:begin scl_low<=0;phase<=2;end
        2:begin nack<=sda_sync[1];phase<=3;end
        3:begin scl_low<=1;phase<=0;
          if(nack || bit_index==0) state<=5;
          else begin bit_index<=bit_index-1'b1;state<=3;end
        end
       endcase
     end
     5:begin // STOP: SDA low, then SCL high, then SDA high
       case(phase)
        0:begin sda_low<=1;phase<=1;end
        1:begin scl_low<=0;phase<=2;end
        2:begin sda_low<=0;phase<=3;end
        3:begin phase<=0;state<=6;end
       endcase
     end
     6:begin
       if(nack) begin error<=1;state<=8;end
       else if(reg_index==LAST_REG) begin wait_count<=0;state<=7;end
       else begin reg_index<=reg_index+1'b1;state<=1;end
     end
     default:begin error<=1;state<=8;end
     endcase
    end else divider<=divider+1'b1;
   end
  end
 end
endmodule
