// Raw RX transition detector, independent of baud rate and UART framing.
// Arm after 1024 clocks so reset synchronizer fill cannot trigger the latch.
module uart_activity_diag(
 input wire clk,rst_n,rx,
 output reg edge_seen
);
 (* ASYNC_REG="TRUE" *) reg [1:0] rx_sync;
 reg last_rx;
 reg [10:0] arm_count;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin
   rx_sync<=2'b11;last_rx<=1'b1;arm_count<=0;edge_seen<=0;
  end else begin
   rx_sync<={rx_sync[0],rx};last_rx<=rx_sync[1];
   if(!arm_count[10])arm_count<=arm_count+1'b1;
   else if(rx_sync[1]!=last_rx)edge_seen<=1'b1;
  end
 end
endmodule
