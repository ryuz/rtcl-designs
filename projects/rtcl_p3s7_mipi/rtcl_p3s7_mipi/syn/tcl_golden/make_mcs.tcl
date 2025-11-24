write_cfgmem -format mcs -interface spix4 -loadbit "up 0x0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.mcs -force
write_cfgmem -format bin -interface spix4 -loadbit "up 0x0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.bin -force

write_cfgmem -format mcs -interface spix4 -loadbit "up 0x0 rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit up 0x100000 ../tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit" -file rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_full.mcs -force
