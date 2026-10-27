// 50MHz / 5 * 6 = 60MHz feedback; VCO=600MHz; C1=600/50=12MHz.
// Device primitive settings must pass TD PLL legality checks.
module audio_pll(input clk50,input reset,output mclk,output locked);
 wire feedback_raw,feedback;
 wire [2:0] unused_clocks;
 EG_LOGIC_BUFG fb_buf(.i(feedback_raw),.o(feedback));
 EG_PHY_PLL #(
 .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.FIN("50.000"),
 .FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC0_EXT"),
 .STDBY_ENABLE("ENABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
 .GMC_GAIN(4),.ICP_CURRENT(13),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(4),
 .REFCLK_DIV(5),.FBCLK_DIV(6),
 .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(10),.CLKC0_CPHASE(9),.CLKC0_FPHASE(0),
 .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(50),.CLKC1_CPHASE(49),.CLKC1_FPHASE(0)
 ) pll(.refclk(clk50),.reset(reset),.stdby(1'b0),.extlock(locked),
 .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b0),
 .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),
 .fbclk(feedback),.clkc({unused_clocks,mclk,feedback_raw}));
endmodule
