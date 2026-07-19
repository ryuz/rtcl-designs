// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none

module ft601_multi_ch_mode
        #(
            parameter   int     CHANNELS         = 4            ,
            parameter   bit     ASYNC            = 1            ,
            parameter   int     RX_FIFO_PTR_BITS = 8            ,
            parameter   int     TX_FIFO_PTR_BITS = 8            ,
            localparam  type    data_t           = logic [31:0] ,
            localparam  type    be_t             = logic [3:0]  
        )
        (
            input   var logic                           ft601_reset             ,
            input   var logic                           ft601_clk               ,
            input   var logic                           ft601_rxf_n             ,
            input   var logic                           ft601_txe_n             ,
            output  var logic                           ft601_wr_n              ,
            output  var logic                           ft601_rd_n              ,
            output  var logic                           ft601_oe_n              ,
            input   var be_t                            ft601_be_i              ,
            output  var be_t                            ft601_be_o              ,
            output  var be_t                            ft601_be_t              ,
            input   var data_t                          ft601_data_i            ,
            output  var data_t                          ft601_data_o            ,
            output  var data_t                          ft601_data_t            ,

            jelly3_axi4s_if.s                           s_axi4s_tx  [CHANNELS]  ,
            jelly3_axi4s_if.m                           m_axi4s_rx  [CHANNELS]  ,

            output  var logic   [CHANNELS-1:0][31:0]    rx_counter              ,
            output  var logic   [CHANNELS-1:0][31:0]    tx_counter          

        );
    
    be_t    [CHANNELS-1:0]  ft601_tx_fifo_strb       ;
    data_t  [CHANNELS-1:0]  ft601_tx_fifo_data       ;
    logic   [CHANNELS-1:0]  ft601_tx_fifo_valid      ;
    logic   [CHANNELS-1:0]  ft601_tx_fifo_ready      ;

    logic   [CHANNELS-1:0]  ft601_rx_fifo_almost_full;
    be_t    [CHANNELS-1:0]  ft601_rx_fifo_strb       ;
    data_t  [CHANNELS-1:0]  ft601_rx_fifo_data       ;
    logic   [CHANNELS-1:0]  ft601_rx_fifo_valid      ;
    
    ft601_multi_ch_mode_transceiver
            #(
                .CHANNELS           (CHANNELS                   )
            )
        u_ft601_multi_ch_mode_transceiver
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
                .m_fifo_valid       (ft601_rx_fifo_valid        ),

                .rx_counter         (rx_counter                 ),
                .tx_counter         (tx_counter                 )
            );


    // -------------------------------
    //  Command FIFO
    // -------------------------------

    for ( genvar i = 0; i < CHANNELS; i++ ) begin : gen_ch

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
                                        ft601_rx_fifo_strb[i],
                                        ft601_rx_fifo_data[i]
                                    }),
                    .s_valid        (ft601_rx_fifo_valid[i] ),
                    .s_ready        (),
                    .s_free_size    (fifo_rx_free_size      ),

                    .m_reset        (~m_axi4s_rx[i].aresetn ),
                    .m_clk          (m_axi4s_rx[i].aclk     ),
                    .m_cke          (m_axi4s_rx[i].aclken   ),
                    .m_data         ({
                                        m_axi4s_rx[i].tstrb,
                                        m_axi4s_rx[i].tdata
                                    }),
                    .m_valid        (m_axi4s_rx[i].tvalid   ),
                    .m_ready        (m_axi4s_rx[i].tready   ),
                    .m_data_size    (                       )
                );

        always_ff @(posedge ft601_clk) begin
            if ( ft601_reset ) begin
                ft601_rx_fifo_almost_full[i] <= 1'b0;
            end
            else begin
                ft601_rx_fifo_almost_full[i] <= fifo_rx_free_size < 64;
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
                    .s_reset        (~s_axi4s_tx[i].aresetn ),
                    .s_clk          (s_axi4s_tx[i].aclk     ),
                    .s_cke          (s_axi4s_tx[i].aclken   ),
                    .s_data         ({
                                        s_axi4s_tx[i].tstrb,
                                        s_axi4s_tx[i].tdata
                                    }),
                    .s_valid        (s_axi4s_tx[i].tvalid   ),
                    .s_ready        (s_axi4s_tx[i].tready   ),
                    .s_free_size    (                       ),

                    .m_reset        (ft601_reset            ),
                    .m_clk          (ft601_clk              ),
                    .m_cke          (1'b1                   ),
                    .m_data         ({
                                        ft601_tx_fifo_strb[i],
                                        ft601_tx_fifo_data[i]
                                    }),
                    .m_valid        (ft601_tx_fifo_valid[i] ),
                    .m_ready        (ft601_tx_fifo_ready[i] ),
                    .m_data_size    (                       )
                );
    end

endmodule


`default_nettype wire
