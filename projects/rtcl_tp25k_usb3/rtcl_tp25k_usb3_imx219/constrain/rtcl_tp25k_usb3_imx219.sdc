# 50MHz
create_clock -name in_clk50 -period 20.000 -waveform {0 10.000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
#create_clock -name ft601_clk -period 10.000 -waveform {0 5.000} [get_ports {ft601_clk}] -add
create_clock -name ft601_clk -period 15.000 -waveform {0 7.500} [get_ports {ft601_clk}] -add

# 458MHz (916Mbps/DDR)
create_clock -name mipi_ck_p -period 2.1834 -waveform {0 1.0917} [get_ports {mipi_ck_p}] -add

# 114MHz
create_clock -name dphy_clk -period 8.7719 -waveform {0 4.3860} [get_pins {u_mipi_dphy/mipi_dphy_inst/RX_CLK_O}] -add

# PLL (50MHz -> 100MHz)
create_generated_clock -name clk -source [get_ports {in_clk50}] -multiply_by 2 [get_pins {u_gowin_pll/u_pll/PLLA_inst/CLKOUT0}]


# clock_groups
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {ft601_clk}] -group [get_clocks {dphy_clk}]

# FT601
set_input_delay -clock ft601_clk  3.0 -min [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
set_input_delay -clock ft601_clk  3.5 -max [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]

set_output_delay -clock ft601_clk 3.0 -min [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
set_output_delay -clock ft601_clk 3.0 -max [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
