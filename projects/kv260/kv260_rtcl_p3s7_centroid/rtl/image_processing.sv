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
            parameter   int     WIDTH_BITS  = 10                            ,
            parameter   int     HEIGHT_BITS = 9                             ,
            parameter   type    width_t     = logic [WIDTH_BITS-1:0]        ,
            parameter   type    height_t    = logic [HEIGHT_BITS-1:0]       ,
            parameter   int     TAPS        = 1                             ,
            parameter   int     RAW_BITS    = 10                            ,
            parameter   type    raw_t       = logic signed  [RAW_BITS-1:0]  ,
            parameter   int     CX_BITS     = 32                            ,
            parameter   type    cx_t        = logic signed  [CX_BITS-1:0]   ,
            parameter   int     CY_BITS     = 32                            ,
            parameter   type    cy_t        = logic signed  [CY_BITS-1:0]   ,
            parameter   int     M00_BITS    = 32                            ,
            parameter   type    m00_t       = logic [M00_BITS-1:0]          ,
            parameter   int     M10_BITS    = 32                            ,
            parameter   type    m10_t       = logic [M10_BITS-1:0]          ,
            parameter   int     M01_BITS    = 32                            ,
            parameter   type    m01_t       = logic [M01_BITS-1:0]          ,
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
            jelly3_axi4s_if.m                       m_axi4s         ,

            jelly3_axi4l_if.s                       s_axi4l         ,
            output  var logic                       out_irq         ,
            
            output  var cx_t                        m_centroid_x    ,
            output  var cy_t                        m_centroid_y    ,
            output  var logic                       m_centroid_valid,

            output  var m00_t                       m_moment_m00    ,
            output  var m10_t                       m_moment_m10    ,
            output  var m01_t                       m_moment_m01    ,
            output  var logic                       m_moment_valid   
        );


    // ----------------------------------------
    //  local patrameter
    // ----------------------------------------

    localparam  int     ROWS_BITS  = $bits(height_t);
    localparam  int     COLS_BITS  = $bits(width_t);
    localparam  type    rows_t     = logic [ROWS_BITS-1:0];
    localparam  type    cols_t     = logic [COLS_BITS-1:0];

    localparam  int     S_CH_BITS  = s_axi4s.DATA_BITS;
    localparam  int     M_CH_BITS  = m_axi4s.DATA_BITS;


    // ----------------------------------------
    //  Address decoder
    // ----------------------------------------
    
    localparam int DEC_GAUSS  = 0;
    localparam int DEC_CLAMP  = 1;
    localparam int DEC_RECT   = 2;
    localparam int DEC_MOMENT = 3;
    localparam int DEC_SEL    = 4;
    localparam int DEC_NUM    = 5;

    jelly3_axi4l_if
            #(
                .ADDR_BITS      (s_axi4l.ADDR_BITS  ),
                .DATA_BITS      (s_axi4l.DATA_BITS  )
            )
        axi4l_dec [DEC_NUM]
            (
                .aresetn        (s_axi4l.aresetn    ),
                .aclk           (s_axi4l.aclk       ),
                .aclken         (s_axi4l.aclken     )
            );
    
    // address map
    assign {axi4l_dec[DEC_GAUSS ].addr_base, axi4l_dec[DEC_GAUSS ].addr_high} = {40'ha040_1000, 40'ha040_1fff};
    assign {axi4l_dec[DEC_CLAMP ].addr_base, axi4l_dec[DEC_CLAMP ].addr_high} = {40'ha040_2000, 40'ha040_2fff};
    assign {axi4l_dec[DEC_RECT  ].addr_base, axi4l_dec[DEC_RECT  ].addr_high} = {40'ha040_3000, 40'ha040_3fff};
    assign {axi4l_dec[DEC_MOMENT].addr_base, axi4l_dec[DEC_MOMENT].addr_high} = {40'ha040_4000, 40'ha040_4fff};
    assign {axi4l_dec[DEC_SEL   ].addr_base, axi4l_dec[DEC_SEL   ].addr_high} = {40'ha040_f000, 40'ha040_ffff};

    jelly3_axi4l_addr_decoder
            #(
                .NUM            (DEC_NUM    ),
                .DEC_ADDR_BITS  (20         )
            )
        u_axi4l_addr_decoder
            (
                .s_axi4l        (s_axi4l    ),
                .m_axi4l        (axi4l_dec  )
            );
    

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
                .CH_BITS    (S_CH_BITS      ),
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
                .CH_BITS    (M_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_sink
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );
    
    jelly3_axi4s_mat
            #(
                .ROWS_BITS      ($bits(rows_t)      ),
                .COLS_BITS      ($bits(cols_t)      ),
                .BLANK_BITS     (4                  ),
                .CKE_BUFG       (0                  )
            )
        u_axi4s_mat
            (
                .param_rows     (param_height       ),
                .param_cols     (param_width        ),
                .param_blank    (4'd5               ),
                
                .s_axi4s        (s_axi4s            ),
                .m_axi4s        (m_axi4s            ),

                .out_cke        (cke                ),
                .m_mat          (img_src.m          ),
                .s_mat          (img_sink.s         )
        );
    
    
    // -------------------------------------
    //  Gaussian filter
    // -------------------------------------
    
    jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    (S_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_gauss
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );
    
    img_gaussian
            #(
                .NUM            (4                      ),
                .MAX_COLS       (1024                   ),
                .RAM_TYPE       ("block"                ),
                .BORDER_MODE    ("REPLICATE"            ),
                .BYPASS_SIZE    (1'b1                   ),
                .ROUND          (1'b1                   )
            )
        u_img_gaussian
            (
                .in_update_req  (in_update_req          ),

                .s_img          (img_src                ),
                .m_img          (img_gauss              ),
            
                .s_axi4l        (axi4l_dec[DEC_GAUSS]   )
        );
    
    // -------------------------------------
    //  clamp
    // -------------------------------------

    jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    (S_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_clamp
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );
    
    jelly3_mat_clamp
            #(
                .CALC_BITS          (RAW_BITS               ),
                .INIT_CTL_CONTROL   (2'b01                  ),
                .INIT_PARAM_MIN     ('0                     ),
                .INIT_PARAM_MAX     ('1                     )
            )
        u_mat_clamp
            (
                .in_update_req      (in_update_req          ),

                .s_mat              (img_gauss              ),
                .m_mat              (img_clamp              ),

                .s_axi4l            (axi4l_dec[DEC_CLAMP]   )
        );
    

    // -------------------------------------
    //  rect region
    // -------------------------------------
    jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    (S_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_rect
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
                .CH_BITS    (S_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_rect_trim
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
                .CH_BITS    (S_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_rect_org
            (
                .reset      (reset          ),
                .clk        (clk            ),
                .cke        (cke            )
            );


    jelly3_img_region_rect
            #(
                .X_BITS             ($bits(width_t)     ),
                .Y_BITS             ($bits(height_t)    ),
                .BYPASS_SIZE        (1'b1               ),
                .INIT_CTL_CONTROL   (2'b01              ),
                .INIT_PARAM_X       ('0                 ),
                .INIT_PARAM_Y       ('0                 ),
                .INIT_PARAM_WIDTH   ('1                 ),
                .INIT_PARAM_HEIGHT  ('1                 )
            )
        u_img_region_rect
            (
                .in_update_req      (in_update_req      ),

                .s_img              (img_clamp          ),
                .m_img              (img_rect_trim      ),
                .m_img_org          (img_rect_org       ),
                
                .s_axi4l            (axi4l_dec[DEC_RECT])
            );

    assign img_rect.rows      = img_rect_org.rows;
    assign img_rect.cols      = img_rect_org.cols;
    assign img_rect.row_first = img_rect_org.row_first;
    assign img_rect.row_last  = img_rect_org.row_last ;
    assign img_rect.col_first = img_rect_org.col_first;
    assign img_rect.col_last  = img_rect_org.col_last ;
    assign img_rect.de        = img_rect_org.de       ;
    assign img_rect.user      = img_rect_org.user     ;
    assign img_rect.data      = img_rect_trim.de ? img_rect_org.data : '0;
    assign img_rect.valid     = img_rect_org.valid    ;



    // -------------------------------------
    //  calc moment
    // -------------------------------------
    
    jelly3_img_moment
            #(
                .CH_DEPTH       (1                      ),
                .M00_BITS       ($bits(m00_t)           ),
                .m00_t          (m00_t                  ),
                .M10_BITS       ($bits(m10_t)           ),
                .m10_t          (m10_t                  ),
                .M01_BITS       ($bits(m01_t)           ),
                .m01_t          (m01_t                  )
            )
        u_img_moment
            (
                .s_mat          (img_rect               ),
                .s_axi4l        (axi4l_dec[DEC_MOMENT]  ),
                .out_irq        (out_irq                ),

                .m_out_x        (m_centroid_x           ),
                .m_out_y        (m_centroid_y           ),
                .m_out_valid    (m_centroid_valid       ),

                .m_moment_m00   ( m_moment_m00          ),
                .m_moment_m10   ( m_moment_m10          ),
                .m_moment_m01   ( m_moment_m01          ),
                .m_moment_valid ( m_moment_valid        )
            );



    // -------------------------------------
    //  output selector
    // -------------------------------------

    localparam int SEL_NUM = 4;

    jelly3_mat_if
            #(
                .TAPS       (TAPS           ),
                .ROWS_BITS  ($bits(rows_t)  ),
                .COLS_BITS  ($bits(cols_t)  ),
                .CH_BITS    (M_CH_BITS      ),
                .CH_DEPTH   (1              )
            )
        img_sel_s [SEL_NUM]
            (
                .reset      (img_sink.reset    ),
                .clk        (img_sink.clk      ),
                .cke        (img_sink.cke      )
            );

    jelly3_img_selector
            #(
                .NUM                (SEL_NUM            ),
                .INIT_CTL_SELECT    ('0                 )
            )
        u_img_selector
            (
                .s_img              (img_sel_s          ),
                .m_img              (img_sink           ),
                .s_axi4l            (axi4l_dec[DEC_SEL] )
            );
    
    assign img_sel_s[0].rows        = img_src.rows                  ;
    assign img_sel_s[0].cols        = img_src.cols                  ;
    assign img_sel_s[0].row_first   = img_src.row_first             ;
    assign img_sel_s[0].row_last    = img_src.row_last              ;
    assign img_sel_s[0].col_first   = img_src.col_first             ;
    assign img_sel_s[0].col_last    = img_src.col_last              ;
    assign img_sel_s[0].de          = img_src.de                    ;
    assign img_sel_s[0].data        = M_CH_BITS'(img_src.data[0][0]);
    assign img_sel_s[0].user        = img_src.user                  ;
    assign img_sel_s[0].valid       = img_src.valid                 ;

    assign img_sel_s[1].rows        = img_gauss.rows                ;
    assign img_sel_s[1].cols        = img_gauss.cols                ;
    assign img_sel_s[1].row_first   = img_gauss.row_first           ;
    assign img_sel_s[1].row_last    = img_gauss.row_last            ;
    assign img_sel_s[1].col_first   = img_gauss.col_first           ;
    assign img_sel_s[1].col_last    = img_gauss.col_last            ;
    assign img_sel_s[1].de          = img_gauss.de                  ;
    assign img_sel_s[1].data        = M_CH_BITS'(img_gauss.data)    ;
    assign img_sel_s[1].user        = img_gauss.user                ;
    assign img_sel_s[1].valid       = img_gauss.valid               ;

    assign img_sel_s[2].rows        = img_clamp.rows                ;
    assign img_sel_s[2].cols        = img_clamp.cols                ;
    assign img_sel_s[2].row_first   = img_clamp.row_first           ;
    assign img_sel_s[2].row_last    = img_clamp.row_last            ;
    assign img_sel_s[2].col_first   = img_clamp.col_first           ;
    assign img_sel_s[2].col_last    = img_clamp.col_last            ;
    assign img_sel_s[2].de          = img_clamp.de                  ;
    assign img_sel_s[2].data        = M_CH_BITS'(img_clamp.data)    ;
    assign img_sel_s[2].user        = img_clamp.user                ;
    assign img_sel_s[2].valid       = img_clamp.valid               ;

    assign img_sel_s[3].rows        = img_rect.rows             ;
    assign img_sel_s[3].cols        = img_rect.cols             ;
    assign img_sel_s[3].row_first   = img_rect.row_first        ;
    assign img_sel_s[3].row_last    = img_rect.row_last         ;
    assign img_sel_s[3].col_first   = img_rect.col_first        ;
    assign img_sel_s[3].col_last    = img_rect.col_last         ;
    assign img_sel_s[3].de          = img_rect.de               ;
    assign img_sel_s[3].data        = M_CH_BITS'(img_rect.data) ;
    assign img_sel_s[3].user        = img_rect.user             ;
    assign img_sel_s[3].valid       = img_rect.valid            ;

endmodule


`default_nettype wire



// end of file
