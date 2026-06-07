//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02_SP2 (64-bit)
//IP Version: 1.0
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: B
//Created Time: Sun Jun  7 12:51:36 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    ft601_pll_MOD your_instance_name(
        .lock(lock), //output lock
        .clkout0(clkout0), //output clkout0
        .clkout1(clkout1), //output clkout1
        .mdrdo(mdrdo), //output [7:0] mdrdo
        .clkin(clkin), //input clkin
        .reset(reset), //input reset
        .pllpwd(pllpwd), //input pllpwd
        .mdclk(mdclk), //input mdclk
        .mdopc(mdopc), //input [1:0] mdopc
        .mdainc(mdainc), //input mdainc
        .mdwdi(mdwdi) //input [7:0] mdwdi
    );

//--------Copy end-------------------
