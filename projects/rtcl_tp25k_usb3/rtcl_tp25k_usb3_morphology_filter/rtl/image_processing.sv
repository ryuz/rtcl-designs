// ---------------------------------------------------------------------------
//  Jelly  -- the soft-core processor system
//   math
//
//                                 Copyright (C) 2008-2018 by Ryuji Fuchikami
//                                 https://github.com/ryuz/jelly.git
// ---------------------------------------------------------------------------



`timescale 1ns / 1ps
`default_nettype none


module image_processing
        #(
            parameter   int     WIDTH_BITS  = 16                            ,
            parameter   int     HEIGHT_BITS = 16                            ,
            parameter   type    width_t     = logic [WIDTH_BITS-1:0]        ,
            parameter   type    height_t    = logic [HEIGHT_BITS-1:0]       ,
            parameter   int     FILTER_NUM  = 4                             ,
            parameter   int     FILTER_ROWS = 3                             ,
            parameter   int     FILTER_COLS = 3                             ,
            parameter   int     TAPS        = 32                            ,
            parameter   int     MAX_COLS    = 512                           ,
            parameter           RAM_TYPE    = "block"                       ,
            parameter   bit     BYPASS_SIZE = 1'b1                          ,
            parameter           DEVICE      = "RTL"                     
        )
        (
            input   var logic                       in_update_req   ,
            input   var width_t                     param_width     ,
            input   var height_t                    param_height    ,

            jelly3_axi4s_if.s                       s_axi4s         ,
            jelly3_axi4s_if.m                       m_axi4s         ,

            jelly3_axi4l_if.s                       s_axi4l         
        );


    // ----------------------------------------
    //  local patrameter
    // ----------------------------------------

    localparam  int     ROWS_BITS  = $bits(height_t );
    localparam  int     COLS_BITS  = $bits(width_t  );
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
                .CH_BITS    (1              ),
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
                .CH_BITS    (1              ),
                .CH_DEPTH   (1              )
            )
        img_sink
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );
    
    localparam int  BLANK_LINES = (FILTER_ROWS) * FILTER_NUM + 2;
    localparam int  BLANK_BITS  = $clog2(BLANK_LINES+1);
    localparam type blank_t = logic [BLANK_BITS-1:0];
    jelly3_axi4s_mat
            #(
                .ROWS_BITS      ($bits(rows_t)          ),
                .COLS_BITS      ($bits(cols_t)          ),
                .BLANK_BITS     (BLANK_BITS             ),
                .CKE_BUFG       (0                      )
            )
        u_axi4s_mat
            (
                .param_rows     (param_height           ),
                .param_cols     (param_width            ),
                .param_blank    (blank_t'(BLANK_LINES)  ),
                
                .s_axi4s        (s_axi4s                ),
                .m_axi4s        (m_axi4s                ),

                .out_cke        (cke                    ),
                .m_mat          (img_src.m              ),
                .s_mat          (img_sink.s             )
        );
    
    
    // -------------------------------------
    //  Morphology filter
    // -------------------------------------
    
    jelly3_img_morphology_filter
            #(
                .NUM                    (FILTER_NUM     ),
                .N                      (FILTER_ROWS    ),
                .M                      (FILTER_COLS    ),
                .MAX_COLS               (MAX_COLS       ),
                .RAM_TYPE               (RAM_TYPE       ),
                .BYPASS_SIZE            (BYPASS_SIZE    ),
                .INIT_CTL_CONTROL       (2'b01          ),
                .INIT_PARAM_ENABLE      (4'b1111        ),
                .INIT_PARAM_DILATION    (4'b0110        ),
                .INIT_PARAM_FILTER      ('1             )
            )
        u_img_morphology_filter
            (
                .in_update_req          (in_update_req  ),
                
                .s_img                  (img_src.s      ),
                .m_img                  (img_sink.m     ),

                .s_axi4l                (s_axi4l        )
            );


endmodule



`default_nettype wire



// end of file
