
`timescale 1ns / 1ps
`default_nettype none

module tb_main
        (
            input   var logic   reset       ,
            input   var logic   clk         ,
            input   var logic   ft601_clk   
        );

    // -------------------------
    //  DUT
    // -------------------------

    wire            ft601_reset_n   ;
    wire            ft601_wakeup_n  ;
    logic           ft601_rxf_n     ;
    logic           ft601_txe_n     ;
    logic           ft601_siwu_n    ;
    logic           ft601_wr_n      ;
    logic           ft601_rd_n      ;
    logic           ft601_oe_n      ;
    wire    [3:0]   ft601_be        ;
    wire    [31:0]  ft601_data      ;
    wire    [1:0]   ft601_gpio      ;
    logic   [1:0]   push_sw         ;
    logic   [1:0]   dip_sw          ;
    logic   [3:0]   led             ;
    logic   [7:0]   pmod            ;

    rtcl_tp25k_usb3_fifo_sample
        u_rtcl_tp25k_usb3_fifo_sample
            (
                .in_clk50           (clk            ),

                .ft601_reset_n      (ft601_reset_n  ),
                .ft601_wakeup_n     (ft601_wakeup_n ),
                .ft601_clk          (ft601_clk      ),
                .ft601_rxf_n        (ft601_rxf_n    ),
                .ft601_txe_n        (ft601_txe_n    ),
                .ft601_siwu_n       (ft601_siwu_n   ),
                .ft601_wr_n         (ft601_wr_n     ),
                .ft601_rd_n         (ft601_rd_n     ),
                .ft601_oe_n         (ft601_oe_n     ),
                .ft601_be           (ft601_be       ),
                .ft601_data         (ft601_data     ),
                .ft601_gpio         (ft601_gpio     ),

                .mipi_ck_p          (               ),
                .mipi_ck_n          (               ),
                .mipi_d_p           (               ),
                .mipi_d_n           (               ),
                .mipi_scl           (               ),
                .mipi_sda           (               ),
                .mipi_gpio          (               ),
                .mipi_pwr_en_n      (               ),

                .push_sw            (push_sw        ),
                .dip_sw             (dip_sw         ),
                .led                (led            ),
                .pmod               (pmod           )
            );

    // -------------------------
    //  Simulation
    // -------------------------

    logic   [31:0]  cmd_data    ;
    logic           cmd_valid   ;
    logic           cmd_ready   ;

    logic   [31:0]  rx_data     ;
    logic           rx_valid    ;
    logic           rx_ready    ;

    jelly3_stream_fifo
            #(
                .ASYNC          (0              ),
                .PTR_BITS       (10             ),
                .DATA_BITS      (32             )
            )
        u_stream_fifo
            (
                .s_reset        (~ft601_reset_n ),
                .s_clk          (ft601_clk      ),
                .s_cke          (1'b1           ),
                .s_data         (cmd_data       ),
                .s_valid        (cmd_valid      ),
                .s_ready        (cmd_ready      ),
                .s_free_size    (               ),
                
                .m_reset        (~ft601_reset_n ),
                .m_clk          (ft601_clk      ),
                .m_cke          (1'b1           ),
                .m_data         (rx_data        ),
                .m_valid        (rx_valid       ),
                .m_ready        (rx_ready       ),
                .m_data_size    (               )
        );


    assign push_sw[0] = reset;
    assign push_sw[1] = 1'b0;

    initial begin
        cmd_valid = 1'b0;

        #10000;
        $display("write");
        @(negedge ft601_clk); cmd_valid = 1'b1; cmd_data = 32'h0008_f0_02;
        @(negedge ft601_clk); cmd_valid = 1'b1; cmd_data = 32'h0000_0100;
        @(negedge ft601_clk); cmd_valid = 1'b1; cmd_data = 32'h1234_5678;
        @(negedge ft601_clk); cmd_valid = 1'b0;

        #2000;
        $display("read");
        @(negedge ft601_clk); cmd_valid = 1'b1; cmd_data = 32'h0004_00_03;
        @(negedge ft601_clk); cmd_valid = 1'b1; cmd_data = 32'h0000_0000;
        @(negedge ft601_clk); cmd_valid = 1'b0;
    end


    // FPGA側は posedge で出してくるので negedge で受けて遅延させる。 verilator でも使える。
    logic           dly_ft601_wr_n      ;
    logic           dly_ft601_rd_n      ;
    logic           dly_ft601_oe_n      ;
    logic   [3:0]   dly_ft601_be        ;
    logic   [31:0]  dly_ft601_data      ;
    always_ff @(negedge ft601_clk) begin
        dly_ft601_wr_n <= ft601_wr_n    ;
        dly_ft601_rd_n <= ft601_rd_n    ;
        dly_ft601_oe_n <= ft601_oe_n    ;
        dly_ft601_be   <= ft601_be      ;
        dly_ft601_data <= ft601_data    ;
    end

  
    assign ft601_rxf_n = ~rx_valid;
    assign ft601_txe_n = 1'b0;
    assign ft601_data  = ~dly_ft601_oe_n ? rx_data : 'z;
    assign ft601_be    = ~dly_ft601_oe_n ? '1 : 'z;
    assign rx_ready    = ~dly_ft601_rd_n;

    // logging
    int fp_tx = 0;
    int fp_rx = 0;
    initial begin
        fp_tx = $fopen("tx_log.txt", "w");
        fp_rx = $fopen("rx_log.txt", "w");
    end

    always_ff @(negedge ft601_clk) begin
        if ( ft601_reset_n ) begin
            if ( ~ft601_rxf_n && ~dly_ft601_rd_n && ~dly_ft601_oe_n ) begin
                $fdisplay(fp_rx, "%h", ft601_data);
            end
        end
    end

    always_ff @(negedge ft601_clk) begin
        if ( ft601_reset_n ) begin
            if ( ~ft601_txe_n && ~dly_ft601_wr_n ) begin
                $fdisplay(fp_tx, "%h", dly_ft601_data);
            end
        end
    end

endmodule


`default_nettype wire


// end of file
