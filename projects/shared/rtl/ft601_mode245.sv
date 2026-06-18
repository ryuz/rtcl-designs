// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none

module ft601_mode245
        #(
            parameter bit   ASYNC            = 1,
            parameter int   RX_FIFO_PTR_BITS = 8,
            parameter int   TX_FIFO_PTR_BITS = 8
        )
        (
            input   var logic           ft601_reset         ,
            input   var logic           ft601_clk           ,
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

            jelly3_axi4s_if.s           s_axi4s_tx          ,
            jelly3_axi4s_if.m           m_axi4s_rx          
        );
    
    logic   [3:0]   ft601_tx_fifo_strb       ;
    logic   [31:0]  ft601_tx_fifo_data       ;
    logic           ft601_tx_fifo_valid      ;
    logic           ft601_tx_fifo_ready      ;

    logic           ft601_rx_fifo_almost_full;
    logic   [3:0]   ft601_rx_fifo_strb       ;
    logic   [31:0]  ft601_rx_fifo_data       ;
    logic           ft601_rx_fifo_valid      ;
    
    ft601_mode245_transceiver
        u_ft601_mode245_transceiver
            (
                .reset              (ft601_reset                ),
                .clk                (ft601_clk                  ),

                .ft601_rxf_n        (ft601_rxf_n                ),
                .ft601_txe_n        (ft601_txe_n                ),
                .ft601_wr_n         (ft601_wr_n                 ),
                .ft601_rd_n         (ft601_rd_n                 ),
                .ft601_oe_n         (ft601_oe_n                 ),
                .ft601_be_i         (ft601_be_i                 ),
                .ft601_be_o         (ft601_be_o                 ),
                .ft601_be_t         (ft601_be_t                 ),
                .ft601_data_i       (ft601_data_i               ),
                .ft601_data_o       (ft601_data_o               ),
                .ft601_data_t       (ft601_data_t               ),

                .s_fifo_strb        (ft601_tx_fifo_strb         ),
                .s_fifo_data        (ft601_tx_fifo_data         ),
                .s_fifo_valid       (ft601_tx_fifo_valid        ),
                .s_fifo_ready       (ft601_tx_fifo_ready        ),

                .m_fifo_almost_full (ft601_rx_fifo_almost_full  ),
                .m_fifo_strb        (ft601_rx_fifo_strb         ),
                .m_fifo_data        (ft601_rx_fifo_data         ),
                .m_fifo_valid       (ft601_rx_fifo_valid        )
            );


    // -------------------------------
    //  Command FIFO
    // -------------------------------

    // RX FIFO
    logic  [RX_FIFO_PTR_BITS:0] fifo_rx_free_size   ;

    logic   [3:0]               cmd_rx_fifo_strb    ;
    logic   [31:0]              cmd_rx_fifo_data    ;
    logic                       cmd_rx_fifo_valid   ;
    logic                       cmd_rx_fifo_ready   ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC                  ),
                .PTR_BITS       (RX_FIFO_PTR_BITS       ),
                .DATA_BITS      (4+32                   ),
                .S_SYNC_FF      (3                      ),
                .M_SYNC_FF      (3                      ),
                .RAM_TYPE       ("block"                ),
                .DOUT_REG       (1                      )
            )
        u_stream_fifo_rx
            (
                .s_reset        (ft601_reset            ),
                .s_clk          (ft601_clk              ),
                .s_cke          (1'b1                   ),
                .s_data         ({
                                    ft601_rx_fifo_strb,
                                    ft601_rx_fifo_data
                                }),
                .s_valid        (ft601_rx_fifo_valid    ),
                .s_ready        (),
                .s_free_size    (fifo_rx_free_size      ),

                .m_reset        (~m_axi4s_rx.aresetn    ),
                .m_clk          (m_axi4s_rx.aclk        ),
                .m_cke          (m_axi4s_rx.aclken      ),
                .m_data         ({
                                    m_axi4s_rx.tstrb,
                                    m_axi4s_rx.tdata
                                }),
                .m_valid        (m_axi4s_rx.tvalid      ),
                .m_ready        (m_axi4s_rx.tready      ),
                .m_data_size    (                       )
            );

    always_ff @(posedge ft601_clk) begin
        if ( ft601_reset ) begin
            ft601_rx_fifo_almost_full <= 1'b0;
        end
        else begin
            ft601_rx_fifo_almost_full <= fifo_rx_free_size < 64;
        end
    end

    // TX FIFO
    logic   [3:0]   cmd_tx_fifo_strb    ;
    logic   [31:0]  cmd_tx_fifo_data    ;
    logic           cmd_tx_fifo_valid   ;
    logic           cmd_tx_fifo_ready   ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC                  ),
                .PTR_BITS       (TX_FIFO_PTR_BITS       ),
                .DATA_BITS      (4+32                   ),
                .S_SYNC_FF      (3                      ),
                .M_SYNC_FF      (3                      ),
                .RAM_TYPE       ("block"                ),
                .DOUT_REG       (1                      )
            )
        u_stream_fifo_tx
            (
                .s_reset        (~s_axi4s_tx.aresetn    ),
                .s_clk          (s_axi4s_tx.aclk        ),
                .s_cke          (s_axi4s_tx.aclken      ),
                .s_data         ({
                                    s_axi4s_tx.tstrb,
                                    s_axi4s_tx.tdata
                                }),
                .s_valid        (s_axi4s_tx.tvalid      ),
                .s_ready        (s_axi4s_tx.tready      ),
                .s_free_size    (                       ),

                .m_reset        (ft601_reset            ),
                .m_clk          (ft601_clk              ),
                .m_cke          (1'b1                   ),
                .m_data         ({
                                    ft601_tx_fifo_strb,
                                    ft601_tx_fifo_data
                                }),
                .m_valid        (ft601_tx_fifo_valid    ),
                .m_ready        (ft601_tx_fifo_ready    ),
                .m_data_size    (                       )
            );

endmodule


`default_nettype wire
