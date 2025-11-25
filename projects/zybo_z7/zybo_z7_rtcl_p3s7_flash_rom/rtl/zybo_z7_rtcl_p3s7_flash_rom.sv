// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module zybo_z7_rtcl_p3s7_flash_rom
        (
         // input   var logic           cam_clk_hs_p        ,
         // input   var logic           cam_clk_hs_n        ,
         // input   var logic           cam_clk_lp_p        ,
         // input   var logic           cam_clk_lp_n        ,
         // input   var logic   [1:0]   cam_data_hs_p       ,
         // input   var logic   [1:0]   cam_data_hs_n       ,
         // input   var logic   [1:0]   cam_data_lp_p       ,
         // input   var logic   [1:0]   cam_data_lp_n       ,
            output  var logic           cam_gpio0           ,
         // output  var logic           cam_gpio1           ,
            inout   tri logic           cam_scl             ,
            inout   tri logic           cam_sda             ,
            
            inout   tri logic   [14:0]  DDR_addr            ,
            inout   tri logic   [2:0]   DDR_ba              ,
            inout   tri logic           DDR_cas_n           ,
            inout   tri logic           DDR_ck_n            ,
            inout   tri logic           DDR_ck_p            ,
            inout   tri logic           DDR_cke             ,
            inout   tri logic           DDR_cs_n            ,
            inout   tri logic   [3:0]   DDR_dm              ,
            inout   tri logic   [31:0]  DDR_dq              ,
            inout   tri logic   [3:0]   DDR_dqs_n           ,
            inout   tri logic   [3:0]   DDR_dqs_p           ,
            inout   tri logic           DDR_odt             ,
            inout   tri logic           DDR_ras_n           ,
            inout   tri logic           DDR_reset_n         ,
            inout   tri logic           DDR_we_n            ,
            inout   tri logic           FIXED_IO_ddr_vrn    ,
            inout   tri logic           FIXED_IO_ddr_vrp    ,
            inout   tri logic   [53:0]  FIXED_IO_mio        ,
            inout   tri logic           FIXED_IO_ps_clk     ,
            inout   tri logic           FIXED_IO_ps_porb    ,
            inout   tri logic           FIXED_IO_ps_srstb   
        );
    
    logic           IIC_0_0_scl_i       ;
    logic           IIC_0_0_scl_o       ;
    logic           IIC_0_0_scl_t       ;
    logic           IIC_0_0_sda_i       ;
    logic           IIC_0_0_sda_o       ;
    logic           IIC_0_0_sda_t       ;

    design_1
        u_design_1
            (
                .DDR_addr               (DDR_addr           ),
                .DDR_ba                 (DDR_ba             ),
                .DDR_cas_n              (DDR_cas_n          ),
                .DDR_ck_n               (DDR_ck_n           ),
                .DDR_ck_p               (DDR_ck_p           ),
                .DDR_cke                (DDR_cke            ),
                .DDR_cs_n               (DDR_cs_n           ),
                .DDR_dm                 (DDR_dm             ),
                .DDR_dq                 (DDR_dq             ),
                .DDR_dqs_n              (DDR_dqs_n          ),
                .DDR_dqs_p              (DDR_dqs_p          ),
                .DDR_odt                (DDR_odt            ),
                .DDR_ras_n              (DDR_ras_n          ),
                .DDR_reset_n            (DDR_reset_n        ),
                .DDR_we_n               (DDR_we_n           ),
                .FIXED_IO_ddr_vrn       (FIXED_IO_ddr_vrn   ),
                .FIXED_IO_ddr_vrp       (FIXED_IO_ddr_vrp   ),
                .FIXED_IO_mio           (FIXED_IO_mio       ),
                .FIXED_IO_ps_clk        (FIXED_IO_ps_clk    ),
                .FIXED_IO_ps_porb       (FIXED_IO_ps_porb   ),
                .FIXED_IO_ps_srstb      (FIXED_IO_ps_srstb  ),
                
                .IIC_0_0_scl_i          (IIC_0_0_scl_i      ),
                .IIC_0_0_scl_o          (IIC_0_0_scl_o      ),
                .IIC_0_0_scl_t          (IIC_0_0_scl_t      ),
                .IIC_0_0_sda_i          (IIC_0_0_sda_i      ),
                .IIC_0_0_sda_o          (IIC_0_0_sda_o      ),
                .IIC_0_0_sda_t          (IIC_0_0_sda_t      )
            );
    
    IOBUF
        u_IOBUF_cam_scl
            (
                .IO     (cam_scl        ),
                .I      (IIC_0_0_scl_o  ),
                .O      (IIC_0_0_scl_i  ),
                .T      (IIC_0_0_scl_t  )
            );

    IOBUF
        u_iobuf_cam_sda
            (
                .IO     (cam_sda        ),
                .I      (IIC_0_0_sda_o  ),
                .O      (IIC_0_0_sda_i  ),
                .T      (IIC_0_0_sda_t  )
            );
    
    assign cam_gpio0 = 1'b1;    // enable
    
endmodule

`default_nettype wire

// end of file