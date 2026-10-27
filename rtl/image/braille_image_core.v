// 64x96 normalized RGB565 cell, raster scan. >=1 idle clock between pixels.
// Fixed ROI default centers: (16,16/48/80),(48,16/48/80), radius 4.
// 8-bit gray -> 3x3 mean -> dark-pixel threshold -> six parallel counters.
module braille_image_core #(
 parameter integer WIDTH=64,HEIGHT=96,GRAY_THRESHOLD=160,MIN_DARK=12
)(
 input wire clk,rst_n,start,pixel_valid,input wire[15:0]pixel,
 output reg done,output reg[5:0]dot_mask,
 output wire gray_valid,output wire[7:0]gray_debug
);
 wire[7:0]r={pixel[15:11],pixel[15:13]};
 wire[7:0]g={pixel[10:5],pixel[10:9]};
 wire[7:0]b={pixel[4:0],pixel[4:2]};
 wire[15:0]re={8'b0,r},ge={8'b0,g},be={8'b0,b};
 wire[15:0]weighted=(re<<6)+(re<<3)+(re<<2)+re+
   (ge<<7)+(ge<<4)+(ge<<2)+(ge<<1)+(be<<4)+(be<<3)+(be<<2)+be;
 reg gv,sv,fv;
 reg[7:0]gray,filtered;
 reg[11:0]sum;
 reg[6:0]x,y,sx,sy,fx,fy;
 reg[7:0]line1[0:WIDTH-1],line2[0:WIDTH-1];
 reg[7:0]a0,a1,m0,m1,c0,c1;
 reg[7:0]counts[0:5];
 integer i;integer cx,cy;
 assign gray_valid=gv;assign gray_debug=gray;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   gv<=0;sv<=0;fv<=0;done<=0;dot_mask<=0;gray<=0;filtered<=0;sum<=0;
   x<=0;y<=0;sx<=0;sy<=0;fx<=0;fy<=0;
   a0<=0;a1<=0;m0<=0;m1<=0;c0<=0;c1<=0;
   for(i=0;i<6;i=i+1)counts[i]<=0;
  end else if(start)begin
   gv<=0;sv<=0;fv<=0;done<=0;dot_mask<=0;x<=0;y<=0;
   a0<=0;a1<=0;m0<=0;m1<=0;c0<=0;c1<=0;
   for(i=0;i<6;i=i+1)counts[i]<=0;
  end else begin
   done<=0;gv<=pixel_valid;sv<=0;fv<=sv;
   if(pixel_valid)gray<=weighted[15:8];
   if(gv)begin
    line2[x]<=line1[x];line1[x]<=gray;
    a1<=a0;a0<=line2[x];m1<=m0;m0<=line1[x];c1<=c0;c0<=gray;
    if(x>=2&&y>=2)begin
     sum<={4'b0,a1}+{4'b0,a0}+{4'b0,line2[x]}+
          {4'b0,m1}+{4'b0,m0}+{4'b0,line1[x]}+
          {4'b0,c1}+{4'b0,c0}+{4'b0,gray};
     sx<=x-1;sy<=y-1;sv<=1;
    end
    if(x==WIDTH-1)begin x<=0;y<=y+1;end else x<=x+1;
   end
   if(sv)begin filtered<=sum/9;fx<=sx;fy<=sy;end
   if(fv)begin
    for(i=0;i<6;i=i+1)begin
     cx=(i<3)?16:48;cy=16+(i%3)*32;
     if(fx>=cx-4&&fx<=cx+4&&fy>=cy-4&&fy<=cy+4&&filtered<GRAY_THRESHOLD)
      counts[i]<=counts[i]+1'b1;
    end
    // Last filter center is outside all ROIs, so counters are final here.
    if(fx==WIDTH-2&&fy==HEIGHT-2)begin
     for(i=0;i<6;i=i+1)dot_mask[i]<=counts[i]>=MIN_DARK;
     done<=1;
    end
   end
  end
 end
endmodule
