write_cfgmem -format mcs -interface spix4 -loadbit "up 0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.mcs -force
write_cfgmem -format bin -interface spix4 -loadbit "up 0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bin -force
write_cfgmem -format mcs -interface spix4 -loadbit "up 0x100000 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_update.mcs -force
