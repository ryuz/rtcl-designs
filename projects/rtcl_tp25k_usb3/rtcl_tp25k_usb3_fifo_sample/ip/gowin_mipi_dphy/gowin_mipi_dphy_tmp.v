//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02_SP2
//IP Version: 1.0
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: A
//Created Time: Wed Jun 17 21:53:18 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_MIPI_DPHY your_instance_name(
        .rx_clk_o(rx_clk_o), //output rx_clk_o
        .d0ln_hsrxd(d0ln_hsrxd), //output [7:0] d0ln_hsrxd
        .d1ln_hsrxd(d1ln_hsrxd), //output [7:0] d1ln_hsrxd
        .d2ln_hsrxd(d2ln_hsrxd), //output [7:0] d2ln_hsrxd
        .d3ln_hsrxd(d3ln_hsrxd), //output [7:0] d3ln_hsrxd
        .d0ln_hsrxd_vld(d0ln_hsrxd_vld), //output d0ln_hsrxd_vld
        .d1ln_hsrxd_vld(d1ln_hsrxd_vld), //output d1ln_hsrxd_vld
        .d2ln_hsrxd_vld(d2ln_hsrxd_vld), //output d2ln_hsrxd_vld
        .d3ln_hsrxd_vld(d3ln_hsrxd_vld), //output d3ln_hsrxd_vld
        .di_lprx0_n(di_lprx0_n), //output di_lprx0_n
        .di_lprx0_p(di_lprx0_p), //output di_lprx0_p
        .di_lprx1_n(di_lprx1_n), //output di_lprx1_n
        .di_lprx1_p(di_lprx1_p), //output di_lprx1_p
        .di_lprx2_n(di_lprx2_n), //output di_lprx2_n
        .di_lprx2_p(di_lprx2_p), //output di_lprx2_p
        .di_lprx3_n(di_lprx3_n), //output di_lprx3_n
        .di_lprx3_p(di_lprx3_p), //output di_lprx3_p
        .ck_n(ck_n), //inout ck_n
        .ck_p(ck_p), //inout ck_p
        .d0_n(d0_n), //inout d0_n
        .d0_p(d0_p), //inout d0_p
        .d1_n(d1_n), //inout d1_n
        .d1_p(d1_p), //inout d1_p
        .d2_n(d2_n), //inout d2_n
        .d2_p(d2_p), //inout d2_p
        .d3_n(d3_n), //inout d3_n
        .d3_p(d3_p), //inout d3_p
        .lptxen_ln0(lptxen_ln0), //input lptxen_ln0
        .lptxen_ln1(lptxen_ln1), //input lptxen_ln1
        .lptxen_ln2(lptxen_ln2), //input lptxen_ln2
        .lptxen_ln3(lptxen_ln3), //input lptxen_ln3
        .do_lptx0_n(do_lptx0_n), //input do_lptx0_n
        .do_lptx1_n(do_lptx1_n), //input do_lptx1_n
        .do_lptx2_n(do_lptx2_n), //input do_lptx2_n
        .do_lptx3_n(do_lptx3_n), //input do_lptx3_n
        .do_lptx0_p(do_lptx0_p), //input do_lptx0_p
        .do_lptx1_p(do_lptx1_p), //input do_lptx1_p
        .do_lptx2_p(do_lptx2_p), //input do_lptx2_p
        .do_lptx3_p(do_lptx3_p), //input do_lptx3_p
        .hsrx_en_d0(hsrx_en_d0), //input hsrx_en_d0
        .hsrx_en_d1(hsrx_en_d1), //input hsrx_en_d1
        .hsrx_en_d2(hsrx_en_d2), //input hsrx_en_d2
        .hsrx_en_d3(hsrx_en_d3), //input hsrx_en_d3
        .hsrx_odten_d0(hsrx_odten_d0), //input hsrx_odten_d0
        .hsrx_odten_d1(hsrx_odten_d1), //input hsrx_odten_d1
        .hsrx_odten_d2(hsrx_odten_d2), //input hsrx_odten_d2
        .hsrx_odten_d3(hsrx_odten_d3), //input hsrx_odten_d3
        .lprx_en_d0(lprx_en_d0), //input lprx_en_d0
        .lprx_en_d1(lprx_en_d1), //input lprx_en_d1
        .lprx_en_d2(lprx_en_d2), //input lprx_en_d2
        .lprx_en_d3(lprx_en_d3), //input lprx_en_d3
        .rx_drst_n(rx_drst_n) //input rx_drst_n
    );

//--------Copy end-------------------
