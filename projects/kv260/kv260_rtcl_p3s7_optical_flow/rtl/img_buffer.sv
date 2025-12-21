

`timescale 1ns / 1ps
`default_nettype none


module img_buffer
        #(
            parameter   int     BUF_SIZE     = 640 * 480    ,
            parameter           RAM_TYPE     = "ultra"      ,
            parameter           DEVICE       = "RTL"        ,
            parameter           SIMULATION   = "false"      ,
            parameter           DEBUG        = "false"      
        )
        (
            jelly3_mat_if.s     s_mat,
            jelly3_mat_if.m     m_mat
        );

    localparam  int     TAPS        = s_mat.TAPS                ;
    localparam  int     CH_BITS     = s_mat.CH_BITS             ;
    localparam  int     CH_DEPTH    = s_mat.CH_DEPTH            ;
    localparam  int     DE_BITS     = s_mat.DE_BITS             ;
    localparam  int     USER_BITS   = s_mat.USER_BITS           ;
    localparam  int     ROWS_BITS   = s_mat.ROWS_BITS           ;
    localparam  int     COLS_BITS   = s_mat.COLS_BITS           ;
    localparam  type    ch_t        = logic [CH_BITS-1:0]       ;
    localparam  type    data_t      = ch_t  [CH_DEPTH-1:0]      ;
    localparam  type    de_t        = logic [DE_BITS-1:0]       ;
    localparam  type    user_t      = logic [USER_BITS-1:0]     ;
    localparam  type    rows_t      = logic [ROWS_BITS-1:0]     ;
    localparam  type    cols_t      = logic [COLS_BITS-1:0]     ;

    localparam  int     MEM_DEPTH  = BUF_SIZE / 4                   ;
    localparam  int     ADDRL_BITS = 2                              ;
    localparam  int     ADDRH_BITS = $clog2(BUF_SIZE) - ADDRL_BITS  ;
    localparam  type    we_t       = logic   [3:0]                  ;
    localparam  type    word_t     = data_t  [TAPS-1:0]             ;
    localparam  type    addr_t     = logic   [ADDRH_BITS-1:0]       ;


    // Simple Dualport-RAM
    we_t            wr_en       ;
    addr_t          wr_addr     ;
    word_t  [3:0]   wr_din      ;
    logic           rd_en       ;
    logic           rd_regcke   ;
    addr_t          rd_addr     ;
    word_t  [3:0]   rd_dout     ;

    jelly3_ram_simple_dualport
            #(
                .ADDR_BITS      (ADDRH_BITS     ),
                .WE_BITS        (4              ),
                .DATA_BITS      ($bits(word_t)*4),
                .WORD_BITS      ($bits(word_t)  ),
                .MEM_DEPTH      (MEM_DEPTH      ),
                .RAM_TYPE       (RAM_TYPE       ),
                .DOUT_REG       (1              ),
                .FILLMEM        (1              ),
                .FILLMEM_DATA   ('0             ),
                .DEVICE         (DEVICE         ),
                .SIMULATION     (SIMULATION     ),
                .DEBUG          (DEBUG          )
            )
        u_ram_simple_dualport
            (
                .wr_clk         (s_mat.clk      ),
                .wr_en          (wr_en          ),
                .wr_addr        (wr_addr        ),
                .wr_din         (wr_din         ),

                .rd_clk         (s_mat.clk      ),
                .rd_en          (rd_en          ),
                .rd_regcke      (rd_regcke      ),
                .rd_addr        (rd_addr        ),
                .rd_dout        (rd_dout        )
            );


    we_t                st0_we          ;
    addr_t              st0_addrh       ;
    logic   [1:0]       st0_addrl       ;
    rows_t              st0_rows        ;
    cols_t              st0_cols        ;
    logic               st0_row_first   ;
    logic               st0_row_last    ;
    logic               st0_col_first   ;
    logic               st0_col_last    ;
    de_t                st0_de          ;
    word_t              st0_data        ;
    user_t              st0_user        ;
    logic               st0_valid       ;

    logic   [1:0]       st1_addrl       ;
    rows_t              st1_rows        ;
    cols_t              st1_cols        ;
    logic               st1_row_first   ;
    logic               st1_row_last    ;
    logic               st1_col_first   ;
    logic               st1_col_last    ;
    de_t                st1_de          ;
    word_t              st1_data        ;
    user_t              st1_user        ;
    logic               st1_valid       ;

    logic   [1:0]       st2_addrl       ;
    rows_t              st2_rows        ;
    cols_t              st2_cols        ;
    logic               st2_row_first   ;
    logic               st2_row_last    ;
    logic               st2_col_first   ;
    logic               st2_col_last    ;
    de_t                st2_de          ;
    word_t              st2_data        ;
    user_t              st2_user        ;
    logic               st2_valid       ;

    rows_t              st3_rows        ;
    cols_t              st3_cols        ;
    logic               st3_row_first   ;
    logic               st3_row_last    ;
    logic               st3_col_first   ;
    logic               st3_col_last    ;
    de_t                st3_de          ;
    word_t              st3_data0       ;
    word_t              st3_data1       ;
    user_t              st3_user        ;
    logic               st3_valid       ;

    always_ff @(posedge s_mat.clk) begin
        if ( s_mat.reset ) begin
            st0_valid <= 1'b0   ;
            st1_valid <= 1'b0   ;
            st2_valid <= 1'b0   ;
            st3_valid <= 1'b0   ;
        end
        else if ( s_mat.cke ) begin
            st0_valid <= s_mat.valid;
            st1_valid <= st0_valid  ;
            st2_valid <= st1_valid  ;
            st3_valid <= st2_valid  ;
        end
    end

    always_ff @(posedge s_mat.clk) begin
        if ( s_mat.cke ) begin
            // stage 0
            if ( s_mat.valid && s_mat.row_first && s_mat.col_first ) begin
                st0_we                 <= 4'b0001   ;
                {st0_addrh, st0_addrl} <= '0        ;
            end
            else if ( s_mat.valid && s_mat.de ) begin
                st0_we                 <= {st0_we[2:0], st0_we[3]}  ;
                {st0_addrh, st0_addrl} <= {st0_addrh, st0_addrl} + 1;
            end
            st0_rows      <= s_mat.rows         ;
            st0_cols      <= s_mat.cols         ;
            st0_row_first <= s_mat.row_first    ;
            st0_row_last  <= s_mat.row_last     ;
            st0_col_first <= s_mat.col_first    ;
            st0_col_last  <= s_mat.col_last     ;
            st0_de        <= s_mat.de           ;
            st0_data      <= s_mat.data         ;
            st0_user      <= s_mat.user         ;

            // stage 1
            st1_addrl     <= st0_addrl          ;
            st1_rows      <= st0_rows           ;
            st1_cols      <= st0_cols           ;
            st1_row_first <= st0_row_first      ;
            st1_row_last  <= st0_row_last       ;
            st1_col_first <= st0_col_first      ;
            st1_col_last  <= st0_col_last       ;
            st1_de        <= st0_de             ;
            st1_data      <= st0_data           ;
            st1_user      <= st0_user           ;

            // stage 2
            st2_addrl     <= st1_addrl          ;
            st2_rows      <= st1_rows           ;
            st2_cols      <= st1_cols           ;
            st2_row_first <= st1_row_first      ;
            st2_row_last  <= st1_row_last       ;
            st2_col_first <= st1_col_first      ;
            st2_col_last  <= st1_col_last       ;
            st2_de        <= st1_de             ;
            st2_data      <= st1_data           ;
            st2_user      <= st1_user           ;

            // stage 3
            st3_rows      <= st2_rows           ;
            st3_cols      <= st2_cols           ;
            st3_row_first <= st2_row_first      ;
            st3_row_last  <= st2_row_last       ;
            st3_col_first <= st2_col_first      ;
            st3_col_last  <= st2_col_last       ;
            st3_de        <= st2_de             ;
            st3_data0     <= rd_dout[st1_addrl] ;
            st3_data1     <= st2_data           ;
            st3_user      <= st2_user           ;
        end
    end

    assign wr_en     = s_mat.cke ? st0_we : '0  ;
    assign wr_addr   = st0_addrh                ;
    assign wr_din    = {4{st0_data}}            ;

    assign rd_en     = s_mat.cke                ;
    assign rd_regcke = s_mat.cke                ;
    assign rd_addr   = st0_addrh                ;


    assign m_mat.rows      = st3_rows               ;
    assign m_mat.cols      = st3_cols               ;
    assign m_mat.row_first = st3_row_first          ;
    assign m_mat.row_last  = st3_row_last           ;
    assign m_mat.col_first = st3_col_first          ;
    assign m_mat.col_last  = st3_col_last           ;
    assign m_mat.de        = st3_de                 ;
    assign m_mat.data      = {st3_data1, st3_data0} ;
    assign m_mat.user      = st3_user               ;
    assign m_mat.valid     = st3_valid              ;

endmodule

`default_nettype wire

// end of file
