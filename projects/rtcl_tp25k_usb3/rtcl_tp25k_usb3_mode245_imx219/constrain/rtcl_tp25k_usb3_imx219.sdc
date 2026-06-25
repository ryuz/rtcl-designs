# 50MHz
create_clock -name in_clk50 -period 20.0000 -waveform {0 10.0000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
create_clock -name ft601_clk -period 10.0000 -waveform {0 5.0000} [get_ports {ft601_clk}] -add

# 458MHz (916Mbps/DDR)
create_clock -name mipi_ck_p -period 2.1834 -waveform {0 1.0917} [get_ports {mipi_ck_p}] -add

# 114MHz
create_clock -name dphy_clk -period 8.7719 -waveform {0 4.3860} [get_pins {u_mipi_dphy/mipi_dphy_inst/RX_CLK_O}] -add

# PLL (50MHz -> 100MHz)
create_generated_clock -name clk -source [get_ports {in_clk50}] -multiply_by 2 [get_pins {u_gowin_pll/u_pll/PLLA_inst/CLKOUT0}]

# clock_groups
set_clock_groups -asynchronous -group [get_clocks {in_clk50 clk}] -group [get_clocks {ft601_clk}] -group [get_clocks {dphy_clk}]

#create_generated_clock -name ft601_rx_clk -source [get_ports {ft601_clk}] -phase   0 [get_nets {ft601_rx_clk}]
#create_generated_clock -name ft601_tx_clk -source [get_ports {ft601_clk}] -phase 270 [get_nets {ft601_tx_clk}]
#set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {ft601_clk ft601_rx_clk ft601_tx_clk}]

set_input_delay -clock ft601_clk  3.0 -min [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
set_input_delay -clock ft601_clk  3.5 -max [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]

set_output_delay -clock ft601_clk 1.0 -min [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
set_output_delay -clock ft601_clk 1.0 -max [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
