
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
            #(
                .USE_FT601_PLL      (0              )
            )
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

    int     rd_data_count = '0;
    int     rd_data;
    int     wr_data_count = '0;

    always_ff @(posedge ft601_clk) begin
        if ( !ft601_reset_n ) begin
            rd_data_count <= '0;
            rd_data       <= '0;
        end
        else begin
            // read
            if ( rd_data_count == 0 && $urandom_range(0, 99) < 2 ) begin
                rd_data_count <= $urandom_range(16, 32);
            end

            if ( ~ft601_rd_n && rd_data_count > 0 ) begin
                rd_data_count <= rd_data_count - 1'b1;
                rd_data       <= rd_data + 1;
            end

            // write
            if ( wr_data_count > 0 && $urandom_range(0, 99) < 2 ) begin
                wr_data_count <= 0;
            end

            if ( ~ft601_txe_n && ~ft601_wr_n ) begin
                $display("Write: %h", ft601_data);
                wr_data_count <= wr_data_count + 1'b1;
            end
        end
    end
    
    assign ft601_rxf_n = ~(rd_data_count > 0);
    assign ft601_txe_n = ~(wr_data_count < 64);
    assign ft601_data  = ~ft601_oe_n ? rd_data : 'z;
    assign ft601_be    = ~ft601_oe_n ? '1 : 'z;

endmodule


`default_nettype wire


// end of file
