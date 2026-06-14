
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

    logic           ft601_reset_n   ;
    logic           ft601_wakeup_n  ;
    logic           ft601_rxf_n     ;
    logic           ft601_txe_n     ;
    logic           ft601_siwu_n    ;
    logic           ft601_wr_n      ;
    logic           ft601_rd_n      ;
    logic           ft601_oe_n      ;
    logic   [3:0]   ft601_be        ;
    logic   [31:0]  ft601_data      ;
    logic   [1:0]   ft601_gpio      ;
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

                .mipi_pwr_en_n      (               ),
                .mipi_gpio          (               ),
                .mipi_scl           (               ),
                .mipi_sda           (               ),

                .push_sw            (push_sw        ),
                .dip_sw             (dip_sw         ),
                .led                (led            ),
                .pmod               (pmod           )
            );

    // -------------------------
    //  Simulation
    // -------------------------

    assign push_sw[0] = reset;
    assign push_sw[1] = 1'b0;

    logic [31:0] rx_fifo [$];

    initial begin
        // write
        rx_fifo.push_back(32'h0008_f0_02);
        rx_fifo.push_back(32'h0000_0100);
        rx_fifo.push_back(32'h1234_5678);

        // read
        rx_fifo.push_back(32'h0004_00_03);
        rx_fifo.push_back(32'h0000_0200);
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

    // 疑似送受信
    int     rd_data_count = '0;
    int     rd_data;
    int     wr_data_count = '0;

    always_ff @(negedge ft601_clk) begin
        if ( !ft601_reset_n ) begin
            rd_data_count <= '0;
            rd_data       <= '1;
        end
        else begin
            // read
            if ( ~dly_ft601_rd_n && rx_fifo.size() > 0 ) begin
//              rd_data <= rx_fifo[0];
                rx_fifo.pop_front();
            end

            // write
            if ( ~ft601_txe_n && ~dly_ft601_wr_n ) begin
            end
        end
    end
    
    assign ft601_rxf_n = ~(rx_fifo.size() > 0);
    assign ft601_txe_n = 1'b0;
    assign ft601_data  = ~dly_ft601_oe_n ? rx_fifo[0] : 'z;
    assign ft601_be    = ~dly_ft601_oe_n ? '1 : 'z;

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
