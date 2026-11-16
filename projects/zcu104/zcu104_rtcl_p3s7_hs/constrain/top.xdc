################################
# Timing
################################


# cam_clk_p
create_clock -period 1.600 -name {cam_clk_hs_p[0]} -waveform {0.000 0.800} [get_ports {cam_clk_hs_p[0]}]


################################
# Pin assignments
################################

# MIPI
set_property PACKAGE_PIN F17 [get_ports {cam_clk_lp_p[0]}]
set_property PACKAGE_PIN F16 [get_ports {cam_clk_lp_n[0]}]
set_property PACKAGE_PIN K19 [get_ports {cam_data_lp_p[0][0]}]
set_property PACKAGE_PIN K18 [get_ports {cam_data_lp_n[0][0]}]
set_property PACKAGE_PIN G18 [get_ports {cam_data_lp_p[0][1]}]
set_property PACKAGE_PIN F18 [get_ports {cam_data_lp_n[0][1]}]

set_property PACKAGE_PIN H18 [get_ports {cam_clk_hs_p[0]}]
set_property PACKAGE_PIN H17 [get_ports {cam_clk_hs_n[0]}]
set_property PACKAGE_PIN L15 [get_ports {cam_data_hs_p[0][0]}]
set_property PACKAGE_PIN K15 [get_ports {cam_data_hs_n[0][0]}]
set_property PACKAGE_PIN H19 [get_ports {cam_data_hs_p[0][1]}]
set_property PACKAGE_PIN G19 [get_ports {cam_data_hs_n[0][1]}]

set_property PACKAGE_PIN J15 [get_ports {cam_gpio[0]}]
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
