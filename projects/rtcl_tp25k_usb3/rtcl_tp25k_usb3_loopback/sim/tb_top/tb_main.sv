
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
    wire            ft601_wakeup_n  ;
    logic           ft601_rxf_n     ;
    logic           ft601_txe_n = 0 ;
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

    rtcl_tp25k_usb3_loopback
        u_rtcl_tp25k_usb3_loopback
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
    logic   [3:0]   ft601_be_t      ;
    logic   [3:0]   ft601_be_o      ;
    logic   [3:0]   ft601_be_i      ;
    logic   [31:0]  ft601_data_t    ;
    logic   [31:0]  ft601_data_o    ;
    logic   [31:0]  ft601_data_i    ;

    for ( genvar i = 0; i < 4; i++ ) begin
        assign ft601_be  [i] = ft601_be_t[i] ? 1'bz            : ft601_be_o[i];
        assign ft601_be_i[i] = ft601_be_t[i] ? dly_ft601_be[i] : ft601_be[i];
    end
    for ( genvar i = 0; i < 32; i++ ) begin
        assign ft601_data  [i] = ft601_data_t[i] ? 1'bz              : ft601_data_o[i];
        assign ft601_data_i[i] = ft601_data_t[i] ? dly_ft601_data[i] : ft601_data_o[i];
    end

    initial begin
        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;
        for ( int i = 0; i < 500; i++ ) begin
            @(negedge ft601_clk);
        end

        // 受信
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ef00;
        @(negedge ft601_clk);

        while ( dly_ft601_wr_n != 1'b0 ) begin
            @(negedge ft601_clk);
        end
        @(negedge ft601_clk);
        @(negedge ft601_clk);

        for ( int i = 1; i < 11; i++ ) begin
            ft601_rxf_n  = 1'b0;
            ft601_be_t   = 4'h0         ;
            ft601_be_o   = 4'h1         ;
            ft601_data_t = 32'h0000_0000;
            ft601_data_o = 32'(i);
            @(negedge ft601_clk);
        end

        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf         ;
        ft601_be_o   = 4'h3         ;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;
        @(negedge ft601_clk);


        @(negedge ft601_clk);
        @(negedge ft601_clk);
        for ( int i = 0; i < 20; i++ ) begin
            @(negedge ft601_clk);
        end

        // 送信1
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_fe00;
        @(negedge ft601_clk);

        while ( dly_ft601_wr_n != 1'b0 ) begin
            @(negedge ft601_clk);
        end
        ft601_be_t   = 4'hf         ;
        ft601_data_t = 32'hffff_ffff;
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b0;

        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b1;
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf         ;
        ft601_be_o   = 4'h3         ;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;

        // interval
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);

        // 送信2
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_fe00;
        @(negedge ft601_clk);

        while ( dly_ft601_wr_n != 1'b0 ) begin
            @(negedge ft601_clk);
        end
        ft601_be_t   = 4'hf         ;
        ft601_data_t = 32'hffff_ffff;
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b0;

        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b1;
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf         ;
        ft601_be_o   = 4'h3         ;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;


        // end
        @(negedge ft601_clk);
        @(negedge ft601_clk);
        for ( int i = 0; i < 100; i++ ) begin
            @(negedge ft601_clk);
        end

        $finish;
    end
    


    /*
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
    */

endmodule


`default_nettype wire


// end of file
