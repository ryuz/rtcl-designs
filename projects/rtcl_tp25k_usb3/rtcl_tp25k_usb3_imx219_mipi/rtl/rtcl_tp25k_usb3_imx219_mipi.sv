// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module rtcl_tp25k_usb3_imx219_mipi
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

            inout   tri logic           mipi_ck_p       ,
            inout   tri logic           mipi_ck_n       ,
            inout   tri logic   [3:0]   mipi_d_p        ,
            inout   tri logic   [3:0]   mipi_d_n        ,
            inout   tri logic           mipi_scl        ,
            inout   tri logic           mipi_sda        ,
            inout   tri logic   [1:0]   mipi_gpio       ,
            output  var logic           mipi_pwr_en_n   ,

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



    // ----------------------------------------
    //  D-PHY
    // ----------------------------------------

    logic           dphy_reset              ;

    logic           dphy_clk                ;
    logic   [7:0]   dphy_d0ln_hsrxd         ;
    logic   [7:0]   dphy_d1ln_hsrxd         ;
    logic   [7:0]   dphy_d2ln_hsrxd         ;
    logic   [7:0]   dphy_d3ln_hsrxd         ;
    logic   [3:0]   dphy_hsrxd_vld          ;

    logic   [1:0]   dphy_di_lprx0           ;
    logic   [1:0]   dphy_di_lprx1           ;
    logic   [1:0]   dphy_di_lprx2           ;
    logic   [1:0]   dphy_di_lprx3           ;
    logic   [1:0]   dphy_di_lprxck          ;

    logic           dphy_d0ln_deskew_done   ;
    logic           dphy_d1ln_deskew_done   ;
    logic           dphy_d2ln_deskew_done   ;
    logic           dphy_d3ln_deskew_done   ;
    logic           dphy_d0ln_deskew_error  ;
    logic           dphy_d1ln_deskew_error  ;
    logic           dphy_d2ln_deskew_error  ;
    logic           dphy_d3ln_deskew_error  ;
    logic           dphy_lptxen_ln0         ;
    logic           dphy_lptxen_ln1         ;
    logic           dphy_lptxen_ln2         ;
    logic           dphy_lptxen_ln3         ;
    logic           dphy_do_lptx0_n         ;
    logic           dphy_do_lptx1_n         ;
    logic           dphy_do_lptx2_n         ;
    logic           dphy_do_lptx3_n         ;
    logic           dphy_do_lptx0_p         ;
    logic           dphy_do_lptx1_p         ;
    logic           dphy_do_lptx2_p         ;
    logic           dphy_do_lptx3_p         ;

    logic           dphy_lprx_en_ck         ;
    logic           dphy_hsrx_en_d0         ;
    logic           dphy_hsrx_en_d1         ;
    logic           dphy_hsrx_en_d2         ;
    logic           dphy_hsrx_en_d3         ;
    logic   [3:0]   dphy_hsrx_odten         ;
    logic           dphy_lprx_en_d0         ;
    logic           dphy_lprx_en_d1         ;
    logic           dphy_lprx_en_d2         ;
    logic           dphy_lprx_en_d3         ;
    logic           dphy_rx_drst_n          ;
    logic           dphy_d0ln_deskew_req    ;
    logic           dphy_d1ln_deskew_req    ;
    logic           dphy_d2ln_deskew_req    ;
    logic           dphy_d3ln_deskew_req    ;

    Gowin_MIPI_DPHY
        u_mipi_dphy
            (
                .rx_clk_o           (dphy_clk               ), //output rx_clk_o
                .d0ln_hsrxd         (dphy_d0ln_hsrxd        ), //output [7:0] d0ln_hsrxd
                .d1ln_hsrxd         (dphy_d1ln_hsrxd        ), //output [7:0] d1ln_hsrxd
                .d2ln_hsrxd         (dphy_d2ln_hsrxd        ), //output [7:0] d2ln_hsrxd
                .d3ln_hsrxd         (dphy_d3ln_hsrxd        ), //output [7:0] d3ln_hsrxd
                .d0ln_hsrxd_vld     (dphy_hsrxd_vld[0]      ), //output d0ln_hsrxd_vld
                .d1ln_hsrxd_vld     (dphy_hsrxd_vld[1]      ), //output d1ln_hsrxd_vld
                .d2ln_hsrxd_vld     (dphy_hsrxd_vld[2]      ), //output d2ln_hsrxd_vld
                .d3ln_hsrxd_vld     (dphy_hsrxd_vld[3]      ), //output d3ln_hsrxd_vld
                .di_lprx0_n         (dphy_di_lprx0[0]       ), //output di_lprx0_n
                .di_lprx0_p         (dphy_di_lprx0[1]       ), //output di_lprx0_p
                .di_lprx1_n         (dphy_di_lprx1[0]       ), //output di_lprx1_n
                .di_lprx1_p         (dphy_di_lprx1[1]       ), //output di_lprx1_p
                .di_lprx2_n         (dphy_di_lprx2[0]       ), //output di_lprx2_n
                .di_lprx2_p         (dphy_di_lprx2[1]       ), //output di_lprx2_p
                .di_lprx3_n         (dphy_di_lprx3[0]       ), //output di_lprx3_n
                .di_lprx3_p         (dphy_di_lprx3[1]       ), //output di_lprx3_p
                .di_lprxck_n        (dphy_di_lprxck[0]      ), //output di_lprxck_n
                .di_lprxck_p        (dphy_di_lprxck[1]      ), //output di_lprxck_p
                .d0ln_deskew_done   (dphy_d0ln_deskew_done  ), //output d0ln_deskew_done
                .d1ln_deskew_done   (dphy_d1ln_deskew_done  ), //output d1ln_deskew_done
                .d2ln_deskew_done   (dphy_d2ln_deskew_done  ), //output d2ln_deskew_done
                .d3ln_deskew_done   (dphy_d3ln_deskew_done  ), //output d3ln_deskew_done
                .d0ln_deskew_error  (dphy_d0ln_deskew_error ), //output d0ln_deskew_error
                .d1ln_deskew_error  (dphy_d1ln_deskew_error ), //output d1ln_deskew_error
                .d2ln_deskew_error  (dphy_d2ln_deskew_error ), //output d2ln_deskew_error
                .d3ln_deskew_error  (dphy_d3ln_deskew_error ), //output d3ln_deskew_error

                .ck_n               (mipi_ck_n              ), //inout ck_n
                .ck_p               (mipi_ck_p              ), //inout ck_p
                .d0_n               (mipi_d_n[0]            ), //inout d0_n
                .d0_p               (mipi_d_p[0]            ), //inout d0_p
                .d1_n               (mipi_d_n[1]            ), //inout d1_n
                .d1_p               (mipi_d_p[1]            ), //inout d1_p
                .d2_n               (mipi_d_n[2]            ), //inout d2_n
                .d2_p               (mipi_d_p[2]            ), //inout d2_p
                .d3_n               (mipi_d_n[3]            ), //inout d3_n
                .d3_p               (mipi_d_p[3]            ), //inout d3_p
                .lptxen_ln0         (1'b0                   ), //input lptxen_ln0
                .lptxen_ln1         (1'b0                   ), //input lptxen_ln1
                .lptxen_ln2         (1'b0                   ), //input lptxen_ln2
                .lptxen_ln3         (1'b0                   ), //input lptxen_ln3
                .lptxen_lnck        (1'b0                   ), //input lptxen_lnck
                .do_lptx0_n         (1'b0                   ), //input do_lptx0_n
                .do_lptx1_n         (1'b0                   ), //input do_lptx1_n
                .do_lptx2_n         (1'b0                   ), //input do_lptx2_n
                .do_lptx3_n         (1'b0                   ), //input do_lptx3_n
                .do_lptxck_n        (1'b0                   ), //input do_lptxck_n
                .do_lptx0_p         (1'b0                   ), //input do_lptx0_p
                .do_lptx1_p         (1'b0                   ), //input do_lptx1_p
                .do_lptx2_p         (1'b0                   ), //input do_lptx2_p
                .do_lptx3_p         (1'b0                   ), //input do_lptx3_p
                .do_lptxck_p        (1'b0                   ), //input do_lptxck_p

                .hsrx_en_ck         (1'b1                   ), //input hsrx_en_ck
                .hsrx_en_d0         (dphy_hsrx_en_d0        ), //input hsrx_en_d0
                .hsrx_en_d1         (dphy_hsrx_en_d1        ), //input hsrx_en_d1
                .hsrx_en_d2         (dphy_hsrx_en_d2        ), //input hsrx_en_d2
                .hsrx_en_d3         (dphy_hsrx_en_d3        ), //input hsrx_en_d3
                .hsrx_odten_ck      (1'b1                   ), //input hsrx_odten_ck
                .hsrx_odten_d0      (dphy_hsrx_odten[0]     ), //input hsrx_odten_d0
                .hsrx_odten_d1      (dphy_hsrx_odten[1]     ), //input hsrx_odten_d1
                .hsrx_odten_d2      (dphy_hsrx_odten[2]     ), //input hsrx_odten_d2
                .hsrx_odten_d3      (dphy_hsrx_odten[3]     ), //input hsrx_odten_d3
                .lprx_en_ck         (1'b1                   ), //input lprx_en_ck
                .lprx_en_d0         (dphy_lprx_en_d0        ), //input lprx_en_d0
                .lprx_en_d1         (dphy_lprx_en_d1        ), //input lprx_en_d1
                .lprx_en_d2         (dphy_lprx_en_d2        ), //input lprx_en_d2
                .lprx_en_d3         (dphy_lprx_en_d3        ), //input lprx_en_d3
                .rx_drst_n          (dphy_rx_drst_n         ), //input rx_drst_n
                .d0ln_deskew_req    (dphy_d0ln_deskew_req   ), //input d0ln_deskew_req
                .d1ln_deskew_req    (dphy_d1ln_deskew_req   ), //input d1ln_deskew_req
                .d2ln_deskew_req    (dphy_d2ln_deskew_req   ), //input d2ln_deskew_req
                .d3ln_deskew_req    (dphy_d3ln_deskew_req   )  //input d3ln_deskew_req
            );

    jelly3_reset_async
            #(
                .IN_LOW_ACTIVE      (0                  ),
                .OUT_LOW_ACTIVE     (0                  )
            )
        u_reset_async_dphy
            (
                .clk                (dphy_clk           ),
                .cke                (1'b1               ),
                .in_reset           (self_reset || ~lock),
                .out_reset          (dphy_reset         )
            );


    assign dphy_lptxen_ln0    = 0;
    assign dphy_lptxen_ln1    = 0;
    assign dphy_lptxen_ln2    = 0;
    assign dphy_lptxen_ln3    = 0;
    assign dphy_do_lptx0_n    = 0;
    assign dphy_do_lptx1_n    = 0;
    assign dphy_do_lptx2_n    = 0;
    assign dphy_do_lptx3_n    = 0;
    assign dphy_do_lptx0_p    = 0;
    assign dphy_do_lptx1_p    = 0;
    assign dphy_do_lptx2_p    = 0;
    assign dphy_do_lptx3_p    = 0;

    assign dphy_hsrx_en_d0    = 1;
    assign dphy_hsrx_en_d1    = 1;
    assign dphy_hsrx_en_d2    = 1;
    assign dphy_hsrx_en_d3    = 1;
    assign dphy_lprx_en_d0    = 1;
    assign dphy_lprx_en_d1    = 1;
    assign dphy_lprx_en_d2    = 1;
    assign dphy_lprx_en_d3    = 1;

    assign dphy_d0ln_deskew_req = 0;
    assign dphy_d1ln_deskew_req = 0;
    assign dphy_d2ln_deskew_req = 0;
    assign dphy_d3ln_deskew_req = 0;
    
    // control terminator
    logic               dphy_byte_ready  ;
    logic   [7:0]       dphy_byte_d0     ;
    logic   [7:0]       dphy_byte_d1     ;
    logic   [1:0]       dphy_lp0_reg_0   = 2'b11   ;
    logic   [1:0]       dphy_lp0_reg_1   = 2'b11   ;
    logic               dphy_odt_en_msk  = '0      ;
    logic               dphy_hsrx_en_msk = 1'b0    ;
    logic   [5:0]       dphy_hsrx_cnt    = 'b0     ;
    logic               dphy_reg3to1     = 1'b0    ;

    wire logic          dphy_from0to3    = (dphy_lp0_reg_1==0)&(dphy_lp0_reg_0==3);
    wire logic          dphy_from1to0    = (dphy_lp0_reg_1==1)&(dphy_lp0_reg_0==0);
    wire logic          dphy_from1to2    = (dphy_lp0_reg_1==1)&(dphy_lp0_reg_0==2);
    wire logic          dphy_from1to3    = (dphy_lp0_reg_1==1)&(dphy_lp0_reg_0==3);
    wire logic          dphy_from3to1    = (dphy_lp0_reg_1==3)&(dphy_lp0_reg_0==1);
    wire logic          dphy_fromXto3    = (dphy_lp0_reg_1!=3)&(dphy_lp0_reg_0==3);
    wire logic          dphy_from1toX    = (dphy_lp0_reg_1==1)&(dphy_lp0_reg_0!=1);
    wire logic  [ 1:0]  dphy_odt_en      = {(dphy_di_lprx1==0), (dphy_di_lprx0==0)} & {2{dphy_odt_en_msk}};

    always_ff @(posedge dphy_clk or posedge reset) begin
        if      (reset           ) dphy_odt_en_msk <= 'b0;
        else if (~dphy_odt_en_msk) dphy_odt_en_msk <= dphy_from3to1;
        else if (1               ) dphy_odt_en_msk <= !(dphy_from1to2|dphy_from1to3|dphy_fromXto3);

        if      (reset           ) dphy_reg3to1 <= 'b0;
        else if (~dphy_reg3to1   ) dphy_reg3to1 <= dphy_from3to1;
        else if (1               ) dphy_reg3to1 <= ~dphy_from1toX;

        if      (reset           ) dphy_hsrx_cnt <= 'b0;
        else if (|dphy_odt_en    ) dphy_hsrx_cnt <= 6'd10;
        else if (dphy_hsrx_cnt>0 ) dphy_hsrx_cnt <= dphy_hsrx_cnt - 6'd1;
    end

    always_ff @(posedge dphy_clk) begin
        dphy_lp0_reg_0   <= dphy_di_lprx0;
        dphy_lp0_reg_1   <= dphy_lp0_reg_0;
        dphy_rx_drst_n   <= ~(dphy_reg3to1&dphy_from1to0);
        dphy_hsrx_en_msk <= (dphy_hsrx_cnt>0);
        dphy_byte_ready  <= dphy_hsrx_en_msk & dphy_hsrxd_vld[0];
        dphy_byte_d0     <= dphy_d0ln_hsrxd[7:0];
        dphy_byte_d1     <= dphy_d1ln_hsrxd[7:0];
    end
    assign dphy_hsrx_odten = {(dphy_di_lprx3==0), (dphy_di_lprx2==0), (dphy_di_lprx1==0), (dphy_di_lprx0==0)} & {4{dphy_odt_en_msk}};




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
    localparam DEC_I2C  = 1;
    localparam DEC_FRM  = 2;
    localparam DEC_NUM  = 3;

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
    assign {axi4l_dec[DEC_I2C].addr_base, axi4l_dec[DEC_I2C].addr_high} = {32'h0001_0000, 32'h0001_ffff};
    assign {axi4l_dec[DEC_FRM].addr_base, axi4l_dec[DEC_FRM].addr_high} = {32'h0004_0000, 32'h0004_ffff};

    jelly3_axi4l_addr_decoder
            #(
                .NUM            (DEC_NUM    ),
                .DEC_ADDR_BITS  (28         )
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
                .INIT_CONTROL0      ('0                 ),  // POWER_RN
                .INIT_CONTROL1      ('0                 ),  // CAM_EN
                .INIT_CONTROL2      ('0                 ),
                .INIT_CONTROL3      (512                ),  // max_len
                .INIT_CONTROL4      (1024*4             ),  // limit_len
                .INIT_CONTROL5      (10000              ),  // timeout
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

    assign mipi_pwr_en_n = ~control0[0]  ;
    assign mipi_gpio[0]  = control1[0]   ;
    assign mipi_gpio[1]  = 1'bz          ;


    // ----------------------------------------
    //  I2C
    // ----------------------------------------

    logic       i2c_scl_t   ;
    logic       i2c_scl_i   ;
    logic       i2c_sda_t   ;
    logic       i2c_sda_i   ;
    jelly3_i2c
            #(
                .DIVIDER_BITS   (16                 )
            )
        u_i2c
            (
                .i2c_scl_t      (i2c_scl_t          ),
                .i2c_scl_i      (i2c_scl_i          ),
                .i2c_sda_t      (i2c_sda_t          ),
                .i2c_sda_i      (i2c_sda_i          ),

                .s_axi4l        (axi4l_dec[DEC_I2C] ),
                .irq            (                   )
            );
    
    IOBUF
        u_iobuf_scl
            (
                .O          (i2c_scl_i  ),
                .IO         (mipi_scl   ),
                .I          (1'b0       ),
                .OEN        (i2c_scl_t  )
            );

    IOBUF
        u_iobuf_sda
            (
                .O          (i2c_sda_i  ),
                .IO         (mipi_sda   ),
                .I          (1'b0       ),
                .OEN        (i2c_sda_t  )
            );


    // --------------------------------
    //  Frame Control
    // --------------------------------
    
    jelly3_axi4s_if
            #(
                .USE_STRB   (1          ),
                .USE_LAST   (1          ),
                .USER_BITS  (1          ),
                .DATA_BITS  (32         ),
                .STRB_BITS  (4          )
            )
        axi4s_dphy
            (
                .aresetn    (~dphy_reset),
                .aclk       (dphy_clk   ),
                .aclken     (1'b1       )
            );

    gowin_dphy_lane2_to_fifo32
        u_gowin_dphy_lane2_to_fifo32
            (
                .dphy_data  ({dphy_byte_d1, dphy_byte_d0}   ),
                .dphy_valid (dphy_byte_ready                ),
                .data_type  (8'h2b                          ),

                .m_axi4s    (axi4s_dphy.m                   )
            );

    jelly3_axi4s_if
            #(
                .USE_STRB   (1          ),
                .USE_LAST   (1          ),
                .USER_BITS  (1          ),
                .DATA_BITS  (32         ),
                .STRB_BITS  (4          )
            )
        axi4s_frame
            (
                .aresetn    (~dphy_reset),
                .aclk       (dphy_clk   ),
                .aclken     (1'b1       )
            );


    frame_controller
        u_frame_controller
            (
                .s_axi4l    (axi4l_dec[DEC_FRM].s   ),

                .s_axi4s    (axi4s_dphy.s           ),
                .m_axi4s    (axi4s_frame.m          )
            );

    jelly3_axi4s_if
            #(
                .USE_STRB   (1          ),
                .USE_LAST   (1          ),
                .USER_BITS  (1          ),
                .DATA_BITS  (32         ),
                .STRB_BITS  (4          )
            )
        axi4s_tx
            (
                .aresetn    (~reset     ),
                .aclk       (clk        ),
                .aclken     (1'b1       )
            );

    fifo32_cmd_axi4s_tx
            #(
                .ASYNC          (1                  ),
                .DATA_BUF_SIZE  (1024*16            ),
                .CMD_BUF_SIZE   (1024               ),
                .TIMER_BITS     (16                 )
            )
        u_fifo32_cmd_axi4s_tx
            (
                .max_len        (control3[13:0]     ),
                .limit_len      (control4[13:0]     ),
                .timeout        (control5[15:0]     ),

                .s_axi4s        (axi4s_frame.s      ),
                .m_axi4s        (axi4s_ft601_tx[1].m)
//              .m_axi4s        (axi4s_tx.m)
            );

    /*
    // 全力送信実験
    logic  [31:0]   busy_count = 13;
    always_ff @(posedge axi4s_ft601_tx[1].aclk ) begin
        if ( !axi4s_ft601_tx[1].tvalid || axi4s_ft601_tx[1].tready ) begin
            busy_count <= busy_count + 1'b1;
        end
    end

    logic  [31:0]   axi4s_tx_data;
    logic  [31:0]   axi4s_tx_count;
    logic           axi4s_tx_valid;
    always_ff @(posedge axi4s_ft601_tx[1].aclk ) begin
        if ( ~axi4s_ft601_tx[1].aresetn ) begin
            axi4s_tx_count           <= 8'b0;
            axi4s_tx_data            <= 32'hx03020100;
            axi4s_ft601_tx[1].tstrb  <= '1;
            axi4s_tx_valid <= 1'b0;
        end
        else begin
            axi4s_tx_valid <= 1'b1;
            if ( axi4s_ft601_tx[1].tvalid && axi4s_ft601_tx[1].tready ) begin
                axi4s_tx_count <= axi4s_tx_count + 1'b1;
                axi4s_tx_data[0*8 +: 8] <= axi4s_tx_data[0*8 +: 8] + 4;
                axi4s_tx_data[1*8 +: 8] <= axi4s_tx_data[1*8 +: 8] + 4;
                axi4s_tx_data[2*8 +: 8] <= axi4s_tx_data[2*8 +: 8] + 4;
                axi4s_tx_data[3*8 +: 8] <= axi4s_tx_data[3*8 +: 8] + 4;
            end
        end
    end
    assign axi4s_ft601_tx[1].tdata = axi4s_tx_count[7:0] == 0 ? 32'h03fc_0010 : axi4s_tx_data;
//  assign axi4s_ft601_tx[1].tdata  = 32'h0100_0010;
    assign axi4s_ft601_tx[1].tvalid = axi4s_tx_valid && (busy_count[16:9] != 0); // || busy_count[3:0] == 0);
    */

    // rx
    assign axi4s_ft601_rx[1].tready = 1'b1;



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

    logic frame_overflow;
    always_ff @(posedge dphy_clk) begin
        if ( dphy_reset ) begin
            frame_overflow <= 1'b0;
        end
        else begin
            if ( axi4s_frame.tvalid && !axi4s_frame.tready ) begin
                frame_overflow <= 1'b1;
            end
        end
    end

    logic dphy_overflow;
    always_ff @(posedge dphy_clk) begin
        if ( dphy_reset ) begin
            dphy_overflow <= 1'b0;
        end
        else begin
            if ( axi4s_dphy.tvalid && !axi4s_dphy.tready ) begin
                dphy_overflow <= 1'b1;
            end
        end
    end


    assign led[0] = clk_counter[24] ;
    assign led[1] = usb_counter[26] ;
    assign led[2] = frame_overflow  ;
    assign led[3] = dphy_overflow   ;


    // --------------------------------
    //  PMOD
    // --------------------------------

    
    assign pmod[0] = ft601_rxf_n;
    assign pmod[1] = ft601_wr_n;
    assign pmod[2] = axi4s_frame.tready;
    assign pmod[3] = axi4s_frame.tvalid;
//    assign pmod[4] = ft601_data_i[8];
//    assign pmod[5] = ft601_data_i[9];
//    assign pmod[6] = ft601_data_i[12];
//    assign pmod[7] = ft601_data_i[13];

    assign pmod[4] = axi4s_ft601_tx[1].tready;
    assign pmod[5] = axi4s_ft601_tx[1].tvalid;
    assign pmod[6] = ft601_txe_n;
    assign pmod[7] = ft601_data_i[9];

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


    // --------------------------------
    //  Debug
    // --------------------------------

    jelly3_axi4s_debug_monitor
        u_axi4s_debug_monitor_dphy
            (
                .mon_axi4s  (axi4s_dphy.mon)
            );

    jelly3_axi4s_debug_monitor
        u_axi4s_debug_monitor_frame
            (
                .mon_axi4s  (axi4s_frame.mon)
            );

endmodule


`default_nettype wire
