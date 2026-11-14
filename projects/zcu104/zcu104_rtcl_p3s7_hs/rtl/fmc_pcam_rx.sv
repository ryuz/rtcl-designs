// ---------------------------------------------------------------------------
//  Real-time Computing Lab
//
//  Copyright (C) 2026 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fmc_pcam_rx
        #(
            parameter   int         LANES       = 2                         ,
            parameter               DEBUG       = "true"                    
        )
        (
            input   var logic                       reset       ,
            input   var logic                       clk         ,

            input   var logic                       clk_lp_p    ,
            input   var logic                       clk_lp_n    ,
            input   var logic                       clk_hs_p    ,
            input   var logic                       clk_hs_n    ,
            input   var logic   [LANES-1:0]         data_lp_p   ,
            input   var logic   [LANES-1:0]         data_lp_n   ,
            input   var logic   [LANES-1:0]         data_hs_p   ,
            input   var logic   [LANES-1:0]         data_hs_n   ,
            output  var logic                       clk_div_out ,
            output  var logic   [LANES-1:0][7:0]    data_out    
        );

    // -------------------------------------------------------------------------
    // 1. 入力バッファ (IBUFDS)
    // -------------------------------------------------------------------------

    logic                   rx_clk;
    logic                   clk_in_buf;
    logic   [LANES-1:0]     rx_data;
    IBUFDS
        u_ibufds_clk
            (
                .I  (clk_hs_p   ),
                .IB (clk_hs_n   ),
                .O  (rx_clk     )
            );

    // -------------------------------------------------------------------------
    // 2. 分周クロックの生成 (BUFGCE_DIV)
    // -------------------------------------------------------------------------
    logic   clk_div;

    BUFGCE
        u_bufgce
            (
                .I      (rx_clk      ),
                .CE     (1'b1        ),
                .O      (clk_in_buf  )
            );

    BUFGCE_DIV
            #(
                .BUFGCE_DIVIDE  (4)
            )
        u_bufgce_div
            (
                .I      (clk_in_buf ),
                .CE     (1'b1       ),
                .CLR    (1'b0       ),
                .O      (clk_div    )
            );

    assign clk_div_out = clk_div;


    // -------------------------------------------------------------------------
    // 3. 入力遅延調整 (IDELAYE3) ※オプション（COUNTモード指定）
    // -------------------------------------------------------------------------

    for ( genvar i = 0; i < LANES; i++ ) begin : ibufds_data_gen
        IBUFDS
            u_ibufds_data
                (
                    .I  (data_hs_p[i]   ),
                    .IB (data_hs_n[i]   ),
                    .O  (rx_data[i]     )
                );

        logic   data_delayed;
        
        /*
        IDELAYE3
                #(
                    .DELAY_SRC          ("IDATAIN"      ),
                    .DELAY_TYPE         ("FIXED"        ),
                    .DELAY_VALUE        (IDELAY_TAPS    ),
                    .REFCLK_FREQUENCY   (300.0          )
                )
            u_idelaye3
                (
                    .IDATAIN            (data_in_buf    ),
                    .DATAOUT            (data_delayed   ),
                    .CLK                (clk_div        ),
                    .CE                 (1'b0),
                    .INC                (1'b0),
                    .LOAD               (1'b0),
                    .CNTVALUEIN         (9'd0),
                    .CNTVALUEOUT        (),
                    .EN_VTC             (1'b0)  // クロック停止対応のためCOUNTモード（VTC無効）
                );
        */
        assign data_delayed = rx_data[i];


        // -------------------------------------------------------------------------
        // 4. ISERDESE3 インスタンス化 (DDR 1:8)
        // -------------------------------------------------------------------------

        ISERDESE3
                #(
                    .DATA_WIDTH         (8      ),  // 1:8 デシリアライズ
                    .IS_CLK_INVERTED    (1'b0   ),  // CLK 反転なし
                    .IS_CLK_B_INVERTED  (1'b1   ),  // CLK_B は CLK の反転として使用
                    .IS_RST_INVERTED    (1'b0   ),  // アクティブHIGHリセット
                    .SIM_DEVICE         ("ULTRASCALE_PLUS"),
                    .FIFO_ENABLE        ("FALSE")   // 内部FIFO不使用（低レイテンシ）
                )
            u_iserdese3
                (
                    .Q                  (data_out[i]    ),  // [7:0] 並列出力
                    .CLK                (clk_in_buf     ),  // 高速ビットクロック
                    .CLK_B              (clk_in_buf     ),  // IS_CLK_B_INVERTED で反転
                    .CLKDIV             (clk_div        ),  // 分周パラレルクロック
                    .D                  (data_delayed   ),  // 入力データ（IDELAY通過後）
                    .RST                (reset          ),  // リセット（クロック停止時はHIGH）
                    .FIFO_RD_CLK        (1'b0           ),
                    .FIFO_RD_EN         (1'b0           )
                );
    end


    // -------------------------------------------------------------------------
    // Debug
    // -------------------------------------------------------------------------

    logic                       tmp_clk_lp_p    ;
    logic                       tmp_clk_lp_n    ;
    logic   [LANES-1:0]         tmp_data_lp_p   ;
    logic   [LANES-1:0]         tmp_data_lp_n   ;
    logic   [LANES-1:0][7:0]    tmp_data_out    ;
    logic                       tmp_valid       ;
    
    jelly3_stream_fifo
            #(
                .ASYNC          (1          ),
                .PTR_BITS       (5          ),
                .DATA_BITS      (2+4+8*2    ),
                .RAM_TYPE       ("block"    ),
                .DOUT_REG       (1'b0       ),
                .DEVICE         ("RTL"      ),
                .SIMULATION     ("false"    ),
                .DEBUG          ("false"    )
            )
        u_stream_fifo
            (
                .s_reset        (reset      ),
                .s_clk          (clk_div    ),
                .s_cke          (1          ),
                .s_data         ({
                                    clk_lp_p    ,
                                    clk_lp_n    ,
                                    data_lp_p   ,
                                    data_lp_n   ,
                                    data_out    
                                }),
                .s_valid        (1'b1       ),
                .s_ready        (           ),
                .s_free_size    (           ),

                .m_reset        (reset      ),
                .m_clk          (clk        ),
                .m_cke          (1          ),
                .m_data         ({
                                    tmp_clk_lp_p    ,
                                    tmp_clk_lp_n    ,
                                    tmp_data_lp_p   ,
                                    tmp_data_lp_n   ,
                                    tmp_data_out    
                                }),
                .m_valid        (tmp_valid  ),
                .m_ready        (1'b1       ),
                .m_data_size    (           )
            );


    (* mark_debug="true" *) logic                       dbg_clk_lp_p    ;
    (* mark_debug="true" *) logic                       dbg_clk_lp_n    ;
    (* mark_debug="true" *) logic   [LANES-1:0]         dbg_data_lp_p   ;
    (* mark_debug="true" *) logic   [LANES-1:0]         dbg_data_lp_n   ;

    (* mark_debug="true" *) logic                       mon_clk_lp_p    ;
    (* mark_debug="true" *) logic                       mon_clk_lp_n    ;
    (* mark_debug="true" *) logic   [LANES-1:0]         mon_data_lp_p   ;
    (* mark_debug="true" *) logic   [LANES-1:0]         mon_data_lp_n   ;
    (* mark_debug="true" *) logic   [LANES-1:0][7:0]    mon_data_out    ;
    (* mark_debug="true" *) logic                       mon_valid       ;

    always_ff @( posedge clk ) begin
        dbg_clk_lp_p  <= clk_lp_p       ;
        dbg_clk_lp_n  <= clk_lp_n       ;
        dbg_data_lp_p <= data_lp_p      ;
        dbg_data_lp_n <= data_lp_n      ;

        mon_clk_lp_p  <= tmp_clk_lp_p   ;
        mon_clk_lp_n  <= tmp_clk_lp_n   ;
        mon_data_lp_p <= tmp_data_lp_p  ;
        mon_data_lp_n <= tmp_data_lp_n  ;
        mon_data_out  <= tmp_data_out   ;
        mon_valid     <= tmp_valid      ;
    end

endmodule


`default_nettype wire