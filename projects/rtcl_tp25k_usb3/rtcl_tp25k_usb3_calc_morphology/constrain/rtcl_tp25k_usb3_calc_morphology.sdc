# 50MHz
create_clock -name in_clk50 -period 20.000 -waveform {0 10.000} [get_ports {in_clk50}] -add

# FT601(100MHz or 66MHz)
create_clock -name ft601_clk_in -period 10.000 -waveform {0 5.000} [get_ports {ft601_clk_in}] -add
#create_clock -name ft601_clk_in -period 15.000 -waveform {0 7.500} [get_ports {ft601_clk_in}] -add

# Sys PLL (50MHz -> 100MHz)
create_generated_clock -name clk -source [get_ports {in_clk50}] -multiply_by 2 [get_pins {u_gowin_pll/u_pll/PLLA_inst/CLKOUT0}]

# FT601 PLL
create_generated_clock -name ft601_clk -source [get_ports {ft601_clk_in}] -multiply_by 1 -phase 45 [get_pins {u_gowin_pll_ft601/u_pll/PLLA_inst/CLKOUT0}]

# clock_groups
set_clock_groups -asynchronous -group [get_clocks {in_clk50}] -group [get_clocks {clk}] -group [get_clocks {ft601_clk}]

# FT601
set_input_delay  -clock ft601_clk -min 1.0 [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
set_input_delay  -clock ft601_clk -max 9.0 [get_ports {ft601_rxf_n ft601_txe_n ft601_data[*] ft601_de[*]}]
set_output_delay -clock ft601_clk -min 0.0 [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
set_output_delay -clock ft601_clk -max 0.0 [get_ports {ft601_wr_n ft601_rd_n ft601_oe_n ft601_data[*] ft601_de[*]}]
