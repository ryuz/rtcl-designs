// ---------------------------------------------------------------------------
//  Real-time Computing Lab Sample Program
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module image_processing
        #(
            parameter   int     WIDTH_BITS  = 8                             ,
            parameter   int     HEIGHT_BITS = 8                             ,
            parameter   type    width_t     = logic [WIDTH_BITS-1:0]        ,
            parameter   type    height_t    = logic [HEIGHT_BITS-1:0]       ,
            parameter   int     TAPS        = 1                             ,
            parameter   int     RAW_BITS    = 10                            ,
            parameter   type    raw_t       = logic [RAW_BITS-1:0]          ,
            parameter   int     MAX_COLS    = 4096                          ,
            parameter           RAM_TYPE    = "block"                       ,
            parameter   bit     BYPASS_SIZE = 1'b1                          ,
            parameter           DEVICE      = "RTL"                     
        )
        (
            input   var logic                       in_update_req   ,
            input   var width_t                     param_width     ,
            input   var height_t                    param_height    ,

            jelly3_axi4s_if.s                       s_axi4s         ,
            jelly3_axi4s_if.m                       m_axi4s         
        );


    // ----------------------------------------
    //  local patrameter
    // ----------------------------------------

    localparam  int     ROWS_BITS  = $bits(height_t);
    localparam  int     COLS_BITS  = $bits(width_t);
    localparam  type    rows_t     = logic [ROWS_BITS-1:0];
    localparam  type    cols_t     = logic [COLS_BITS-1:0];


    // -------------------------------------
    //  AXI4-Stream <=> Image Interface
    // -------------------------------------

    logic           reset ;
    logic           clk   ;
    logic           cke   ;
    assign  reset = ~s_axi4s.aresetn;
    assign  clk   = s_axi4s.aclk;
    
    jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    ($bits(raw_t)   ),
                .CH_DEPTH   (1              )
            )
        img_src
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );

   jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    ($bits(raw_t)   ),
                .CH_DEPTH   (3              )
            )
        img_sink
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );
    
    jelly3_axi4s_mat
            #(
                .ROWS_BITS      ($bits(rows_t)  ),
                .COLS_BITS      ($bits(cols_t)  ),
                .BLANK_BITS     (4              ),
                .CKE_BUFG       (0              )
            )
        u_axi4s_mat
            (
                .param_rows     (param_height   ),
                .param_cols     (param_width    ),
                .param_blank    (4'd5           ),
                
                .s_axi4s        (s_axi4s        ),
                .m_axi4s        (m_axi4s        ),

                .out_cke        (cke            ),
                .m_mat          (img_src.m      ),
                .s_mat          (img_sink.s     )
        );
    
    
    // -------------------------------------
    //  縮小 ＆ RGB化
    // -------------------------------------
    
    img_rgb4x4_core
            #(
                .MAX_COLS       (MAX_COLS       ),
                .RAM_TYPE       (RAM_TYPE       ),
                .BORDER_MODE    ("NONE"         ),
                .BYPASS_SIZE    (BYPASS_SIZE    )
            )
        u_img_rgb4x4_core
            (
                .s_img          (img_src        ),
                .m_img          (img_sink       )
        );
    

endmodule


`default_nettype wire


// end of file
