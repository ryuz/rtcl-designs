write_cfgmem -format mcs -interface spix1 -loadbit "up 0x0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.mcs -force
write_cfgmem -format bin -interface spix1 -loadbit "up 0x0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.bin -force
