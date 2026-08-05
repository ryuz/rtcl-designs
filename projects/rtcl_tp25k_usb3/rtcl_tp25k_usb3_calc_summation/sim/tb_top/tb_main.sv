
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

    logic   [1:0]   push_sw         ;
    logic   [1:0]   dip_sw          ;
    logic   [3:0]   led             ;
    logic   [7:0]   pmod            ;

    rtcl_tp25k_usb3_calc_summation
        u_rtcl_tp25k_usb3_calc_summation
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
                .push_sw            (push_sw        ),
                .dip_sw             (dip_sw         ),
                .led                (led            ),
                .pmod               (pmod           )
            );

    always_comb force u_rtcl_tp25k_usb3_calc_summation.u_gowin_pll.clkout0  = clk100    ;


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

    task ft601_write(input int ch, input [31:0] data[]);
        begin
            $display("ft601_write: ch=%0d, data=%p", ch, data);
            @(negedge ft601_clk);
            ft601_rxf_n  = 1'b1;
            ft601_be_t   = 4'hf         ;
            ft601_be_o   = 4'hf         ;
            ft601_data_t = 32'hffff_00ff;
            ft601_data_o = 32'h0000_ff00 & ~(1 << (12+ch));
            @(negedge ft601_clk);

            while ( dly_ft601_wr_n != 1'b0 ) begin
                @(negedge ft601_clk);
            end
            @(negedge ft601_clk);
            @(negedge ft601_clk);

            for ( int i = 0; i < data.size(); i++ ) begin
                $display("data: data=%h", data[i]);

                ft601_rxf_n  = 1'b0;
                ft601_be_t   = 4'h0         ;
                ft601_be_o   = 4'h1         ;
                ft601_data_t = 32'h0000_0000;
                ft601_data_o = data[i]      ;
                @(negedge ft601_clk);
            end

            ft601_rxf_n  = 1'b1;
            ft601_be_t   = 4'hf         ;
            ft601_be_o   = 4'h0         ;
            ft601_data_t = 32'hffff_00ff;
            ft601_data_o = 32'h0000_ff00;
            @(negedge ft601_clk);
            @(negedge ft601_clk);
        end
    endtask

    task ft601_read(input int ch, input int size);
        ft601_rxf_n  = 1'b1;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00 & (~(1 << (8+ch)));
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
        for ( int i = 0; i < size; i++ ) begin
            @(negedge ft601_clk);
            $display("ft601_read: ch=%0d, data=%h, be=", ch, dly_ft601_data, dly_ft601_be);
        end
        ft601_rxf_n  = 1'b1;
        @(negedge ft601_clk);
        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf         ;
        ft601_be_o   = 4'h3         ;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;
    endtask

    task axi4l_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        begin
            automatic logic [31:0] header;
            header[7:0]   = 8'h02;    // write command
            header[11:8]  = '0;       // awprot
            header[15:12] = strb;     // write strobe
            header[31:16] = 16'h0008; // size
            ft601_write(0, '{header, addr, data});

            ft601_read(0, 1);
        end
    endtask

    task axi4l_read(input [31:0] addr);
        begin
            automatic logic [31:0] header;
            header[7:0]   = 8'h03;    // read command
            header[11:8]  = '0;       // arprot
            header[15:12] = '0;       // reserve
            header[31:16] = 16'h0004; // size
            ft601_write(0, '{header, addr});

            ft601_read(0, 2);
        end
    endtask

    logic [31:0] packet [1+10];

    initial begin
        ft601_rxf_n  = 1'b1;
        ft601_be_t   = 4'hf;
        ft601_data_t = 32'hffff_00ff;
        ft601_data_o = 32'h0000_ff00;
        for ( int i = 0; i < 500; i++ ) begin
            @(negedge ft601_clk);
        end

        axi4l_read(0);
        axi4l_read(4);

        #100;
        @(negedge ft601_clk);
        packet[0] = 32'h0028_8010;
        for ( int j = 0; j < 10; j++ ) begin
            packet[j+1] = j+1;
        end

        ft601_write(1, packet);
        #1000;

        ft601_read(1, 2);
        
        #10000;
        $finish;
    end




endmodule


`default_nettype wire


// end of file
