create_clock -name sys_clk -period 20 [get_ports sys_clk]
create_clock -name aud_bclk -period 83.333 [get_ports aud_bclk]
derive_clocks
# UART is asynchronous; RTL samples it through a two-flop synchronizer.
set_false_path -from [get_ports uart_rx]
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks aud_bclk]
set_input_delay -clock sys_clk -max 5 [get_ports {matrix_row_n[*]}]
set_input_delay -clock sys_clk -min 0 [get_ports {matrix_row_n[*]}]
set_input_delay -clock aud_bclk -clock_fall -max 10 [get_ports aud_lrc]
set_input_delay -clock aud_bclk -clock_fall -min 0 [get_ports aud_lrc]
set_output_delay -clock aud_bclk -max 10 [get_ports aud_dacdat]
set_output_delay -clock aud_bclk -min 0 [get_ports aud_dacdat]
