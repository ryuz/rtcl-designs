// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none

module rtcl_p3s7_hs_dphy_recv
        #(
            parameter   int     X_BITS         = 10                         ,
            parameter   type    x_t            = logic  [X_BITS-1:0]        ,
            parameter   int     Y_BITS         = 10                         ,
            parameter   type    y_t            = logic  [Y_BITS-1:0]        ,

            parameter   int     CHANNELS       = 1                          ,
            parameter   int     RAW_BITS       = 10                         ,
            parameter   int     DPHY_LANES     = 2                          ,
            parameter           DEBUG          = "false"                    
        )
        (
            input   var x_t                             param_black_width   ,
            input   var y_t                             param_black_height  ,
            input   var x_t                             param_image_width   ,
            input   var y_t                             param_image_height  ,

            input   var logic                           dphy_reset          ,
            input   var logic                           dphy_clk            ,
            input   var logic   [DPHY_LANES-1:0][7:0]   dphy_data           ,
            input   var logic                           dphy_valid          ,

            jelly3_axi4s_if.m                           m_axi4s_black       ,
            jelly3_axi4s_if.m                           m_axi4s_image       ,

            output  var logic   [DPHY_LANES-1:0][7:0]   header_data         ,
            output  var logic                           header_valid        
        );

    logic       aresetn     ;
    logic       aclk        ;
    logic       aclken      ;
    assign aresetn = m_axi4s_image.aresetn    ;
    assign aclk    = m_axi4s_image.aclk       ;
    assign aclken  = m_axi4s_image.aclken     ;

    logic   [0:0]   axi4s_img_tuser      /*verilator public_flat*/;
    logic           axi4s_img_tlast      /*verilator public_flat*/;
    logic   [9:0]   axi4s_img_tdata      /*verilator public_flat*/;
    logic           axi4s_img_tvalid     /*verilator public_flat*/;
    logic           axi4s_img_tready     /*verilator public_flat*/;

    assign m_axi4s_image.tuser  = axi4s_img_tuser   ;
    assign m_axi4s_image.tlast  = axi4s_img_tlast   ;
    assign m_axi4s_image.tdata  = axi4s_img_tdata   ;
    assign m_axi4s_image.tvalid = axi4s_img_tvalid  ;
    assign axi4s_img_tready = m_axi4s_image.tready  ;

endmodule

`default_nettype wire

// end of file
