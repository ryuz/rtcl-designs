// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`default_nettype none

module ft601_multi_ch_mode_transceiver
        #(
            parameter   int     CHANNELS = 4            ,
            localparam  type    data_t   = logic [31:0] ,
            localparam  type    be_t     = logic [3:0]  ,
            localparam  type    strb_t   = be_t         
        )
        (
            input   var logic                   reset               ,
            input   var logic                   clk                 ,

            input   var logic                   ft601_rxf_n         ,
            input   var logic                   ft601_txe_n         ,
            output  var logic                   ft601_wr_n          ,
            output  var logic                   ft601_rd_n          ,
            output  var logic                   ft601_oe_n          ,
            input   var be_t                    ft601_be_i          ,
            output  var be_t                    ft601_be_o          ,
            output  var be_t                    ft601_be_t          ,
            input   var data_t                  ft601_data_i        ,
            output  var data_t                  ft601_data_o        ,
            output  var data_t                  ft601_data_t        ,

            input   var strb_t  [CHANNELS-1:0]  s_fifo_strb         ,
            input   var data_t  [CHANNELS-1:0]  s_fifo_data         ,
            input   var logic   [CHANNELS-1:0]  s_fifo_valid        ,
            output  var logic   [CHANNELS-1:0]  s_fifo_ready        ,

            input   var logic   [CHANNELS-1:0]  m_fifo_almost_full  ,
            output  var strb_t  [CHANNELS-1:0]  m_fifo_strb         ,
            output  var data_t  [CHANNELS-1:0]  m_fifo_data         ,
            output  var logic   [CHANNELS-1:0]  m_fifo_valid        
        );
    
    localparam  int     CHANNELS_BITS = CHANNELS > 1 ? $clog2(CHANNELS) : 1;
    localparam  type    channel_t     = logic [CHANNELS_BITS-1:0];

    // Multi-channel mode で未使用のピン
    assign ft601_rd_n = 1'b1;
    assign ft601_oe_n = 1'b1;


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
    typedef enum {
        IDLE            ,
        READ_COMMAND    ,
        READ_TA1_1      ,
        READ_TA1_2      ,
        READ_DATA       ,
        WRITE_COMMAD    ,
        WRITE_TA1       ,
        WRITE_DATA      ,
        WRITE_TA2       ,
        FINAL           
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

    always_ff @( posedge clk or posedge reset ) begin
        if ( reset ) begin
            state            <= IDLE         ;
            channel          <= 'x           ;
            buf_en           <= '0           ;
            buf_data         <= 'x           ;
            buf_strb         <= 'x           ;
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
                    reg_ft601_wr_n   <= 1'b1         ;
                    reg_ft601_be_t   <= 4'h0         ;
                    reg_ft601_be_o   <= 4'hf         ;
                    reg_ft601_data_t <= 32'h0000_ff00;
                    reg_ft601_data_o <= 32'hffff_ffff;
                    // read判定
                    for ( int i = 0; i < CHANNELS; i++ ) begin
                        if ( reg_ft601_data_i[12+i] && m_fifo_almost_full[i] ) begin
                            state               <= READ_COMMAND ;
                            channel             <= channel_t'(i);
                            reg_ft601_wr_n      <= 1'b0         ;
                            reg_ft601_be_t      <= 4'h0         ;
                            reg_ft601_be_o      <= 4'h0         ;
                            reg_ft601_data_t    <= 32'h0000_ff00;
                            reg_ft601_data_o    <= 32'hffff_ff00;
                            reg_ft601_data_o[i] <= 1'b1         ;
                        end
                    end
                    // write判定(優先)
                    for ( int i = 0; i < CHANNELS; i++ ) begin
                        if ( reg_ft601_data_i[8+i] && s_fifo_valid[i] ) begin
                            state               <= WRITE_COMMAD ;
                            channel             <= channel_t'(i);
                            reg_ft601_wr_n      <= 1'b0         ;
                            reg_ft601_be_t      <= 4'h0         ;
                            reg_ft601_be_o      <= 4'h1         ;
                            reg_ft601_data_t    <= 32'h0000_ff00;
                            reg_ft601_data_o    <= 32'hffff_ff00;
                            reg_ft601_data_o[i] <= 1'b1         ;
                        end
                    end
                end

                READ_COMMAND:
                    begin
                        state            <= READ_TA_1_1  ;
                        reg_ft601_wr_n   <= 1'b0         ;
                        reg_ft601_be_t   <= 4'hf         ;
                        reg_ft601_data_t <= 32'hffff_ffff;
                    end
                
                READ_TA1_1:
                    begin
                        state <= READ_TA1_2  ;
                    end

                READ_TA1_2:
                    begin
                        state <= READ_DATA    ;
                    end

                READ_DATA:
                    begin
                        if ( ft601_rxf_n == 1'b1 ) begin
                            state            <= FINAL        ;
                            reg_ft601_wr_n   <= 1'b1         ;
                            reg_ft601_be_t   <= 4'h0         ;
                            reg_ft601_be_o   <= 4'hf         ;
                            reg_ft601_data_t <= 32'h0000_ff00;
                            reg_ft601_data_o <= 32'hffff_ffff;
                        end
                    end

                WRITE_COMMAND:
                    begin
                        state            <= WRITE_TA1       ;
                    end

                WRITE_TA1:
                    begin
                        state            <= WRITE_DATA          ;
                        reg_ft601_wr_n   <= 1'b0                ;
                        reg_ft601_data_t <= 32'h0000_0000       ;
                        reg_ft601_data_o <= s_fifo_data[channel];
                    end

                WRITE_DATA:
                    begin
                        if ( !s_fifo_valid[channel] ||  ) begin
                            state            <= WRITE_TA2       ;
                            reg_ft601_wr_n   <= 1'b1            ;
                            reg_ft601_be_t   <= 4'h0            ;
                            reg_ft601_be_o   <= 4'hf            ;
                            reg_ft601_data_t <= 32'h0000_ff00   ;
                            reg_ft601_data_o <= 32'hffff_ffff   ;
                        end
                        else begin
                            reg_ft601_data_t <= 32'h0000_0000       ;
                            reg_ft601_data_o <= s_fifo_data[channel];
                        end
                    end

                default:
                    state <= IDLE;
            endcase
        end
    end

    logic           reg_read     = 1'b0 ;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            reg_read     <= 1'b0;
            m_fifo_strb  <= 'x  ;
            m_fifo_data  <= 'x  ;
            m_fifo_valid <= 1'b0;
        end
        else begin
            reg_read     <= (state == READ_DATA);
            m_fifo_strb  <= reg_ft601_be_i              ;
            m_fifo_data  <= reg_ft601_data_i            ;
            m_fifo_valid <= reg_read && ~reg_ft601_rxf_n;
        end
    end

    assign s_fifo_ready = ~ft601_txe_n && (state == WRITE);

    assign ft601_wr_n   = reg_ft601_wr_n   ;
    assign ft601_rd_n   = reg_ft601_rd_n   ;
    assign ft601_oe_n   = reg_ft601_oe_n   ;
    assign ft601_be_o   = reg_ft601_be_o   ;
    assign ft601_be_t   = reg_ft601_be_t   ; 
    assign ft601_data_o = reg_ft601_data_o ;
    assign ft601_data_t = reg_ft601_data_t ;

endmodule


`default_nettype wire
