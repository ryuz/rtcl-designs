// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module kv260_rtcl_p3s7_flash_rom
        #(
            parameter   DEBUG = "false"
        )
        (
//          input   var logic           cam_clk_p   ,
//          input   var logic           cam_clk_n   ,
//          input   var logic   [1:0]   cam_data_p  ,
//          input   var logic   [1:0]   cam_data_n  ,
            inout   tri logic           cam_scl     ,
            inout   tri logic           cam_sda     ,
            output  var logic           cam_gpio0   ,
            output  var logic           cam_gpio1   ,
            
            output  var logic           fan_en      
        );
    

    // ----------------------------------------
    //  Zynq UltraScale+ MPSoC block
    // ----------------------------------------

    (* MARK_DEBUG=DEBUG *)  logic       i2c0_scl_i  ;
                            logic       i2c0_scl_o  ;
    (* MARK_DEBUG=DEBUG *)  logic       i2c0_scl_t  ;
    (* MARK_DEBUG=DEBUG *)  logic       i2c0_sda_i  ;
                            logic       i2c0_sda_o  ;
    (* MARK_DEBUG=DEBUG *)  logic       i2c0_sda_t  ;

    design_1
        u_design_1
            (
                .fan_en                 (fan_en     ),
                
                .i2c_scl_i              (i2c0_scl_i ),
                .i2c_scl_o              (i2c0_scl_o ),
                .i2c_scl_t              (i2c0_scl_t ),
                .i2c_sda_i              (i2c0_sda_i ),
                .i2c_sda_o              (i2c0_sda_o ),
                .i2c_sda_t              (i2c0_sda_t )
            );
    
    // I2C
    IOBUF
        u_iobuf_i2c0_scl
            (
                .I                      (i2c0_scl_o ),
                .O                      (i2c0_scl_i ),
                .T                      (i2c0_scl_t ),
                .IO                     (cam_scl    )
        );

    IOBUF
        u_iobuf_i2c0_sda
            (
                .I                      (i2c0_sda_o ),
                .O                      (i2c0_sda_i ),
                .T                      (i2c0_sda_t ),
                .IO                     (cam_sda    )
            );

    assign cam_gpio0 = 1'b1;    // enable
    
endmodule

`default_nettype wire

// end of file