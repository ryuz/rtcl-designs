// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ps/1ps
`default_nettype none


module ft601_multi_ch_mode_transceiver
        #(
            parameter   int     CHANNELS     = 4                        ,
            parameter   int     TIMEOUT_BITS = 16                       ,
            parameter   type    timeout_t    = logic [TIMEOUT_BITS-1:0] ,
            parameter   int     COUNTER_BITS = 32                       ,
            parameter   type    counter_t    = logic [COUNTER_BITS-1:0] ,
            localparam  type    data_t       = logic [31:0]             ,
            localparam  type    be_t         = logic [3:0]              ,
            localparam  type    strb_t       = be_t                     
        )
        (
            input   var logic                       reset               ,
            input   var logic                       clk                 ,

            input   var logic                       ft601_rxf_n         ,
            input   var logic                       ft601_txe_n         ,
            output  var logic                       ft601_wr_n          ,
            output  var logic                       ft601_rd_n          ,
            output  var logic                       ft601_oe_n          ,
            input   var be_t                        ft601_be_i          ,
            output  var be_t                        ft601_be_o          ,
            output  var be_t                        ft601_be_t          ,
            input   var data_t                      ft601_data_i        ,
            output  var data_t                      ft601_data_o        ,
            output  var data_t                      ft601_data_t        ,

            input   var timeout_t   [CHANNELS-1:0]  s_fifo_timeout      ,
            input   var logic       [CHANNELS-1:0]  s_fifo_enough_data  ,
            input   var strb_t      [CHANNELS-1:0]  s_fifo_strb         ,
            input   var data_t      [CHANNELS-1:0]  s_fifo_data         ,
            input   var logic       [CHANNELS-1:0]  s_fifo_valid        ,
            output  var logic       [CHANNELS-1:0]  s_fifo_ready        ,

            input   var logic       [CHANNELS-1:0]  m_fifo_almost_full  ,
            input   var logic       [CHANNELS-1:0]  m_fifo_enough_space ,
            output  var strb_t      [CHANNELS-1:0]  m_fifo_strb         ,
            output  var data_t      [CHANNELS-1:0]  m_fifo_data         ,
            output  var logic       [CHANNELS-1:0]  m_fifo_valid        ,

            output  var counter_t   [CHANNELS-1:0]  mon_rx_counter      ,
            output  var counter_t   [CHANNELS-1:0]  mon_tx_counter      ,
            output  var logic                       mon_wr_n            ,
            output  var logic                       mon_rxf_n           ,
            output  var logic                       mon_txe_n           ,
            output  var be_t                        mon_be              ,
            output  var data_t                      mon_data            
        );
    
    localparam  int     CHANNELS_BITS = CHANNELS > 1 ? $clog2(CHANNELS) : 1;
    localparam  type    channel_t     = logic [CHANNELS_BITS-1:0];

    // 入力信号ラッチ
    logic       reg_ft601_rxf_n  = 1'b1 ;
    logic       reg_ft601_txe_n  = 1'b1 ;
    be_t        reg_ft601_be_i   ;
    data_t      reg_ft601_data_i ;
    always_ff @( posedge clk or posedge reset) begin
        if ( reset ) begin
            reg_ft601_rxf_n  <= 1'b1  ;
            reg_ft601_txe_n  <= 1'b1  ;
        end
        else begin
            reg_ft601_rxf_n  <= ft601_rxf_n  ;
            reg_ft601_txe_n  <= ft601_txe_n  ;
        end
    end
    always_ff @( posedge clk ) begin
        reg_ft601_be_i   <= ft601_be_i   ;
        reg_ft601_data_i <= ft601_data_i ;
    end

    // 状態定義
    typedef enum logic [3:0] {
        IDLE          = 0   ,
        READ_COMMAND  = 1   ,
        READ_TA1      = 2   ,
        READ_TA2      = 3   ,
        READ_DATA     = 4   ,
        WRITE_COMMAND = 5   ,
        WRITE_TA      = 6   ,
        WRITE_DATA    = 7   ,
        FINAL1        = 8   ,
        FINAL2        = 9   
    } state_t;

    state_t                     state            = IDLE         ;
    channel_t                   channel                         ;
    logic       [CHANNELS-1:0]  buf_en                          ;
    data_t      [CHANNELS-1:0]  buf_data                        ;
    strb_t      [CHANNELS-1:0]  buf_strb                        ;
    logic                       reg_ft601_wr_n   = 1'b1         ;
    be_t                        reg_ft601_be_o   = 4'hf         ;
    be_t                        reg_ft601_be_t   = 4'h0         ;
    data_t                      reg_ft601_data_o = 32'hffff_ffff;
    data_t                      reg_ft601_data_t = 32'h0000_ff00;

    // タイムアウト監視
    timeout_t   [CHANNELS-1:0]  tx_timeout_count;
    logic       [CHANNELS-1:0]  tx_enable       ;
    always_ff @( posedge clk or posedge reset ) begin
        if ( reset ) begin
            tx_timeout_count <= '0;
            tx_enable        <= '0;
        end
        else begin
            for ( int i = 0; i < CHANNELS; i++ ) begin
                if ( state == WRITE_DATA && channel == channel_t'(i) && ft601_rxf_n == 1'b0 ) begin
                    // 送信発生でタイムアウトカウントをリセット
                    tx_timeout_count[i] <= '0;
                    tx_enable[i]        <= 1'b0;
                end
                else if ( s_fifo_valid[i] || buf_en[i] ) begin
                    // 送信データあり
                    if ( s_fifo_enough_data[i] || tx_timeout_count[i] >= s_fifo_timeout[i] ) begin
                        // 十分なデータがあるかタイムアウトなら送信許可
                        tx_enable[i] <= 1'b1;
                    end
                    else begin
                        // 十分なデータがないのでタイムアウトまで貯める
                        tx_timeout_count[i] <= tx_timeout_count[i] + 1'b1;
                        tx_enable[i]        <= 1'b0;
                    end
                end
                else begin
                    // 送信データなし
                    tx_timeout_count[i] <= '0;
                    tx_enable[i]        <= 1'b0;
                end
            end
        end
    end

    // 制御
    always_ff @( posedge clk or posedge reset ) begin
        if ( reset ) begin
            state            <= IDLE         ;
            channel          <= 'x           ;
            buf_en           <= '0           ;
            buf_data         <= 'x           ;
            buf_strb         <= 'x           ;
            mon_wr_n         <= 1'b1         ;
            reg_ft601_wr_n   <= 1'b1         ;
            reg_ft601_be_t   <= 4'h0         ;
            reg_ft601_be_o   <= 4'hf         ;
            reg_ft601_data_t <= 32'h0000_ff00;
            reg_ft601_data_o <= 32'hffff_ffff;
        end
        else begin
            case ( state )
            IDLE:
                begin
                    mon_wr_n         <= 1'b1         ;
                    reg_ft601_wr_n   <= 1'b1         ;
                    reg_ft601_be_t   <= 4'h0         ;
                    reg_ft601_be_o   <= 4'hf         ;
                    reg_ft601_data_t <= 32'h0000_ff00;
                    reg_ft601_data_o <= 32'hffff_ffff;
                    // read判定
                    for ( int i = 0; i < CHANNELS; i++ ) begin
                        if ( ~reg_ft601_data_i[12+i] && m_fifo_enough_space[i] ) begin
                            state                 <= READ_COMMAND ;
                            channel               <= channel_t'(i);
                            mon_wr_n              <= 1'b0         ;
                            reg_ft601_wr_n        <= 1'b0         ;
                            reg_ft601_be_t        <= 4'h0         ;
                            reg_ft601_be_o        <= 4'h0         ;
                            reg_ft601_data_t      <= 32'h0000_ff00;
                            reg_ft601_data_o      <= 32'hffff_ff00;
                            reg_ft601_data_o[2:0] <= 3'(i+1)      ;
                            break;
                        end
                    end
                    // write判定(優先)
                    for ( int i = 0; i < CHANNELS; i++ ) begin
                        if ( ~reg_ft601_data_i[8+i] && tx_enable[i] ) begin
                            state                 <= WRITE_COMMAND;
                            channel               <= channel_t'(i);
                            mon_wr_n              <= 1'b0         ;
                            reg_ft601_wr_n        <= 1'b0         ;
                            reg_ft601_be_t        <= 4'h0         ;
                            reg_ft601_be_o        <= 4'h1         ;
                            reg_ft601_data_t      <= 32'h0000_ff00;
                            reg_ft601_data_o      <= 32'hffff_ff00;
                            reg_ft601_data_o[2:0] <= 3'(i+1)      ;
                            break;
                        end
                    end
                end

                READ_COMMAND:
                    begin
                        state            <= READ_TA1     ;
                        mon_wr_n         <= 1'b0         ;
                        reg_ft601_wr_n   <= 1'b0         ;
                        reg_ft601_be_t   <= 4'hf         ;
                        reg_ft601_data_t <= 32'hffff_ffff;
                    end
                
                READ_TA1:
                    begin
                        state <= READ_TA2  ;
                    end

                READ_TA2:
                    begin
                        state <= READ_DATA  ;
                    end

                READ_DATA:
                    begin
                        if ( ft601_rxf_n == 1'b1 || m_fifo_almost_full[channel] ) begin
                            state            <= FINAL1       ;
                            mon_wr_n         <= 1'b1         ;
                            reg_ft601_wr_n   <= 1'b1         ;
                            reg_ft601_be_t   <= 4'h0         ;
                            reg_ft601_be_o   <= 4'hf         ;
                            reg_ft601_data_t <= 32'h0000_ff00;
                            reg_ft601_data_o <= 32'hffff_ffff;
                        end
                    end

                WRITE_COMMAND:
                    begin
                        state            <= WRITE_TA            ;
                    end

                WRITE_TA:
                    begin
                        state            <= WRITE_DATA          ;
                        mon_wr_n         <= 1'b0                ;
                        reg_ft601_wr_n   <= 1'b0                ;
                        reg_ft601_data_t <= 32'h0000_0000       ;
                        if ( buf_en[channel] ) begin
                            reg_ft601_data_o <= buf_data[channel];
                            reg_ft601_be_o   <= buf_strb[channel];
                        end
                        else begin
                            reg_ft601_data_o  <= s_fifo_data[channel];
                            reg_ft601_be_o    <= s_fifo_strb[channel];
                            buf_strb[channel] <= s_fifo_strb[channel];
                            buf_data[channel] <= s_fifo_data[channel];
                        end
                    end

                WRITE_DATA:
                    begin
                        if ( !s_fifo_valid[channel] || ft601_rxf_n == 1'b1 ) begin
                            state            <= FINAL1                  ;
                            buf_en[channel]  <= ft601_rxf_n == 1'b1     ;
                            mon_wr_n         <= 1'b1                    ;
                            reg_ft601_wr_n   <= 1'b1                    ;
                            reg_ft601_be_t   <= 4'h0                    ;
                            reg_ft601_be_o   <= 4'hf                    ;
                            reg_ft601_data_t <= 32'h0000_ff00           ;
                            reg_ft601_data_o <= 32'hffff_ffff           ;
                        end
                        else begin
                            reg_ft601_be_t    <= 4'h0                ;
                            reg_ft601_be_o    <= s_fifo_strb[channel];
                            reg_ft601_data_t  <= 32'h0000_0000       ;
                            reg_ft601_data_o  <= s_fifo_data[channel];
                            buf_strb[channel] <= s_fifo_strb[channel];
                            buf_data[channel] <= s_fifo_data[channel];
                        end
                    end
                
                FINAL1:
                    begin
                        state            <= FINAL2       ;
                        mon_wr_n         <= 1'b1         ;
                        reg_ft601_wr_n   <= 1'b1         ;
                        reg_ft601_be_t   <= 4'h0         ;
                        reg_ft601_be_o   <= 4'hf         ;
                        reg_ft601_data_t <= 32'h0000_ff00;
                        reg_ft601_data_o <= 32'hffff_ffff;
                    end
                
                FINAL2:
                    begin
                        state            <= IDLE         ;
                        mon_wr_n         <= 1'b1         ;
                        reg_ft601_wr_n   <= 1'b1         ;
                        reg_ft601_be_t   <= 4'h0         ;
                        reg_ft601_be_o   <= 4'hf         ;
                        reg_ft601_data_t <= 32'h0000_ff00;
                        reg_ft601_data_o <= 32'hffff_ffff;
                    end

                default:
                    state <= IDLE;
            endcase
        end
    end

//  logic           reg_read     = 1'b0 ;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
//          reg_read     <= 1'b0 ;
            m_fifo_strb  <= 'x  ;
            m_fifo_data  <= 'x  ;
            m_fifo_valid <= '0  ;
        end
        else begin
//          reg_read     <= 1'b0;
            m_fifo_strb  <= 'x  ;
            m_fifo_data  <= 'x  ;
            m_fifo_valid <= '0  ;
            for ( int i = 0; i < CHANNELS; i++ ) begin
                if ( channel == channel_t'(i) && state == READ_DATA && reg_ft601_rxf_n == 1'b0 ) begin
                    m_fifo_strb[i]  <= reg_ft601_be_i   ;
                    m_fifo_data[i]  <= reg_ft601_data_i ;
                    m_fifo_valid[i] <= 1'b1             ;
                end
            end
        end
    end

    always_comb begin
        s_fifo_ready = '0;
        for ( int i = 0; i < CHANNELS; i++ ) begin
            if ( channel == channel_t'(i) ) begin
                if ( (state == WRITE_TA && !buf_en[i]) || (state == WRITE_DATA && ft601_rxf_n == 1'b0) ) begin
                    s_fifo_ready[i] = 1'b1;
                end
            end
        end
    end

    assign ft601_wr_n   = reg_ft601_wr_n    ;
    assign ft601_rd_n   = 1'b1              ;
    assign ft601_oe_n   = 1'b1              ;
    assign ft601_be_o   = reg_ft601_be_o    ;
    assign ft601_be_t   = reg_ft601_be_t    ;
    assign ft601_data_o = reg_ft601_data_o  ;
    assign ft601_data_t = reg_ft601_data_t  ;


    always_ff @( posedge clk ) begin
        if ( reset ) begin
            mon_tx_counter <= '0;
            mon_rx_counter <= '0;
        end
        else begin
            for ( int i = 0; i < CHANNELS; i++ ) begin
                if ( state == WRITE_DATA &&  ft601_rxf_n == 1'b0 && channel == channel_t'(i) ) begin
                    mon_tx_counter[i] <= mon_tx_counter[i] + 1'b1;
                end
                if ( m_fifo_valid[i] ) begin
                    mon_rx_counter[i] <= mon_rx_counter[i] + 1'b1;
                end
            end
        end
    end

    assign mon_rxf_n    = reg_ft601_rxf_n   ;
    assign mon_txe_n    = reg_ft601_txe_n   ;
    assign mon_be       = reg_ft601_be_i    ;
    assign mon_data     = reg_ft601_data_i  ;

endmodule


`default_nettype wire
