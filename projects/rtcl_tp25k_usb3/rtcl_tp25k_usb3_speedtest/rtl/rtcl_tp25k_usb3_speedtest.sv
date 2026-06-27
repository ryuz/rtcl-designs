// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module rtcl_tp25k_usb3_speedtest
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

    // generate reset
    logic           reset       = 1'b1;
    logic   [7:0]   reset_count = '1;
    always_ff @(posedge in_clk50 or posedge in_reset) begin
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

    logic   clk;
    assign clk = in_clk50;


    // -------------------------------
    //  FT601
    // -------------------------------

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

    assign ft601_reset_n  = ~reset  ;
    assign ft601_wakeup_n = 1'bz    ;
    assign ft601_gpio     = 2'b01   ;   // 1 channel, Multi-Channel FIFO mode
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


    jelly3_axi4s_if
            #(
                .USE_STRB   (1              ),
                .USE_LAST   (0              ),
                .DATA_BITS  (32             )
            )
        axi4s_ft601_rx [1]
            (
                .aresetn    (~ft601_reset   ),
                .aclk       (ft601_clk      ),
                .aclken     (1'b1           )
            );

    jelly3_axi4s_if
            #(
                .USE_STRB   (1              ),
                .USE_LAST   (0              ),
                .DATA_BITS  (32             )
            )
        axi4s_ft601_tx [1]
            (
                .aresetn    (~ft601_reset   ),
                .aclk       (ft601_clk      ),
                .aclken     (1'b1           )
            );

    ft601_multi_ch_mode
            #(
                .CHANNELS           (1                          )
            )
        u_ft601_multi_ch_mode
            (
                .ft601_reset        (ft601_reset                ),
                .ft601_clk          (ft601_clk                  ),
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

                .s_axi4s_tx         (axi4s_ft601_tx             ),
                .m_axi4s_rx         (axi4s_ft601_rx             )

            );


    // -------------------------------
    //  RX
    // -------------------------------

    logic   [31:0]  lfsr_rx;
    jelly3_lfsr
            #(
                .DATA_BITS      (32                         ),
                .INIT           (32'h1234_5678              )
            )
        u_lfsr_rx
            (
                .reset          (ft601_reset                ),
                .clk            (ft601_clk                  ),
                .cke            (1'b1                       ),
                
                .update         (axi4s_ft601_rx[0].tvalid   ),
                .clear          (1'b0                       ),
                .clear_value    (                           ),
                .polynomial     (32'h8020_0003              ), // 32, 22, 2, 1
                
                .dout           (lfsr_rx                    )
            );

    assign axi4s_ft601_rx[0].tready = 1'b1;

    logic       rx_error;
    always_ff @(posedge axi4s_ft601_rx[0].aclk ) begin
        if ( ~axi4s_ft601_rx[0].aresetn ) begin
            rx_error <= 1'b0;
        end
        else if ( axi4s_ft601_rx[0].aclken ) begin
            if ( axi4s_ft601_rx[0].tvalid && axi4s_ft601_rx[0].tready ) begin
                if ( axi4s_ft601_rx[0].tdata != lfsr_rx ) begin
                    rx_error <= 1'b1;
                end
            end
        end
    end

    // -------------------------------
    //  TX
    // -------------------------------

    logic   [31:0]  lfsr_tx;
    jelly3_lfsr
            #(
                .DATA_BITS      (32                         ),
                .INIT           (32'h1234_5678              )
            )
        u_lfsr_tx
            (
                .reset          (ft601_reset                ),
                .clk            (ft601_clk                  ),
                .cke            (1'b1                       ),
                
                .update         (axi4s_ft601_tx[0].tvalid
                                && axi4s_ft601_tx[0].tready ),
                .clear          (1'b0                       ),
                .clear_value    (                           ),
                .polynomial     (32'h8020_0002              ), // 32, 22, 2
                
                .dout           (lfsr_tx                    )
            );

    assign axi4s_ft601_tx[0].tdata  = lfsr_tx;
    assign axi4s_ft601_tx[0].tstrb  = 4'b1111;
    assign axi4s_ft601_tx[0].tvalid = 1'b1;
    


    // -------------------------------
    //  LED
    // -------------------------------

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
    assign led[2] = rx_error        ;
    assign led[3] = reset           ;


    // PMOD
    assign pmod[0] = ft601_rxf_n;
    assign pmod[1] = ft601_txe_n;
    assign pmod[2] = ft601_wr_n;
    assign pmod[3] = '0;
    assign pmod[4] = ft601_data_i[8];
    assign pmod[5] = ft601_data_i[9];
    assign pmod[6] = ft601_data_i[12];
    assign pmod[7] = ft601_data_i[13];


endmodule


`default_nettype wire
