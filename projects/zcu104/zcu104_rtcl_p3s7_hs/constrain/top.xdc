################################
# Timing
################################


# cam_clk_p
create_clock -period 1.600 -name {cam_clk_hs_p[0]} -waveform {0.000 0.800} [get_ports {cam_clk_hs_p[0]}]


################################
# Pin assignments
################################

# MIPI(CH-A)
# set_property PACKAGE_PIN E18 [get_ports {cam_clk_lp_p[0]}]
# set_property PACKAGE_PIN E17 [get_ports {cam_clk_lp_n[0]}]
# set_property PACKAGE_PIN K19 [get_ports {cam_data_lp_p[0][0]}]
# set_property PACKAGE_PIN K18 [get_ports {cam_data_lp_n[0][0]}]
# set_property PACKAGE_PIN G18 [get_ports {cam_data_lp_p[0][1]}]
# set_property PACKAGE_PIN F18 [get_ports {cam_data_lp_n[0][1]}]
# set_property PACKAGE_PIN H18 [get_ports {cam_clk_hs_p[0]}]
# set_property PACKAGE_PIN H17 [get_ports {cam_clk_hs_n[0]}]
# set_property PACKAGE_PIN L15 [get_ports {cam_data_hs_p[0][0]}]
# set_property PACKAGE_PIN K15 [get_ports {cam_data_hs_n[0][0]}]
# set_property PACKAGE_PIN H19 [get_ports {cam_data_hs_p[0][1]}]
# set_property PACKAGE_PIN G19 [get_ports {cam_data_hs_n[0][1]}]
# set_property PACKAGE_PIN J15 [get_ports {cam_gpio[0]}]

# MIPI(CH-B)
set_property PACKAGE_PIN H16 [get_ports {cam_clk_lp_p[0]}]
set_property PACKAGE_PIN G16 [get_ports {cam_clk_lp_n[0]}]
set_property PACKAGE_PIN G15 [get_ports {cam_data_lp_p[0][0]}]
set_property PACKAGE_PIN F15 [get_ports {cam_data_lp_n[0][0]}]
set_property PACKAGE_PIN K17 [get_ports {cam_data_lp_p[0][1]}]
set_property PACKAGE_PIN J17 [get_ports {cam_data_lp_n[0][1]}]
set_property PACKAGE_PIN F17 [get_ports {cam_clk_hs_p[0]}]
set_property PACKAGE_PIN F16 [get_ports {cam_clk_hs_n[0]}]
set_property PACKAGE_PIN L20 [get_ports {cam_data_hs_p[0][0]}]
set_property PACKAGE_PIN K20 [get_ports {cam_data_hs_n[0][0]}]
set_property PACKAGE_PIN L17 [get_ports {cam_data_hs_p[0][1]}]
set_property PACKAGE_PIN L16 [get_ports {cam_data_hs_n[0][1]}]
set_property PACKAGE_PIN A13 [get_ports {cam_gpio[0]}]


set_property PACKAGE_PIN J16 [get_ports cam_pwup]
set_property PACKAGE_PIN C13 [get_ports cam_gpio_en]

set_property IOSTANDARD LVCMOS18 [get_ports {cam_clk_lp_n[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cam_clk_lp_p[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cam_data_lp_n[0][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cam_data_lp_n[0][0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cam_data_lp_p[0][1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cam_data_lp_p[0][0]}]

set_property IOSTANDARD LVDS [get_ports {cam_clk_hs_p[0]}]
set_property IOSTANDARD LVDS [get_ports {cam_data_hs_p[0][1]}]
set_property IOSTANDARD LVDS [get_ports {cam_data_hs_p[0][0]}]

set_property IOSTANDARD LVCMOS18 [get_ports {cam_gpio[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports cam_pwup]


# LED
set_property PACKAGE_PIN D5 [get_ports {led[0]}]
set_property PACKAGE_PIN D6 [get_ports {led[1]}]
set_property PACKAGE_PIN A5 [get_ports {led[2]}]
set_property PACKAGE_PIN B5 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# PUSH SWITCH
set_property PACKAGE_PIN B4 [get_ports {push_sw[0]}]
set_property PACKAGE_PIN C4 [get_ports {push_sw[1]}]
set_property PACKAGE_PIN B3 [get_ports {push_sw[2]}]
set_property PACKAGE_PIN C3 [get_ports {push_sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push_sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push_sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push_sw[3]}]

# DIP SWITCH
set_property PACKAGE_PIN E4 [get_ports {dip_sw[0]}]
set_property PACKAGE_PIN D4 [get_ports {dip_sw[1]}]
set_property PACKAGE_PIN F5 [get_ports {dip_sw[2]}]
set_property PACKAGE_PIN F4 [get_ports {dip_sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[3]}]
