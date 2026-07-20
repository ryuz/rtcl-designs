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
            parameter   int     CHANNELS                    = 1                         ,
            parameter   int     TIMEOUT_BITS                = 16                        ,
            parameter   type    timeout_t                   = logic [TIMEOUT_BITS-1:0]  ,
            parameter   int     COUNTER_BITS                = 32                        ,
            parameter   type    counter_t                   = logic [COUNTER_BITS-1:0]  ,
            parameter   bit     ASYNC                       = 1                         ,
            parameter   int     RX_FIFO_PTR_BITS [CHANNELS] = '{default: 9}             ,
            parameter   int     TX_FIFO_PTR_BITS [CHANNELS] = '{default: 9}             ,
            parameter   int     TX_THRESHOLD     [CHANNELS] = '{default: 256}           ,
            localparam  type    data_t                      = logic [31:0]              ,
            localparam  type    be_t                        = logic [3:0]               
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

            input   var timeout_t   [CHANNELS-1:0]      tx_timeout              ,

            jelly3_axi4s_if.s                           s_axi4s_tx  [CHANNELS]  ,
            jelly3_axi4s_if.m                           m_axi4s_rx  [CHANNELS]  ,

            output  var counter_t   [CHANNELS-1:0]      rx_counter              ,
            output  var counter_t   [CHANNELS-1:0]      tx_counter              ,

            output  var logic                           mon_wr_n                ,
            output  var logic                           mon_rxf_n               ,
            output  var logic                           mon_txe_n               ,
            output  var be_t                            mon_be                  ,
            output  var data_t                          mon_data                
        );
    
    timeout_t   [CHANNELS-1:0]  ft601_tx_timeout            ;
    logic       [CHANNELS-1:0]  ft601_tx_enough_data        ;
    be_t        [CHANNELS-1:0]  ft601_tx_fifo_strb          ;
    data_t      [CHANNELS-1:0]  ft601_tx_fifo_data          ;
    logic       [CHANNELS-1:0]  ft601_tx_fifo_valid         ;
    logic       [CHANNELS-1:0]  ft601_tx_fifo_ready         ;

    logic       [CHANNELS-1:0]  ft601_rx_fifo_almost_full   ;
    logic       [CHANNELS-1:0]  ft601_rx_fifo_enough_space  ;
    be_t        [CHANNELS-1:0]  ft601_rx_fifo_strb          ;
    data_t      [CHANNELS-1:0]  ft601_rx_fifo_data          ;
    logic       [CHANNELS-1:0]  ft601_rx_fifo_valid         ;
    
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

                .s_fifo_timeout     (ft601_tx_timeout           ),
                .s_fifo_enough_data (ft601_tx_enough_data       ),
                .s_fifo_strb        (ft601_tx_fifo_strb         ),
                .s_fifo_data        (ft601_tx_fifo_data         ),
                .s_fifo_valid       (ft601_tx_fifo_valid        ),
                .s_fifo_ready       (ft601_tx_fifo_ready        ),

                .m_fifo_almost_full (ft601_rx_fifo_almost_full  ),
                .m_fifo_enough_space(ft601_rx_fifo_enough_space ),
                .m_fifo_strb        (ft601_rx_fifo_strb         ),
                .m_fifo_data        (ft601_rx_fifo_data         ),
                .m_fifo_valid       (ft601_rx_fifo_valid        ),

                .rx_counter         (rx_counter                 ),
                .tx_counter         (tx_counter                 ),

                .mon_wr_n           (mon_wr_n                   ),
                .mon_rxf_n          (mon_rxf_n                  ),
                .mon_txe_n          (mon_txe_n                  ),
                .mon_be             (mon_be                     ),
                .mon_data           (mon_data                   )
            );


    // -------------------------------
    //  Command FIFO
    // -------------------------------

    for ( genvar i = 0; i < CHANNELS; i++ ) begin : gen_ch

        // RX FIFO
        logic  [RX_FIFO_PTR_BITS[i]:0]  fifo_rx_free_size   ;

        logic   [3:0]                   cmd_rx_fifo_strb    ;
        logic   [31:0]                  cmd_rx_fifo_data    ;
        logic                           cmd_rx_fifo_valid   ;
        logic                           cmd_rx_fifo_ready   ;

        jelly3_stream_fifo
                #(
                    .ASYNC          (ASYNC                  ),
                    .PTR_BITS       (RX_FIFO_PTR_BITS[i]    ),
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
            ft601_rx_fifo_almost_full[i]  <= fifo_rx_free_size < 64;
            ft601_rx_fifo_enough_space[i] <= fifo_rx_free_size >= (1 << RX_FIFO_PTR_BITS[i]) / 2;
        end

        // TX FIFO
        logic   [3:0]                   cmd_tx_fifo_strb    ;
        logic   [31:0]                  cmd_tx_fifo_data    ;
        logic                           cmd_tx_fifo_valid   ;
        logic                           cmd_tx_fifo_ready   ;

        logic  [TX_FIFO_PTR_BITS[i]:0]  fifo_tx_data_size   ;

        jelly3_stream_fifo
                #(
                    .ASYNC          (ASYNC                  ),
                    .PTR_BITS       (TX_FIFO_PTR_BITS[i]    ),
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
                    .m_data_size    (fifo_tx_data_size      )
                );

        always_ff @(posedge ft601_clk) begin
            ft601_tx_timeout[i]     <= tx_timeout[i];
            ft601_tx_enough_data[i] <= fifo_tx_data_size >= (TX_FIFO_PTR_BITS[i]+1)'(TX_THRESHOLD[i]);
        end
    end

endmodule


`default_nettype wire
