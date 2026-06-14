// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`default_nettype none

module rtcl_tp25k_usb3_fifo_sample
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup_n  ,
            input   var logic           ft601_clk       ,
            input   var logic           ft601_rxf_n     ,
            input   var logic           ft601_txe_n     ,
            output  var logic           ft601_siwu_n    ,
            output  var logic           ft601_wr_n      ,
            output  var logic           ft601_rd_n      ,
            output  var logic           ft601_oe_n      ,
            inout   tri logic   [3:0]   ft601_be        ,   
            inout   tri logic   [31:0]  ft601_data      ,
            inout   tri logic   [1:0]   ft601_gpio      ,

            input   var logic   [1:0]   push_sw         ,
            input   var logic   [1:0]   dip_sw          ,
            output  var logic   [3:0]   led             ,
            output  var logic   [7:0]   pmod            
        );
    
    // reset switch
    logic in_reset;
    assign in_reset = push_sw[0];

    logic   clk;
    assign clk = in_clk50;

    // generate reset
    logic           reset       = 1'b1;
    logic   [7:0]   reset_count = '1;
    always_ff @(posedge clk or posedge in_reset) begin
        if ( in_reset ) begin
            reset       <= 1'b1;
            reset_count <= '1;
        end
        else begin
            if ( reset_count > 0 ) begin
                reset_count <= reset_count - 1'b1;
            end
            reset <= reset_count != 0;
        end
    end


    logic ft601_reset;
    jelly3_reset_async
        #(
                .IN_LOW_ACTIVE      (0              ),
                .OUT_LOW_ACTIVE     (0              ),
                .ASYNC_REGS         (3              )
            )
        u_reset_async_ft601
            (
                .clk                (ft601_clk      ),
                .cke                (1'b1           ),
                .in_reset           (reset          ),
                .out_reset          (ft601_reset    )
            );


    // LED
    logic   [24:0]  clk_counter;
    always_ff @(posedge in_clk50) begin
        clk_counter <= clk_counter + 1'b1;
    end

    logic   [26:0]  usb_counter;
    always_ff @(posedge ft601_clk) begin
        usb_counter <= usb_counter + 1'b1;
    end



    assign led[0] = clk_counter[24] ;
    assign led[1] = usb_counter[26] ;
    assign led[2] = ft601_wakeup_n  ;
    assign led[3] = reset           ;



    // -------------------------------
    //  FT601
    // -------------------------------

    assign ft601_reset_n  = ~reset  ;
    assign ft601_wakeup_n = 1'bz    ;
    assign ft601_gpio     = 2'b00   ;   // 245 Synchrounous FIFO Mode
    assign ft601_siwu_n   = 1'b1    ;
 
    logic   [3:0]   ft601_be_i      ;
    logic   [3:0]   ft601_be_o      ;
    logic   [3:0]   ft601_be_t      ;
    for (genvar i = 0; i < 4; i++) begin : iob_be
        IOBUF
            u_iobuf_be
                (
                    .O  (ft601_be_i[i]),
                    .IO (ft601_be  [i]),
                    .I  (ft601_be_o[i]),
                    .OEN(ft601_be_t[i])
                );
    end

    logic   [31:0]  ft601_data_i            ;
    logic   [31:0]  ft601_data_o  = '0  ;
    logic   [31:0]  ft601_data_t  = '1  ;
    for (genvar i = 0; i < 32; i++) begin : iob_data
        IOBUF
            u_iobuf_data
                (
                    .O  (ft601_data_i[i]),
                    .IO (ft601_data  [i]),
                    .I  (ft601_data_o[i]),
                    .OEN(ft601_data_t[i])
                );
    end


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

    localparam RX_FIFO_PTR_BITS = 8;
    localparam TX_FIFO_PTR_BITS = 8;

    // RX FIFO
    logic  [RX_FIFO_PTR_BITS:0] fifo_rx_free_size   ;

    logic   [3:0]               cmd_rx_fifo_strb    ;
    logic   [31:0]              cmd_rx_fifo_data    ;
    logic                       cmd_rx_fifo_valid   ;
    logic                       cmd_rx_fifo_ready   ;

    jelly3_stream_fifo
            #(
                .ASYNC          (1                  ),
                .PTR_BITS       (RX_FIFO_PTR_BITS   ),
                .DATA_BITS      (4+32               ),
                .S_SYNC_FF      (3                  ),
                .M_SYNC_FF      (3                  ),
                .RAM_TYPE       ("block"            ),
                .DOUT_REG       (1                  )
            )
        u_stream_fifo_rx
            (
                .s_reset        (ft601_reset        ),
                .s_clk          (ft601_clk          ),
                .s_cke          (1'b1               ),
                .s_data         ({
                                    ft601_rx_fifo_strb,
                                    ft601_rx_fifo_data
                                }),
                .s_valid        (ft601_rx_fifo_valid),
                .s_ready        (),
                .s_free_size    (fifo_rx_free_size  ),

                .m_reset        (reset        ),
                .m_clk          (clk          ),
                .m_cke          (1'b1               ),
                .m_data         ({
                                    cmd_rx_fifo_strb,
                                    cmd_rx_fifo_data
                                }),
                .m_valid        (cmd_rx_fifo_valid  ),
                .m_ready        (cmd_rx_fifo_ready  ),
                .m_data_size    (                   )
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
                .ASYNC          (1                  ),
                .PTR_BITS       (TX_FIFO_PTR_BITS   ),
                .DATA_BITS      (4+32               ),
                .S_SYNC_FF      (3                  ),
                .M_SYNC_FF      (3                  ),
                .RAM_TYPE       ("block"            ),
                .DOUT_REG       (1                  )
            )
        u_stream_fifo_tx
            (
                .s_reset        (reset              ),
                .s_clk          (clk                ),
                .s_cke          (1'b1               ),
                .s_data         ({
                                    cmd_tx_fifo_strb,
                                    cmd_tx_fifo_data
                                }),
                .s_valid        (cmd_tx_fifo_valid  ),
                .s_ready        (cmd_tx_fifo_ready  ),
                .s_free_size    (                   ),

                .m_reset        (ft601_reset        ),
                .m_clk          (ft601_clk          ),
                .m_cke          (1'b1               ),
                .m_data         ({
                                    ft601_tx_fifo_strb,
                                    ft601_tx_fifo_data
                                }),
                .m_valid        (ft601_tx_fifo_valid),
                .m_ready        (ft601_tx_fifo_ready),
                .m_data_size    (                   )
            );
    
    // --------------------------------
    //  Commnand processing
    // --------------------------------

    jelly3_axi4l_if
            #(
                .ADDR_BITS      (32     ),
                .DATA_BITS      (32     )
            )
        axi4l
            (
                .aresetn        (~reset ),
                .aclk           (clk    ),
                .aclken         (1'b1   )
            );

    fifo32_cmd_axi4l
        u_fifo32_cmd_axi4l
            (
                .reset          (reset              ),
                .clk            (clk                ),
                .cke            (1'b1               ),

                .s_rx_data      (cmd_rx_fifo_data   ),
                .s_rx_valid     (cmd_rx_fifo_valid  ),
                .s_rx_ready     (cmd_rx_fifo_ready  ),

                .m_tx_data      (cmd_tx_fifo_data   ),
                .m_tx_valid     (cmd_tx_fifo_valid  ),
                .m_tx_ready     (cmd_tx_fifo_ready  ),
                
                .m_axi4l        (axi4l              )
            );
    assign cmd_tx_fifo_strb = '1;

    jelly3_i2c
            #(
                .DIVIDER_BITS   (16                 )
            )
        u_i2c
            (
                .i2c_scl_t      (                   ),
                .i2c_scl_i      (                   ),
                .i2c_sda_t      (                   ),
                .i2c_sda_i      (                   ),

                .s_axi4l        (axi4l              ),
                .irq            (                   )
            );


    assign pmod[7:0] = 0   ;

endmodule


`default_nettype wire
