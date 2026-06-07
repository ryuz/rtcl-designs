// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`default_nettype none

module ft601_mode245_if
        (
            input   var logic           reset               ,
            input   var logic           clk                 ,
//          input   var logic           tx_clk              ,

            input   var logic           ft601_rxf_n         ,
            input   var logic           ft601_txe_n         ,
            output  var logic           ft601_wr_n          ,
            output  var logic           ft601_rd_n          ,
            output  var logic           ft601_oe_n          ,
            input   var logic   [3:0]   ft601_be_i          ,
            output  var logic   [3:0]   ft601_be_o          ,
            output  var logic   [3:0]   ft601_be_t          ,
            input   var logic   [31:0]  ft601_data_i        ,
            output  var logic   [31:0]  ft601_data_o        ,
            output  var logic   [31:0]  ft601_data_t        ,

            input   var logic   [3:0]   s_fifo_strb         ,
            input   var logic   [31:0]  s_fifo_data         ,
            input   var logic           s_fifo_valid        ,
            output  var logic           s_fifo_ready        ,

            input   var logic           m_fifo_almost_full  ,
            output  var logic   [3:0]   m_fifo_strb         ,
            output  var logic   [31:0]  m_fifo_data         ,
            output  var logic           m_fifo_valid        
        );
    

    // 入力信号ラッチ
    logic           reg_ft601_rxf_n  = 1'b1 ;
    logic           reg_ft601_txe_n  = 1'b1 ;
    logic   [3:0]   reg_ft601_be_i   ;
    logic   [31:0]  reg_ft601_data_i ;
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


    // 送信制御
    typedef enum logic [2:0] {
        IDLE        ,
        READ_SETUP  ,
        READ_DATA   ,
        READ_END    ,
        WRITE       
    } state_t;


    state_t         state = IDLE;
//  logic  [7:0]    write_count;

    logic           reg_ft601_wr_n   = 1'b1 ;
    logic           reg_ft601_rd_n   = 1'b1 ;
    logic           reg_ft601_oe_n   = 1'b1 ;
    logic   [3:0]   reg_ft601_be_o   = '0   ;
    logic   [3:0]   reg_ft601_be_t   = '1   ;
    logic   [31:0]  reg_ft601_data_o = '0   ;
    logic   [31:0]  reg_ft601_data_t = '1   ;
    logic           reg_ft601_buf    = 1'b0 ;

    logic read_start;
    logic write_start;
    assign read_start  = (state == IDLE) && ~reg_ft601_rxf_n && !m_fifo_almost_full;
    assign write_start = (state == IDLE) && ~reg_ft601_txe_n && s_fifo_valid && !read_start;

    always_ff @( posedge clk or posedge reset ) begin
        if ( reset ) begin
            state <= IDLE;
            reg_ft601_wr_n   <= 1'b1    ;
            reg_ft601_rd_n   <= 1'b1    ;
            reg_ft601_oe_n   <= 1'b1    ;
            reg_ft601_be_o   <= '0      ;
            reg_ft601_be_t   <= '1      ;
            reg_ft601_data_o <= '0      ;
            reg_ft601_data_t <= '1      ;
            reg_ft601_buf    <= 1'b0    ;
        end
        else begin          
            case ( state )
                IDLE:
                    begin
                        reg_ft601_wr_n   <= 1'b1;
                        reg_ft601_rd_n   <= 1'b1;
                        reg_ft601_oe_n   <= 1'b1;
                        reg_ft601_be_o   <= '0  ;
                        reg_ft601_be_t   <= '1  ;
                        reg_ft601_data_o <= '0  ;
                        reg_ft601_data_t <= '1  ;
                        if ( ~reg_ft601_rxf_n && !m_fifo_almost_full ) begin
                            // 受信開始
                            state      <= READ_SETUP;
                            reg_ft601_oe_n <= 1'b0;
                        end
                        else if ( ~reg_ft601_txe_n && (reg_ft601_buf || s_fifo_valid) ) begin
                            // 送信開始
                            state            <= WRITE;
                            if ( reg_ft601_buf ) begin
                                // 前回の未送信が残っていたらそのまま送信
                                reg_ft601_wr_n   <= 1'b0;
                                reg_ft601_be_t   <= '0;
                                reg_ft601_data_t <= '0;
                            end
                        end
                    end

                READ_SETUP:
                    begin
                        state          <= READ_DATA;
                        reg_ft601_rd_n <= 1'b0;
                        reg_ft601_oe_n <= 1'b0;
                    end

                READ_DATA:
                    begin
                        if ( reg_ft601_rxf_n || m_fifo_almost_full ) begin
                            state          <= READ_END;
                            reg_ft601_rd_n <= 1'b1;
                            reg_ft601_oe_n <= 1'b1;
                        end
                    end
                
                READ_END:
                    begin
                        state <= IDLE;
                    end

                WRITE:
                    begin
                        if ( ~ft601_txe_n ) begin
                            reg_ft601_buf <= 1'b0;
                        end
                        if ( ~ft601_txe_n && s_fifo_valid ) begin
                            reg_ft601_wr_n   <= 1'b0        ;
                            reg_ft601_be_t   <= '0          ;
                            reg_ft601_data_t <= '0          ;
                            reg_ft601_be_o   <= s_fifo_strb ;
                            reg_ft601_data_o <= s_fifo_data ;
                            reg_ft601_buf    <= 1'b1        ;
                        end
                        else begin
                            state            <= IDLE;
                            reg_ft601_wr_n   <= 1'b1;
                            reg_ft601_be_t   <= '1;
                            reg_ft601_data_t <= '1;
                        end
                    end
                
                default:
                    state <= IDLE;
            endcase
        end
    end

    logic           reg_read     = 1'b0 ;
    logic           reg_write    = 1'b0 ;
    always_ff @( posedge clk ) begin
        reg_read  <= state == READ_DATA;
        reg_write <= (state == WRITE) || write_start;
    end

    always_ff @( posedge clk ) begin
        if ( reset ) begin
            m_fifo_strb  <= 'x  ;
            m_fifo_data  <= 'x  ;
            m_fifo_valid <= 1'b0;
        end
        else begin
            m_fifo_strb  <= reg_ft601_be_i              ;
            m_fifo_data  <= reg_ft601_data_i            ;
            m_fifo_valid <= reg_read && ~reg_ft601_rxf_n;
        end
    end

//  assign s_fifo_ready = ~reg_ft601_txe_n && (state == WRITE) || write_start;
    assign s_fifo_ready = ~ft601_txe_n && (state == WRITE);

//  assign s_fifo_ready = (!reg_ft601_buf || ~ft601_txe_n) && (state == WRITE || write_start);

    assign ft601_wr_n   = reg_ft601_wr_n   ;
    assign ft601_rd_n   = reg_ft601_rd_n   ;
    assign ft601_oe_n   = reg_ft601_oe_n   ;
    assign ft601_be_o   = reg_ft601_be_o   ;
    assign ft601_be_t   = reg_ft601_be_t   ; 
    assign ft601_data_o = reg_ft601_data_o ;
    assign ft601_data_t = reg_ft601_data_t ;

endmodule


`default_nettype wire
