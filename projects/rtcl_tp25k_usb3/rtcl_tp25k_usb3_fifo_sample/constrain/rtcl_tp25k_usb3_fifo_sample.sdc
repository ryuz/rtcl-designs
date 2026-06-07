# 50MHz
create_clock -name in_clk50 -period 20.000 -waveform {0 10.000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
create_clock -name ft601_clk -period 10.000 -waveform {0 5.000} [get_ports {ft601_clk}] -add

# clock_groups
set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {ft601_clk}]

#create_generated_clock -name ft601_rx_clk -source [get_ports {ft601_clk}] -phase   0 [get_nets {ft601_rx_clk}]
#create_generated_clock -name ft601_tx_clk -source [get_ports {ft601_clk}] -phase 270 [get_nets {ft601_tx_clk}]
#set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {ft601_clk ft601_rx_clk ft601_tx_clk}]

#set_input_delay -clock ft601_clk -min -3.0 [get_ports ft601_rxf_n]
#set_input_delay -clock ft601_clk -max  3.5 [get_ports ft601_rxf_n]

#set_input_delay -clock ft601_clk -min -3.0 [get_ports ft601_txe_n]
#set_input_delay -clock ft601_clk -max  3.5 [get_ports ft601_txe_n]

#set_input_delay -clock ft601_clk -min -3.0 [get_ports {ft601_data[*]}]
#set_input_delay -clock ft601_clk -max  3.5 [get_ports {ft601_data[*]}]