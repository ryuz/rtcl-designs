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


    // ----------------------------------------
    //  D-PHY
    // ----------------------------------------

    logic           dphy_clk                ;
    logic   [7:0]   dphy_d0ln_hsrxd         ;
    logic   [7:0]   dphy_d1ln_hsrxd         ;
    logic   [7:0]   dphy_d2ln_hsrxd         ;
    logic   [7:0]   dphy_d3ln_hsrxd         ;
    // logic           dphy_d0ln_hsrxd_vld     ;
    // logic           dphy_d1ln_hsrxd_vld     ;
    // logic           dphy_d2ln_hsrxd_vld     ;
    // logic           dphy_d3ln_hsrxd_vld     ;
    logic   [3:0]   dphy_hsrxd_vld          ;

    logic   [1:0]   dphy_di_lprx0           ;
    logic   [1:0]   dphy_di_lprx1           ;
    logic   [1:0]   dphy_di_lprx2           ;
    logic   [1:0]   dphy_di_lprx3           ;
    logic   [1:0]   dphy_di_lprxck          ;


    // logic           dphy_di_lprx0_n         ;
    // logic           dphy_di_lprx0_p         ;
    // logic           dphy_di_lprx1_n         ;
    // logic           dphy_di_lprx1_p         ;
    // logic           dphy_di_lprx2_n         ;
    // logic           dphy_di_lprx2_p         ;
    // logic           dphy_di_lprx3_n         ;
    // logic           dphy_di_lprx3_p         ;
    // logic           dphy_di_lprxck_n        ;
    // logic           dphy_di_lprxck_p        ;
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
    // logic           dphy_hsrx_odten_d0      ;
    // logic           dphy_hsrx_odten_d1      ;
    // logic           dphy_hsrx_odten_d2      ;
    // logic           dphy_hsrx_odten_d3      ;
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
                .hsrx_odten_d0      (dphy_hsrx_odten[0]      ), //input hsrx_odten_d0
                .hsrx_odten_d1      (dphy_hsrx_odten[1]      ), //input hsrx_odten_d1
                .hsrx_odten_d2      (dphy_hsrx_odten[2]      ), //input hsrx_odten_d2
                .hsrx_odten_d3      (dphy_hsrx_odten[3]      ), //input hsrx_odten_d3
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
    // assign dphy_hsrx_odten_d0 = 0;
    // assign dphy_hsrx_odten_d1 = 0;
    // assign dphy_hsrx_odten_d2 = 0;
    // assign dphy_hsrx_odten_d3 = 0;
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




    // ----------------------------------------
    //  FT601
    // ----------------------------------------

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


    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (0      ),
                .DATA_BITS  (32     )
            )
        axi4s_ft601_rx
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
        axi4s_ft601_tx
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );

    ft601_mode245
            #(
                .ASYNC              (1                  ),
                .RX_FIFO_PTR_BITS   (8                  ),
                .TX_FIFO_PTR_BITS   (8                  )
            )
        u_ft601_mode245
            (
                .ft601_reset        (ft601_reset        ),
                .ft601_clk          (ft601_clk          ),
                .ft601_rxf_n        (ft601_rxf_n        ),
                .ft601_txe_n        (ft601_txe_n        ),
                .ft601_wr_n         (ft601_wr_n         ),
                .ft601_rd_n         (ft601_rd_n         ),
                .ft601_oe_n         (ft601_oe_n         ),
                .ft601_be_i         (ft601_be_i         ),
                .ft601_be_o         (ft601_be_o         ),
                .ft601_be_t         (ft601_be_t         ),
                .ft601_data_i       (ft601_data_i       ),
                .ft601_data_o       (ft601_data_o       ),
                .ft601_data_t       (ft601_data_t       ),

                .s_axi4s_tx         (axi4s_ft601_tx.s   ),
                .m_axi4s_rx         (axi4s_ft601_rx.m   )
        );

    // --------------------------------
    //  Commnand arbiter
    // --------------------------------

    localparam  int     ARB_NUM = 2;

    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (0      ),
                .DATA_BITS  (32     ),
                .STRB_BITS  (4      )
            )
        axi4s_arb_tx [ARB_NUM]
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );

    fifo32_cmd_arbiter
            #(
                .N          (2              )
            )
        u_fifo32_cmd_arbiter
            (
                .s_axi4s    (axi4s_arb_tx   ),
                .m_axi4s    (axi4s_ft601_tx ) 
            );



    // --------------------------------
    //  Commnand processing
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

                .s_axi4s_rx     (axi4s_ft601_rx.s   ),
                .m_axi4s_tx     (axi4s_arb_tx[0].m  ),
                
                .m_axi4l        (axi4l_host         )
            );


    // --------------------------------
    //  Stream
    // --------------------------------

    jelly3_axi4s_if
            #(
                .USE_STRB   (1      ),
                .USE_LAST   (1      ),
                .DATA_BITS  (32     ),
                .STRB_BITS  (4      )
            )
        axi4s_dphy
            (
                .aresetn    (~reset ),
                .aclk       (clk    ),
                .aclken     (1'b1   )
            );
    
    logic           dphy_phase  ;
    logic           dphy_last   ;
    logic   [31:0]  dphy_data   ;
    logic           dphy_valid  ;

    always_ff @(posedge dphy_clk or posedge reset ) begin
        if ( reset ) begin
            dphy_phase        <= 0;
            dphy_last         <= 0;
            dphy_data         <= '0;
            dphy_valid        <= 1'b0;
        end
        else begin
            if ( dphy_byte_ready ) begin
                dphy_phase <= dphy_phase + 1;
                dphy_last  <= 1'b0;
                if ( dphy_phase == 0 ) begin
                    dphy_data[15:0]  <= {dphy_byte_d1, dphy_byte_d0};
                    dphy_data[31:16] <= '0;
                end
                else begin
                    dphy_data[31:16] <= {dphy_byte_d1, dphy_byte_d0};
                end
                dphy_valid <= 1'b1;
            end
            else begin
                if ( dphy_valid & dphy_last ) begin
                    dphy_phase <= 0;
                    dphy_data  <= '0;
                    dphy_valid <= 1'b0;
                end
                else begin
                    dphy_last  <= 1'b1;
                end
            end
        end
    end

    assign axi4s_dphy.tlast  = dphy_last;
    assign axi4s_dphy.tdata  = dphy_data;
    assign axi4s_dphy.tstrb  = '1;
    assign axi4s_dphy.tvalid = dphy_valid && (dphy_phase || dphy_last);


//    assign axi4s_arb_tx[1].tdata  = '0;
//    assign axi4s_arb_tx[1].tstrb  = '1;
//    assign axi4s_arb_tx[1].tvalid = 1'b0;

    fifo32_cmd_axi4s_tx
            #(
                .ASYNC      (1              ),
                .CH_ID      (0              ),
                .MAX_LEN    (512            ),
                .BUF_SIZE   (1024           )
            )
        u_fifo32_cmd_axi4s_tx
            (
                .s_axi4s    (axi4s_dphy     ),
                .m_axi4s    (axi4s_arb_tx[1])
            );



    // ----------------------------------------
    //  Address decoder
    // ----------------------------------------

    localparam DEC_CTL = 0;
    localparam DEC_I2C = 1;
    localparam DEC_NUM = 2;

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
    jelly3_system_control
        #(
                .DATA_BITS          (32                 ),
                .CORE_ID            (32'h527a_0001      ),
                .CORE_VERSION       (32'h0003_0001      ),
                .INIT_CONTROL0      ('0                 ),
                .INIT_CONTROL1      ('0                 ),
                .INIT_CONTROL2      ('0                 ),
                .INIT_CONTROL3      ('0                 ),
                .INIT_CONTROL4      ('0                 ),
                .INIT_CONTROL5      ('0                 ),
                .INIT_CONTROL6      ('0                 ),
                .INIT_CONTROL7      ('0                 )
            )
        u_system_control
            (
                .s_axi4l            (axi4l_dec[DEC_CTL] ),

                .control0           (control0           ),
                .control1           (control1           ),
                .control2           (control2           ),
                .control3           (                   ),
                .control4           (                   ),
                .control5           (                   ),
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




    // ----------------------------------------
    //  LED
    // ----------------------------------------

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


    // ----------------------------------------
    //  PMOD
    // ----------------------------------------

//  assign pmod[7:0] = 0   ;

    logic  [7:0]   count;
    always_ff @(posedge dphy_clk) begin
        count <= count + 1'b1;
    end

    
    assign pmod[0] = dphy_di_lprx0[0]    ;
    assign pmod[1] = dphy_di_lprx0[1]    ;
    assign pmod[2] = dphy_di_lprx1[0]    ;
    assign pmod[3] = dphy_di_lprx1[1]    ;
    assign pmod[4] = dphy_di_lprxck[0]   ;
    assign pmod[5] = dphy_di_lprxck[1]   ;
    assign pmod[6] = dphy_hsrxd_vld[0]   ;
    assign pmod[7] = dphy_byte_ready     ;
    
    /*
    assign pmod[0] = ft601_rxf_n;
    assign pmod[1] = ft601_txe_n;
    assign pmod[2] = ft601_wr_n;
    assign pmod[3] = ft601_rd_n;
    assign pmod[4] = ft601_oe_n;
    assign pmod[5] = clk_counter[7];
    assign pmod[6] = ft601_reset_n;
    assign pmod[7] = ft601_wakeup_n;
    */

endmodule

`default_nettype wire

