# 50MHz
create_clock -name in_clk50 -period 20.000 -waveform {0 10.000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
create_clock -name ft601_clk -period 10.000 -waveform {0 5.000} [get_ports {ft601_clk}] -add

# clock_groups
set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {ft601_clk}]

# FT601
set_input_delay -clock ft601_clk  3.0 -min [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
set_input_delay -clock ft601_clk  3.5 -max [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
