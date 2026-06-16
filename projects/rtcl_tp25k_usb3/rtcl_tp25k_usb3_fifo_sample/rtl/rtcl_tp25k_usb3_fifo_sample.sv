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

            output  var logic           mipi_pwr_en_n   ,
            inout   tri logic   [1:0]   mipi_gpio       ,
            inout   tri logic           mipi_scl        ,
            inout   tri logic           mipi_sda        ,

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
    assign led[2] = ft601_wakeup_n  ;
    assign led[3] = reset           ;



    // -------------------------------
    //  FT601
    // -------------------------------

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


    logic   [3:0]   ft601_tx_fifo_strb       ;
    logic   [31:0]  ft601_tx_fifo_data       ;
    logic           ft601_tx_fifo_valid      ;
    logic           ft601_tx_fifo_ready      ;

    logic           ft601_rx_fifo_almost_full;
    logic   [3:0]   ft601_rx_fifo_strb       ;
    logic   [31:0]  ft601_rx_fifo_data       ;
    logic           ft601_rx_fifo_valid      ;
    
    ft601_mode245_transceiver
        u_ft601_mode245_transceiver
            (
                .reset              (ft601_reset                ),
                .clk                (ft601_clk                  ),

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

                .s_fifo_strb        (ft601_tx_fifo_strb         ),
                .s_fifo_data        (ft601_tx_fifo_data         ),
                .s_fifo_valid       (ft601_tx_fifo_valid        ),
                .s_fifo_ready       (ft601_tx_fifo_ready        ),

                .m_fifo_almost_full (ft601_rx_fifo_almost_full  ),
                .m_fifo_strb        (ft601_rx_fifo_strb         ),
                .m_fifo_data        (ft601_rx_fifo_data         ),
                .m_fifo_valid       (ft601_rx_fifo_valid        )
            );


    // -------------------------------
    //  Command FIFO
    // -------------------------------

    localparam RX_FIFO_PTR_BITS = 8;
    localparam TX_FIFO_PTR_BITS = 8;

    // RX FIFO
    logic  [RX_FIFO_PTR_BITS:0] fifo_rx_free_size   ;

    logic   [3:0]               cmd_rx_fifo_strb    ;
    logic   [31:0]              cmd_rx_fifo_data    ;
    logic                       cmd_rx_fifo_valid   ;
    logic                       cmd_rx_fifo_ready   ;

    jelly3_stream_fifo
            #(
                .ASYNC          (1                  ),
                .PTR_BITS       (RX_FIFO_PTR_BITS   ),
                .DATA_BITS      (4+32               ),
                .S_SYNC_FF      (3                  ),
                .M_SYNC_FF      (3                  ),
                .RAM_TYPE       ("block"            ),
                .DOUT_REG       (1                  )
            )
        u_stream_fifo_rx
            (
                .s_reset        (ft601_reset        ),
                .s_clk          (ft601_clk          ),
                .s_cke          (1'b1               ),
                .s_data         ({
                                    ft601_rx_fifo_strb,
                                    ft601_rx_fifo_data
                                }),
                .s_valid        (ft601_rx_fifo_valid),
                .s_ready        (),
                .s_free_size    (fifo_rx_free_size  ),

                .m_reset        (reset        ),
                .m_clk          (clk          ),
                .m_cke          (1'b1               ),
                .m_data         ({
                                    cmd_rx_fifo_strb,
                                    cmd_rx_fifo_data
                                }),
                .m_valid        (cmd_rx_fifo_valid  ),
                .m_ready        (cmd_rx_fifo_ready  ),
                .m_data_size    (                   )
            );

    always_ff @(posedge ft601_clk) begin
        if ( ft601_reset ) begin
            ft601_rx_fifo_almost_full <= 1'b0;
        end
        else begin
            ft601_rx_fifo_almost_full <= fifo_rx_free_size < 64;
        end
    end

    // TX FIFO
    logic   [3:0]   cmd_tx_fifo_strb    ;
    logic   [31:0]  cmd_tx_fifo_data    ;
    logic           cmd_tx_fifo_valid   ;
    logic           cmd_tx_fifo_ready   ;

    jelly3_stream_fifo
            #(
                .ASYNC          (1                  ),
                .PTR_BITS       (TX_FIFO_PTR_BITS   ),
                .DATA_BITS      (4+32               ),
                .S_SYNC_FF      (3                  ),
                .M_SYNC_FF      (3                  ),
                .RAM_TYPE       ("block"            ),
                .DOUT_REG       (1                  )
            )
        u_stream_fifo_tx
            (
                .s_reset        (reset              ),
                .s_clk          (clk                ),
                .s_cke          (1'b1               ),
                .s_data         ({
                                    cmd_tx_fifo_strb,
                                    cmd_tx_fifo_data
                                }),
                .s_valid        (cmd_tx_fifo_valid  ),
                .s_ready        (cmd_tx_fifo_ready  ),
                .s_free_size    (                   ),

                .m_reset        (ft601_reset        ),
                .m_clk          (ft601_clk          ),
                .m_cke          (1'b1               ),
                .m_data         ({
                                    ft601_tx_fifo_strb,
                                    ft601_tx_fifo_data
                                }),
                .m_valid        (ft601_tx_fifo_valid),
                .m_ready        (ft601_tx_fifo_ready),
                .m_data_size    (                   )
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

                .s_rx_data      (cmd_rx_fifo_data   ),
                .s_rx_valid     (cmd_rx_fifo_valid  ),
                .s_rx_ready     (cmd_rx_fifo_ready  ),

                .m_tx_data      (cmd_tx_fifo_data   ),
                .m_tx_valid     (cmd_tx_fifo_valid  ),
                .m_tx_ready     (cmd_tx_fifo_ready  ),
                
                .m_axi4l        (axi4l_host         )
            );
    assign cmd_tx_fifo_strb = '1;


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

    /*
    localparam  SYSREG_ID             = 4'h0;
    localparam  SYSREG_SW_RESET       = 4'h1;
    localparam  SYSREG_CAM_ENABLE     = 4'h2;
    localparam  SYSREG_PWR_ENABLE     = 4'h5;
    localparam  SYSREG_SCRATCH        = 4'hf;
 
    logic               reg_sw_reset        ;
    logic               reg_cam_enable      ;
    logic               reg_pwr_enable      ;
    logic   [31:0]      reg_scratch         ;
    always_ff @(posedge axi4l_dec[DEC_CTL].aclk) begin
        if ( ~axi4l_dec[DEC_CTL].aresetn ) begin
            axi4l_dec[DEC_CTL].bvalid <= 1'b0   ;
            axi4l_dec[DEC_CTL].rdata  <= '0     ;
            axi4l_dec[DEC_CTL].rvalid <= 1'b0   ;

            reg_sw_reset      <= 1'b0       ;
            reg_cam_enable    <= 1'b0       ;
            reg_pwr_enable    <= 1'h0       ;
            reg_scratch       <= 32'h0      ;
        end
        else begin
            // write
            if ( axi4l_dec[DEC_CTL].bready ) begin
                axi4l_dec[DEC_CTL].bvalid <= 1'b0;
            end
            if ( axi4l_dec[DEC_CTL].awvalid && axi4l_dec[DEC_CTL].awready 
                    && axi4l_dec[DEC_CTL].wvalid && axi4l_dec[DEC_CTL].wready
                    && axi4l_dec[DEC_CTL].wstrb[0] ) begin
                case ( axi4l_dec[DEC_CTL].awaddr[5:2] )
                SYSREG_SW_RESET  :   reg_sw_reset   <=  1'(axi4l_dec[DEC_CTL].wdata);
                SYSREG_CAM_ENABLE:   reg_cam_enable <=  1'(axi4l_dec[DEC_CTL].wdata);
                SYSREG_PWR_ENABLE:   reg_pwr_enable <=  1'(axi4l_dec[DEC_CTL].wdata);
                SYSREG_SCRATCH   :   reg_scratch    <= 32'(axi4l_dec[DEC_CTL].wdata);
                default:;
                endcase
                axi4l_dec[DEC_CTL].bvalid <= 1'b1;
            end

            // read
            if ( axi4l_dec[DEC_CTL].rready ) begin
                axi4l_dec[DEC_CTL].rdata  <= '0;
                axi4l_dec[DEC_CTL].rvalid <= 1'b0;
            end
            if ( axi4l_dec[DEC_CTL].arvalid && axi4l_dec[DEC_CTL].arready ) begin
                case ( axi4l_dec[DEC_CTL].araddr[5:2] )
                SYSREG_ID            :  axi4l_dec[DEC_CTL].rdata  <= axi4l_dec[DEC_CTL].DATA_BITS'(32'h01234567)      ;
                SYSREG_SW_RESET      :  axi4l_dec[DEC_CTL].rdata  <= axi4l_dec[DEC_CTL].DATA_BITS'(reg_sw_reset)      ;
                SYSREG_CAM_ENABLE    :  axi4l_dec[DEC_CTL].rdata  <= axi4l_dec[DEC_CTL].DATA_BITS'(reg_cam_enable)    ;
                SYSREG_PWR_ENABLE    :  axi4l_dec[DEC_CTL].rdata  <= axi4l_dec[DEC_CTL].DATA_BITS'(reg_pwr_enable)    ;
                SYSREG_SCRATCH       :  axi4l_dec[DEC_CTL].rdata  <= axi4l_dec[DEC_CTL].DATA_BITS'(reg_scratch)       ;
                default:    axi4l_dec[DEC_CTL].rdata  <= '0    ;
                endcase
                axi4l_dec[DEC_CTL].rvalid <= 1'b1;
            end
        end
    end
    assign axi4l_dec[DEC_CTL].awready = axi4l_dec[DEC_CTL].wvalid  && !axi4l_dec[DEC_CTL].bvalid;
    assign axi4l_dec[DEC_CTL].wready  = axi4l_dec[DEC_CTL].awvalid && !axi4l_dec[DEC_CTL].bvalid;
    assign axi4l_dec[DEC_CTL].bresp   = '0;
    assign axi4l_dec[DEC_CTL].arready = !axi4l_dec[DEC_CTL].rvalid;
    assign axi4l_dec[DEC_CTL].rresp   = '0;

    assign mipi_pwr_en_n = ~reg_pwr_enable  ;
    assign mipi_gpio[0]  = reg_cam_enable   ;
    assign mipi_gpio[1]  = 1'bz             ;
    */

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

                .monitor0           (                   ),
                .monitor1           (                   ),
                .monitor2           (                   ),
                .monitor3           (                   ),
                .monitor4           (                   ),
                .monitor5           (                   ),
                .monitor6           (                   ),
                .monitor7           (                   )
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
    //  PMOD
    // ----------------------------------------

    assign pmod[7:0] = 0   ;

endmodule

`default_nettype wire

