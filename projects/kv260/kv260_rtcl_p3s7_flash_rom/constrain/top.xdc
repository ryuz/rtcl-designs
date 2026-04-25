
# Fan
set_property PACKAGE_PIN A12 [get_ports fan_en]
set_property IOSTANDARD LVCMOS33 [get_ports fan_en]

# MIPI
#set_property PACKAGE_PIN D7 [get_ports cam_clk_p]
#set_property PACKAGE_PIN D6 [get_ports cam_clk_n]
#set_property PACKAGE_PIN E5 [get_ports {cam_data_p[0]}]
#set_property PACKAGE_PIN D5 [get_ports {cam_data_n[0]}]
#set_property PACKAGE_PIN G6 [get_ports {cam_data_p[1]}]
#set_property PACKAGE_PIN F6 [get_ports {cam_data_n[1]}]

set_property PACKAGE_PIN G11 [get_ports cam_scl]
set_property PACKAGE_PIN F10 [get_ports cam_sda]
set_property IOSTANDARD LVCMOS33 [get_ports cam_scl]
set_property IOSTANDARD LVCMOS33 [get_ports cam_sda]

set_property PACKAGE_PIN F11 [get_ports cam_gpio0]
set_property IOSTANDARD LVCMOS33 [get_ports cam_gpio0]
set_property DRIVE 12 [get_ports cam_gpio0]
set_property PACKAGE_PIN J12 [get_ports cam_gpio1]
set_property IOSTANDARD LVCMOS33 [get_ports cam_gpio1]
set_property DRIVE 4 [get_ports cam_gpio1]

