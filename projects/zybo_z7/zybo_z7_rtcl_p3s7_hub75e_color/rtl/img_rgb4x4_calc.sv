// ---------------------------------------------------------------------------
//  Real-time Computing Lab Sample Program
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module img_rgb4x4_calc
        #(
            parameter   int   ROWS_BITS  = 16                                   ,
            parameter   type  rows_t     = logic    [ROWS_BITS-1:0]             ,
            parameter   int   COLS_BITS  = 16                                   ,
            parameter   type  cols_t     = logic    [COLS_BITS-1:0]             ,
            parameter   int   DE_BITS    = 1                                    ,
            parameter   type  de_t       = logic    [DE_BITS-1:0]               ,
            parameter   int   USER_BITS  = 1                                    ,
            parameter   type  user_t     = logic    [USER_BITS-1:0]             ,
            parameter   int   S_RAW_BITS = 10                                   ,
            parameter   type  s_raw_t    = logic    [S_RAW_BITS-1:0]            ,
            parameter   int   M_RAW_BITS = 10                                   ,
            parameter   type  m_raw_t    = logic    [M_RAW_BITS-1:0]            ,
            parameter   int   SHIFT      = $bits(s_raw_t) + 4 - $bits(m_raw_t)  ,
            parameter   bit   ROUND      = 1'b1                                 
        )
        (
            input   var logic               reset       ,
            input   var logic               clk         ,
            input   var logic               cke         ,

            input   var rows_t              s_rows      ,
            input   var cols_t              s_cols      ,
            input   var logic               s_row_first ,
            input   var logic               s_row_last  ,
            input   var logic               s_col_first ,
            input   var logic               s_col_last  ,
            input   var de_t                s_de        ,
            input   var user_t              s_user      ,
            input   var s_raw_t [3:0][3:0]  s_raw       ,
            input   var user_t              s_valid     ,

            output  var rows_t              m_rows      ,
            output  var cols_t              m_cols      ,
            output  var logic               m_row_first ,
            output  var logic               m_row_last  ,
            output  var logic               m_col_first ,
            output  var logic               m_col_last  ,
            output  var de_t                m_de        ,
            output  var user_t              m_user      ,
            output  var m_raw_t [2:0]       m_raw       ,
            output  var user_t              m_valid     
        );
    

    parameter   int     CALC_BITS = $bits(s_raw_t) + 4    ;
    parameter   type    calc_t    = logic [CALC_BITS-1:0] ;

    logic   [1:0]   st0_x           ;
    logic   [1:0]   st0_y           ;
    rows_t          st0_rows        ;
    cols_t          st0_cols        ;
    logic           st0_row_first   ;
    logic           st0_row_last    ;
    logic           st0_col_first   ;
    logic           st0_col_last    ;
    user_t          st0_user        ;
    de_t            st0_de          ;
    calc_t          st0_raw00       ;
    calc_t          st0_raw01       ;
    calc_t          st0_raw10       ;
    calc_t          st0_raw11       ;
    calc_t          st0_raw20       ;
    calc_t          st0_raw21       ;
    calc_t          st0_raw30       ;
    calc_t          st0_raw31       ;
    logic           st0_valid       ;

    rows_t          st1_rows        ;
    cols_t          st1_cols        ;
    logic           st1_row_first   ;
    logic           st1_row_last    ;
    logic           st1_col_first   ;
    logic           st1_col_last    ;
    user_t          st1_user        ;
    de_t            st1_de          ;
    calc_t          st1_raw00       ;
    calc_t          st1_raw01       ;
    calc_t          st1_raw10       ;
    calc_t          st1_raw11       ;
    logic           st1_valid       ;
    
    rows_t          st2_rows        ;
    cols_t          st2_cols        ;
    logic           st2_row_first   ;
    logic           st2_row_last    ;
    logic           st2_col_first   ;
    logic           st2_col_last    ;
    user_t          st2_user        ;
    de_t            st2_de          ;
    calc_t  [2:0]   st2_raw         ;
    logic           st2_valid       ;
    
    always_ff @(posedge clk) begin
        if ( cke ) begin
            // stage 0
            if ( s_valid ) begin
                if ( s_de ) begin
                    st0_x <= st0_x + 1;
                end
                if ( s_col_first ) begin
                    st0_x <= '0 ;
                    st0_y <= st0_y + 1;
                end
                if ( s_row_first ) begin
                    st0_y <= '0 ;
                end
            end
            st0_rows      <= s_rows                                     ;
            st0_cols      <= s_cols                                     ;
            st0_row_first <= s_row_first                                ;
            st0_row_last  <= s_row_last                                 ;
            st0_col_first <= s_col_first                                ;
            st0_col_last  <= s_col_last                                 ;
            st0_user      <= s_user                                     ;
            st0_de        <= s_de                                       ;
            st0_raw00     <= calc_t'(s_raw[0][0]) + calc_t'(s_raw[0][2]);
            st0_raw01     <= calc_t'(s_raw[0][1]) + calc_t'(s_raw[0][3]);
            st0_raw10     <= calc_t'(s_raw[1][0]) + calc_t'(s_raw[1][2]);
            st0_raw11     <= calc_t'(s_raw[1][1]) + calc_t'(s_raw[1][3]);
            st0_raw20     <= calc_t'(s_raw[2][0]) + calc_t'(s_raw[2][2]);
            st0_raw21     <= calc_t'(s_raw[2][1]) + calc_t'(s_raw[2][3]);
            st0_raw30     <= calc_t'(s_raw[3][0]) + calc_t'(s_raw[3][2]);
            st0_raw31     <= calc_t'(s_raw[3][1]) + calc_t'(s_raw[3][3]);

            // stage 1
            st1_rows      <= st0_rows                                   ;
            st1_cols      <= st0_cols                                   ;
            if ( st0_valid && st0_y == '0 && st0_x == '1 ) begin
                st1_row_first <= st0_row_first                          ;
            end
            if ( st0_valid && st0_x == '0 ) begin
                st1_col_first <= st0_col_first                          ;
            end
            st1_row_last  <= st0_row_last                               ;
            st1_col_last  <= st0_col_last                               ;
            st1_user      <= st0_user                                   ;
            st1_de        <= st0_de && st0_y == '1 && st0_x == '1       ;
            st1_raw00     <= st0_raw00 + st0_raw20                      ;
            st1_raw01     <= st0_raw01 + st0_raw21                      ;
            st1_raw10     <= st0_raw10 + st0_raw30                      ;
            st1_raw11     <= st0_raw11 + st0_raw31                      ;

            // stage 2
            st2_rows      <= st1_rows                   ;
            st2_cols      <= st1_cols                   ;
            st2_row_first <= st1_row_first              ;
            st2_row_last  <= st1_row_last  & st1_de     ;
            st2_col_first <= st1_col_first & st1_de     ;
            st2_col_last  <= st1_col_last  & st1_de     ;
            st2_user      <= st1_user                   ;
            st2_de        <= st1_de                     ;
            st2_raw[0]    <= st1_raw00 + st1_raw11      ;
            st2_raw[1]    <= st1_raw01 * 2              ;
            st2_raw[2]    <= st1_raw10 * 2              ;
        end
    end
    
    always_ff @(posedge clk) begin
        if ( reset ) begin
            st0_valid <= 1'b0        ;
            st1_valid <= 1'b0        ;
            st2_valid <= 1'b0        ;
        end
        else if ( cke ) begin
            st0_valid <= s_valid     ;
            st1_valid <= st0_valid   ;
            st2_valid <= st1_valid   ;
        end
    end

    assign m_rows      = st2_rows                   ;
    assign m_cols      = st2_cols                   ;
    assign m_row_first = st2_row_first              ;
    assign m_row_last  = st2_row_last               ;
    assign m_col_first = st2_col_first              ;
    assign m_col_last  = st2_col_last               ;
    assign m_de        = st2_de                     ;
    assign m_user      = st2_user                   ;
    assign m_raw[0]    = m_raw_t'(st2_raw[0] >> 3)  ;
    assign m_raw[1]    = m_raw_t'(st2_raw[1] >> 3)  ;
    assign m_raw[2]    = m_raw_t'(st2_raw[2] >> 3)  ;
    assign m_valid     = st2_valid                  ;

endmodule

`default_nettype wire

// end of file
