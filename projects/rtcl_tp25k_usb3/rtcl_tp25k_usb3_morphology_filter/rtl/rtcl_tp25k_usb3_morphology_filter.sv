// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module rtcl_tp25k_usb3_morphology_filter
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup_n  ,
            input   var logic           ft601_clk_in    ,
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
    logic           self_reset       = 1'b1;
    logic   [7:0]   self_reset_count = '1;
    always_ff @(posedge in_clk50 or posedge in_reset) begin
        if ( in_reset ) begin
            self_reset       <= 1'b1;
            self_reset_count <= '1;
        end
        else begin
            if ( self_reset_count > 0 ) begin
                self_reset_count <= self_reset_count - 1'b1;
            end
            self_reset <= self_reset_count != 0;
        end
    end

    logic       clk     ;
    logic       lock    ;
    Gowin_PLL
        u_gowin_pll
            (
                .clkin      (in_clk50   ),
                .clkout0    (clk        ),
                .lock       (lock       ),
                .mdclk      (in_clk50   ),
                .reset      (self_reset )
            );

    logic       reset   ;
    jelly3_reset_async
            #(
                .IN_LOW_ACTIVE      (0                  ),
                .OUT_LOW_ACTIVE     (0                  )
            )
        u_reset_async
            (
                .clk                (clk                ),
                .cke                (1'b1               ),
                .in_reset           (self_reset || ~lock),
                .out_reset          (reset              )
            );


    // -------------------------------
    //  FT601
    // -------------------------------

    logic   ft601_clk   ;
    logic   ft601_lock  ;
    gowin_pll_ft601
        u_gowin_pll_ft601
            (
                .clkin              (ft601_clk_in   ),
                .clkout0            (ft601_clk      ),
                .lock               (ft601_lock     ),
                .mdclk              (in_clk50       ),
                .reset              (reset          )
            );

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
    assign ft601_gpio     = 2'b11   ;   // 4 channel, Multi-Channel FIFO mode
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

    logic   [31:0]  ft601_data_i        ;
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
                .USE_STRB   (1      ),
                .USE_LAST   (0      ),
                .DATA_BITS  (32     )
            )
        axi4s_ft601_rx [2]
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );

    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (0      ),
                .DATA_BITS  (32     )
            )
        axi4s_ft601_tx [2]
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );

    ft601_multi_ch_mode
            #(
                .CHANNELS           (2                          )
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


    // --------------------------------
    //  AXI4-Lite (ch0)
    // --------------------------------

    jelly3_axi4l_if
            #(
                .ADDR_BITS      (32     ),
                .DATA_BITS      (32     )
            )
        axi4l_host
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

                .s_axi4s_rx     (axi4s_ft601_rx[0].s),
                .m_axi4s_tx     (axi4s_ft601_tx[0].m),
                
                .m_axi4l        (axi4l_host         )
            );



    // ----------------------------------------
    //  Address decoder
    // ----------------------------------------

    localparam DEC_CTL  = 0;
    localparam DEC_IMG  = 1;
    localparam DEC_NUM  = 2;

    jelly3_axi4l_if
            #(
                .ADDR_BITS      (32         ),
                .DATA_BITS      (32         )
            )
        axi4l_dec [DEC_NUM]
            (
                .aresetn        (~reset     ),
                .aclk           (clk        ),
                .aclken         (1'b1       )
            );
    
    // address map
    assign {axi4l_dec[DEC_CTL].addr_base, axi4l_dec[DEC_CTL].addr_high} = {32'h0000_0000, 32'h0000_ffff};
    assign {axi4l_dec[DEC_IMG].addr_base, axi4l_dec[DEC_IMG].addr_high} = {32'h1000_0000, 32'h1fff_ffff};

    jelly3_axi4l_addr_decoder
            #(
                .NUM            (DEC_NUM    ),
                .DEC_ADDR_BITS  (32         )
            )
        u_axi4l_addr_decoder
            (
                .s_axi4l        (axi4l_host ),
                .m_axi4l        (axi4l_dec  )
            );

    // ----------------------------------------
    //  System Control
    // ----------------------------------------

    logic   [31:0]      control0;
    logic   [31:0]      control1;
    logic   [31:0]      control2;
    logic   [31:0]      control3;
    logic   [31:0]      control4;
    logic   [31:0]      control5;
    jelly3_system_control
        #(
                .DATA_BITS          (32                 ),
                .CORE_ID            (32'h527a_0001      ),
                .CORE_VERSION       (32'h0003_0001      ),
                .INIT_CONTROL0      (128/32             ),  // width
                .INIT_CONTROL1      (128                ),  // height
                .INIT_CONTROL2      ('0                 ),
                .INIT_CONTROL3      (512                ),  // max_len
                .INIT_CONTROL4      (0                  ),  // limit_len
                .INIT_CONTROL5      (0                  ),  // timeout
                .INIT_CONTROL6      ('0                 ),
                .INIT_CONTROL7      ('0                 )
            )
        u_system_control
            (
                .s_axi4l            (axi4l_dec[DEC_CTL] ),

                .control0           (control0           ),
                .control1           (control1           ),
                .control2           (control2           ),
                .control3           (control3           ),
                .control4           (control4           ),
                .control5           (control5           ),
                .control6           (                   ),
                .control7           (                   ),

                .monitor0           ('0                 ),
                .monitor1           ('0                 ),
                .monitor2           ('0                 ),
                .monitor3           ('0                 ),
                .monitor4           ('0                 ),
                .monitor5           ('0                 ),
                .monitor6           ('0                 ),
                .monitor7           ('0                 )
            );


    // --------------------------------
    //  Image Processing
    // --------------------------------

    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (1      ),
                .DATA_BITS  (32     )
            )
        axi4s_stream_rx
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );
    
    fifo32_cmd_axi4s_rx
        u_fifo32_cmd_axi4s_rx
            (
                .s_axi4s        (axi4s_ft601_rx[1].s),
                .m_axi4s        (axi4s_stream_rx.m  )
            );

    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (1      ),
                .DATA_BITS  (32     )
            )
        axi4s_stream_tx
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );

    fifo32_cmd_axi4s_tx
            #(
                .ASYNC          (1                  ),
                .DATA_BUF_SIZE  (1024               ),
                .CMD_BUF_SIZE   (128                ),
                .TIMER_BITS     (16                 )
            )
        u_fifo32_cmd_axi4s_tx
            (
                .max_len        (control3[10:0]     ),
                .limit_len      (control4[10:0]     ),
                .timeout        (control5[15:0]     ),

                .s_axi4s        (axi4s_stream_tx.s  ),
                .m_axi4s        (axi4s_ft601_tx[1].m)
            );


    image_processing
            #(
                .WIDTH_BITS     (16                     ),
                .HEIGHT_BITS    (16                     ),
                .FILTER_NUM     (4                      ),
                .FILTER_ROWS    (3                      ),
                .FILTER_COLS    (3                      ),
                .TAPS           (32                     ),
                .MAX_COLS       (512                    ),
                .RAM_TYPE       ("block"                ),
                .BYPASS_SIZE    (1'b1                   ),
                .DEVICE         ("RTL"                  )
            )
        u_image_processing
            (
                .in_update_req  (1'b1                   ),
                .param_width    (control0[15:0]         ),
                .param_height   (control1[15:0]         ),

                .s_axi4s        (axi4s_stream_rx.s      ),
                .m_axi4s        (axi4s_stream_tx.m      ),
                
                .s_axi4l        (axi4l_dec[DEC_IMG].s   )
            );



    // --------------------------------
    //  LED
    // --------------------------------

    logic   [24:0]  clk_counter;
    always_ff @(posedge in_clk50) begin
        clk_counter <= clk_counter + 1'b1;
    end

    logic   [26:0]  usb_counter;
    always_ff @(posedge ft601_clk) begin
        usb_counter <= usb_counter + 1'b1;
    end

    logic   pkt_error;
    fifo32_cmd_axi4s_checker
            #(
                .MIN_PACKET_SIZE    (4                      ),
                .MAX_PACKET_SIZE    (4096                   )
            )
        u_fifo32_cmd_axi4s_checker
            (
                .mon_axi4s          (axi4s_ft601_tx[1].mon  ),

                .error              (pkt_error              )
            );

    assign led[0] = clk_counter[24] ;
    assign led[1] = usb_counter[26] ;
    assign led[2] = pkt_error       ;
    assign led[3] = 0               ;


    // --------------------------------
    //  PMOD
    // --------------------------------

    
    assign pmod[0] = ft601_rxf_n;
    assign pmod[1] = ft601_wr_n;
    assign pmod[2] = axi4s_ft601_rx[1].tready;
    assign pmod[3] = axi4s_ft601_rx[1].tvalid;
    assign pmod[4] = axi4s_ft601_tx[1].tready;
    assign pmod[5] = axi4s_ft601_tx[1].tvalid;
    assign pmod[6] = ft601_data_i[9];   // tx[1]
    assign pmod[7] = ft601_data_i[13];  // rx[1]

    /*
    assign pmod[0] = dphy_byte_ready;
    assign pmod[1] = dphy_hsrxd_vld[0];
    assign pmod[2] = dphy_hsrxd_vld[1];
    assign pmod[3] = '0;
    assign pmod[4] = '0;
    assign pmod[5] = '0;
    assign pmod[6] = '0;
    assign pmod[7] = '0;
    */

endmodule


`default_nettype wire
