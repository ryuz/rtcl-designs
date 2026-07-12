
`timescale 1ns / 1ps
`default_nettype none

module tb_main
        (
            input   var logic   reset       ,
            input   var logic   clk50       ,
            input   var logic   clk100      ,
            input   var logic   ft601_clk   ,
            input   var logic   dphy_clk    
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

    wire            mipi_ck_p       ;
    wire            mipi_ck_n       ;
    wire    [3:0]   mipi_d_p        ;
    wire    [3:0]   mipi_d_n        ;
    wire            mipi_scl        ;
    wire            mipi_sda        ;
    wire    [1:0]   mipi_gpio       ;
    logic           mipi_pwr_en_n   ;

    logic   [1:0]   push_sw         ;
    logic   [1:0]   dip_sw          ;
    logic   [3:0]   led             ;
    logic   [7:0]   pmod            ;

    rtcl_tp25k_usb3_imx219_mipi
        u_rtcl_tp25k_usb3_imx219_mipi
            (
                .in_clk50           (clk50          ),
                .ft601_reset_n      (ft601_reset_n  ),
                .ft601_wakeup_n     (ft601_wakeup_n ),
                .ft601_clk_in       (ft601_clk      ),
                .ft601_rxf_n        (ft601_rxf_n    ),
                .ft601_txe_n        (ft601_txe_n    ),
                .ft601_siwu_n       (ft601_siwu_n   ),
                .ft601_wr_n         (ft601_wr_n     ),
                .ft601_rd_n         (ft601_rd_n     ),
                .ft601_oe_n         (ft601_oe_n     ),
                .ft601_be           (ft601_be       ),
                .ft601_data         (ft601_data     ),
                .ft601_gpio         (ft601_gpio     ),
                .mipi_ck_p          (mipi_ck_p      ),
                .mipi_ck_n          (mipi_ck_n      ),
                .mipi_d_p           (mipi_d_p       ),
                .mipi_d_n           (mipi_d_n       ),
                .mipi_scl           (mipi_scl       ),
                .mipi_sda           (mipi_sda       ),
                .mipi_gpio          (mipi_gpio      ),
                .mipi_pwr_en_n      (mipi_pwr_en_n  ),
                .push_sw            (push_sw        ),
                .dip_sw             (dip_sw         ),
                .led                (led            ),
                .pmod               (pmod           )
            );

    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_gowin_pll.clkout0  = clk100    ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.rx_clk_o = dphy_clk  ;


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

        // Read Command
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ef00;
        @(negedge ft601_clk);

        while ( dly_ft601_wr_n != 1'b0 ) begin
            @(negedge ft601_clk);
        end
        @(negedge ft601_clk);
        @(negedge ft601_clk);

        ft601_rxf_n  = 1'b0;
        ft601_be_t   = 4'h0         ;
        ft601_be_o   = 4'h1         ;
        ft601_data_t = 32'h0000_0000;
        ft601_data_o = 32'h0004_0003;   // read command
        @(negedge ft601_clk);

        ft601_rxf_n  = 1'b0;
        ft601_be_t   = 4'h0         ;
        ft601_be_o   = 4'h1         ;
        ft601_data_t = 32'h0000_0000;
        ft601_data_o = 32'h0000_0000;   // read address
        @(negedge ft601_clk);

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

        // Ack
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

        #10000
        @(negedge ft601_clk);

        // Write Command
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ef00;
        @(negedge ft601_clk);

        while ( dly_ft601_wr_n != 1'b0 ) begin
            @(negedge ft601_clk);
        end
        @(negedge ft601_clk);
        @(negedge ft601_clk);

        ft601_rxf_n  = 1'b0;
        ft601_be_t   = 4'h0         ;
        ft601_be_o   = 4'h1         ;
        ft601_data_t = 32'h0000_0000;
        ft601_data_o = 32'h0008_f002;   // write command
        @(negedge ft601_clk);

        ft601_rxf_n  = 1'b0;
        ft601_be_t   = 4'h0         ;
        ft601_be_o   = 4'h1         ;
        ft601_data_t = 32'h0000_0000;
        ft601_data_o = 32'h0004_0040;   // write address
        @(negedge ft601_clk);

        ft601_rxf_n  = 1'b0;
        ft601_be_t   = 4'h0         ;
        ft601_be_o   = 4'h1         ;
        ft601_data_t = 32'h0000_0000;
        ft601_data_o = 32'h0000_0001;   // write data
        @(negedge ft601_clk);

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

        // Ack
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

        #100000;
        @(negedge ft601_clk);

        for ( int i = 0; i < 3; i++ ) begin

            // 画像受信
            ft601_rxf_n  = 1'b1;
            ft601_data_t = 32'hffff_00ff;
            ft601_data_o = 32'h0000_fd00;
            @(negedge ft601_clk);


            while ( dly_ft601_wr_n != 1'b0 ) begin
                @(negedge ft601_clk);
            end
            ft601_be_t   = 4'hf         ;
            ft601_data_t = 32'hffff_ffff;
            @(negedge ft601_clk);
            ft601_rxf_n  = 1'b0;

            while ( dly_ft601_wr_n == 1'b0 ) begin
                @(negedge ft601_clk);
            end
            ft601_rxf_n  = 1'b1;
            ft601_data_t = 32'hffff_00ff;
            ft601_data_o = 32'h0000_fd00;
        end

        #1000;
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

        #100000;

        $finish;
    end



    logic   [7:0]   d0ln_hsrxd          ;
    logic   [7:0]   d1ln_hsrxd          ;
    logic           d0ln_hsrxd_vld      ;
    logic           d1ln_hsrxd_vld      ;
    logic           di_lprx0_n          ;
    logic           di_lprx0_p          ;
    logic           di_lprx1_n          ;
    logic           di_lprx1_p          ;

    initial begin
        d0ln_hsrxd      = '0;
        d1ln_hsrxd      = '0;
        d0ln_hsrxd_vld  = '0;
        d1ln_hsrxd_vld  = '0;
        di_lprx0_n      = 1;
        di_lprx0_p      = 1;
        di_lprx1_n      = 1;
        di_lprx1_p      = 1;
        #10000;

        forever begin
            #1000;
            @(negedge dphy_clk);
            di_lprx0_n      = 1;
            di_lprx0_p      = 1;
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            di_lprx0_n      = 1;
            di_lprx0_p      = 0;
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            di_lprx0_n      = 0;
            di_lprx0_p      = 0;
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            d0ln_hsrxd_vld = 1;
            d1ln_hsrxd_vld = 1;
            d0ln_hsrxd = 8'hb8;
            d1ln_hsrxd = 8'hb8;
            @(negedge dphy_clk);
            d0ln_hsrxd = 8'h00;
            d1ln_hsrxd = 8'h00;
            @(negedge dphy_clk);
            d0ln_hsrxd = 8'h00;
            d1ln_hsrxd = 8'h00;
            @(negedge dphy_clk);
            @(negedge dphy_clk);
            di_lprx0_n      = 1;
            di_lprx0_p      = 1;
            d0ln_hsrxd_vld  = 0;
            d1ln_hsrxd_vld  = 0;
            @(negedge dphy_clk);
            @(negedge dphy_clk);

            for ( int i = 0; i < 100; i++ ) begin
                #10000;
                @(negedge dphy_clk);
                di_lprx0_n      = 1;
                di_lprx0_p      = 1;
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                di_lprx0_n      = 1;
                di_lprx0_p      = 0;
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                di_lprx0_n      = 0;
                di_lprx0_p      = 0;
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                d0ln_hsrxd_vld = 1;
                d1ln_hsrxd_vld = 1;
                d0ln_hsrxd = 8'hb8;
                d1ln_hsrxd = 8'hb8;
                @(negedge dphy_clk);
                d0ln_hsrxd = 8'h2b;
                d1ln_hsrxd = 8'h40;
                @(negedge dphy_clk);
                d0ln_hsrxd = 8'h06;
                d1ln_hsrxd = 8'h00;
                @(negedge dphy_clk);
                for ( int j = 0; j < 'h640 / 2; j++ ) begin
                    d0ln_hsrxd = 8'((j >> 0) & 8'hff);
                    d1ln_hsrxd = 8'((j >> 8) & 8'hff);
                    @(negedge dphy_clk);
                end
                d0ln_hsrxd = 0;
                d1ln_hsrxd = 0;
                @(negedge dphy_clk);
                d0ln_hsrxd = 0;
                d1ln_hsrxd = 0;
                @(negedge dphy_clk);
                d0ln_hsrxd = 0;
                d1ln_hsrxd = 0;
                @(negedge dphy_clk);

                di_lprx0_n      = 1;
                di_lprx0_p      = 1;
                d0ln_hsrxd_vld  = 0;
                d1ln_hsrxd_vld  = 0;
                @(negedge dphy_clk);
                @(negedge dphy_clk);
                @(negedge dphy_clk);
            end
        end
    end

    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.d0ln_hsrxd     = d0ln_hsrxd          ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.d1ln_hsrxd     = d1ln_hsrxd          ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.d0ln_hsrxd_vld = d0ln_hsrxd_vld      ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.d1ln_hsrxd_vld = d1ln_hsrxd_vld      ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.di_lprx0_n     = di_lprx0_n          ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.di_lprx0_p     = di_lprx0_p          ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.di_lprx1_n     = di_lprx1_n          ;
    always_comb force u_rtcl_tp25k_usb3_imx219_mipi.u_mipi_dphy.di_lprx1_p     = di_lprx1_p          ;

endmodule


`default_nettype wire


// end of file
