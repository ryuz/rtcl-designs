# 50MHz
create_clock -name in_clk50 -period 20.000 -waveform {0 10.000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
create_clock -name ft601_clk -period 10.000 -waveform {0 5.000} [get_ports {ft601_clk}] -add

# clock_groups
set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {ft601_clk}]