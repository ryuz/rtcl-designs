#!/bin/bash

# normal model
make -C ../tcl
cp ../tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit .
cp ../tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.mcs .
cp ../tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bin .
cp ../tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_update.mcs .

# golden model
make -C ../tcl_golden
cp ../tcl_golden/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bit ./rtcl_p3s7_mipi_golden.bit
cp ../tcl_golden/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.mcs .
cp ../tcl_golden/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden.bin .

# golden full model
cp ../tcl_golden/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden_full.mcs .
cp ../tcl_golden/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_golden_full.bin .

# Camera Module V1
make -C ../tcl_spix1
cp ../tcl_spix1/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_spix1.bin .
cp ../tcl_spix1/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi_spix1.mcs .
