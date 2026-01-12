// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module zybo_z7_rtcl_p3s7_mnist_seg
        #(
            parameter   int         WIDTH_BITS  = 11                        ,
            parameter   type        width_t     = logic [WIDTH_BITS-1:0]    ,
            parameter   int         HEIGHT_BITS = 10                        ,
            parameter   type        height_t    = logic [HEIGHT_BITS-1:0]   ,
            parameter   width_t     IMG_WIDTH   = 64                        ,
            parameter   height_t    IMG_HEIGHT  = 64                        ,
            parameter               DEBUG       = "false"                   
        )
        (
            input   var logic           in_clk125           ,
            
            input   var logic   [3:0]   push_sw             ,
            input   var logic   [3:0]   dip_sw              ,
            output  var logic   [3:0]   led                 ,
            output  var logic   [7:0]   pmod_a              ,
            inout   tri logic   [7:0]   pmod_b              ,
            inout   tri logic   [7:0]   pmod_c              ,
            inout   tri logic   [7:0]   pmod_d              ,
            inout   tri logic   [7:0]   pmod_e              ,
            
            input   var logic           cam_clk_hs_p        ,
            input   var logic           cam_clk_hs_n        ,
            input   var logic           cam_clk_lp_p        ,
            input   var logic           cam_clk_lp_n        ,
            input   var logic   [1:0]   cam_data_hs_p       ,
            input   var logic   [1:0]   cam_data_hs_n       ,
            input   var logic   [1:0]   cam_data_lp_p       ,
            input   var logic   [1:0]   cam_data_lp_n       ,
            output  var logic           cam_gpio0           ,
            output  var logic           cam_gpio1           ,
            inout   tri logic           cam_scl             ,
            inout   tri logic           cam_sda             ,
            
            inout   tri logic   [14:0]  DDR_addr            ,
            inout   tri logic   [2:0]   DDR_ba              ,
            inout   tri logic           DDR_cas_n           ,
            inout   tri logic           DDR_ck_n            ,
            inout   tri logic           DDR_ck_p            ,
            inout   tri logic           DDR_cke             ,
            inout   tri logic           DDR_cs_n            ,
            inout   tri logic   [3:0]   DDR_dm              ,
            inout   tri logic   [31:0]  DDR_dq              ,
            inout   tri logic   [3:0]   DDR_dqs_n           ,
            inout   tri logic   [3:0]   DDR_dqs_p           ,
            inout   tri logic           DDR_odt             ,
            inout   tri logic           DDR_ras_n           ,
            inout   tri logic           DDR_reset_n         ,
            inout   tri logic           DDR_we_n            ,
            inout   tri logic           FIXED_IO_ddr_vrn    ,
            inout   tri logic           FIXED_IO_ddr_vrp    ,
            inout   tri logic   [53:0]  FIXED_IO_mio        ,
            inout   tri logic           FIXED_IO_ps_clk     ,
            inout   tri logic           FIXED_IO_ps_porb    ,
            inout   tri logic           FIXED_IO_ps_srstb   
        );
    

    // ----------------------------------------
    //  Zynq block
    // ----------------------------------------

    localparam  int     AXI4L_PERI_ADDR_BITS = 32   ;
    localparam  int     AXI4L_PERI_DATA_BITS = 32   ;
    localparam  int     AXI4_MEM_ID_BITS     = 6    ;
    localparam  int     AXI4_MEM_ADDR_BITS   = 32   ;
    localparam  int     AXI4_MEM_DATA_BITS   = 64   ;

    logic           sys_reset           ;
    logic           sys_clk100          ;
    logic           sys_clk200          ;
    logic           sys_clk250          ;
    
    logic           axi4l_peri_aresetn  ;
    logic           axi4l_peri_aclk     ;
    logic           axi4_mem_aresetn    ;
    logic           axi4_mem_aclk       ;
    
    logic           IIC_0_0_scl_i       ;
    logic           IIC_0_0_scl_o       ;
    logic           IIC_0_0_scl_t       ;
    logic           IIC_0_0_sda_i       ;
    logic           IIC_0_0_sda_o       ;
    logic           IIC_0_0_sda_t       ;

    jelly3_axi4l_if
            #(
                .ADDR_BITS  (AXI4L_PERI_ADDR_BITS   ),
                .DATA_BITS  (AXI4L_PERI_DATA_BITS   )
            )
        axi4l_peri
            (
                .aresetn    (axi4l_peri_aresetn     ),
                .aclk       (axi4l_peri_aclk        ),
                .aclken     (1'b1                   )
            );

    jelly3_axi4_if
            #(
                .ID_BITS    (AXI4_MEM_ID_BITS       ),
                .ADDR_BITS  (AXI4_MEM_ADDR_BITS     ),
                .DATA_BITS  (AXI4_MEM_DATA_BITS     )
            )
        axi4_mem0
            (
                .aresetn    (axi4_mem_aresetn       ),
                .aclk       (axi4_mem_aclk          ),
                .aclken     (1'b1                   )
            );

    jelly3_axi4_if
            #(
                .ID_BITS    (AXI4_MEM_ID_BITS       ),
                .ADDR_BITS  (AXI4_MEM_ADDR_BITS     ),
                .DATA_BITS  (AXI4_MEM_DATA_BITS     )
            )
        axi4_mem1
            (
                .aresetn    (axi4_mem_aresetn       ),
                .aclk       (axi4_mem_aclk          ),
                .aclken     (1'b1                   )
            );

    design_1
        u_design_1
            (
                .sys_reset              (1'b0               ),
                .sys_clock              (in_clk125          ),
                
                .out_reset              (sys_reset          ),
                .out_clk100             (sys_clk100         ),
                .out_clk200             (sys_clk200         ),
                .out_clk250             (sys_clk250         ),
                
                .m_axi4l_peri_aresetn   (axi4l_peri_aresetn ),
                .m_axi4l_peri_aclk      (axi4l_peri_aclk    ),
                .m_axi4l_peri_awaddr    (axi4l_peri.awaddr  ),
                .m_axi4l_peri_awprot    (axi4l_peri.awprot  ),
                .m_axi4l_peri_awvalid   (axi4l_peri.awvalid ),
                .m_axi4l_peri_awready   (axi4l_peri.awready ),
                .m_axi4l_peri_wstrb     (axi4l_peri.wstrb   ),
                .m_axi4l_peri_wdata     (axi4l_peri.wdata   ),
                .m_axi4l_peri_wvalid    (axi4l_peri.wvalid  ),
                .m_axi4l_peri_wready    (axi4l_peri.wready  ),
                .m_axi4l_peri_bresp     (axi4l_peri.bresp   ),
                .m_axi4l_peri_bvalid    (axi4l_peri.bvalid  ),
                .m_axi4l_peri_bready    (axi4l_peri.bready  ),
                .m_axi4l_peri_araddr    (axi4l_peri.araddr  ),
                .m_axi4l_peri_arprot    (axi4l_peri.arprot  ),
                .m_axi4l_peri_arvalid   (axi4l_peri.arvalid ),
                .m_axi4l_peri_arready   (axi4l_peri.arready ),
                .m_axi4l_peri_rdata     (axi4l_peri.rdata   ),
                .m_axi4l_peri_rresp     (axi4l_peri.rresp   ),
                .m_axi4l_peri_rvalid    (axi4l_peri.rvalid  ),
                .m_axi4l_peri_rready    (axi4l_peri.rready  ),
                
                .s_axi4_mem_aresetn     (axi4_mem_aresetn   ),
                .s_axi4_mem_aclk        (axi4_mem_aclk      ),

                .s_axi4_mem0_awid       (axi4_mem0.awid     ),
                .s_axi4_mem0_awaddr     (axi4_mem0.awaddr   ),
                .s_axi4_mem0_awburst    (axi4_mem0.awburst  ),
                .s_axi4_mem0_awcache    (axi4_mem0.awcache  ),
                .s_axi4_mem0_awlen      (axi4_mem0.awlen    ),
                .s_axi4_mem0_awlock     (axi4_mem0.awlock   ),
                .s_axi4_mem0_awprot     (axi4_mem0.awprot   ),
                .s_axi4_mem0_awqos      (axi4_mem0.awqos    ),
    //          .s_axi4_mem0_awregion   (axi4_mem0.awregion ),
                .s_axi4_mem0_awsize     (axi4_mem0.awsize   ),
                .s_axi4_mem0_awvalid    (axi4_mem0.awvalid  ),
                .s_axi4_mem0_awready    (axi4_mem0.awready  ),
                .s_axi4_mem0_wstrb      (axi4_mem0.wstrb    ),
                .s_axi4_mem0_wdata      (axi4_mem0.wdata    ),
                .s_axi4_mem0_wlast      (axi4_mem0.wlast    ),
                .s_axi4_mem0_wvalid     (axi4_mem0.wvalid   ),
                .s_axi4_mem0_wready     (axi4_mem0.wready   ),
                .s_axi4_mem0_bid        (axi4_mem0.bid      ),
                .s_axi4_mem0_bresp      (axi4_mem0.bresp    ),
                .s_axi4_mem0_bvalid     (axi4_mem0.bvalid   ),
                .s_axi4_mem0_bready     (axi4_mem0.bready   ),
                .s_axi4_mem0_araddr     (axi4_mem0.araddr   ),
                .s_axi4_mem0_arburst    (axi4_mem0.arburst  ),
                .s_axi4_mem0_arcache    (axi4_mem0.arcache  ),
                .s_axi4_mem0_arid       (axi4_mem0.arid     ),
                .s_axi4_mem0_arlen      (axi4_mem0.arlen    ),
                .s_axi4_mem0_arlock     (axi4_mem0.arlock   ),
                .s_axi4_mem0_arprot     (axi4_mem0.arprot   ),
                .s_axi4_mem0_arqos      (axi4_mem0.arqos    ),
    //          .s_axi4_mem0_arregion   (axi4_mem0.arregion ),
                .s_axi4_mem0_arsize     (axi4_mem0.arsize   ),
                .s_axi4_mem0_arvalid    (axi4_mem0.arvalid  ),
                .s_axi4_mem0_arready    (axi4_mem0.arready  ),
                .s_axi4_mem0_rid        (axi4_mem0.rid      ),
                .s_axi4_mem0_rresp      (axi4_mem0.rresp    ),
                .s_axi4_mem0_rdata      (axi4_mem0.rdata    ),
                .s_axi4_mem0_rlast      (axi4_mem0.rlast    ),
                .s_axi4_mem0_rvalid     (axi4_mem0.rvalid   ),
                .s_axi4_mem0_rready     (axi4_mem0.rready   ),

                .s_axi4_mem1_awid       (axi4_mem1.awid     ),
                .s_axi4_mem1_awaddr     (axi4_mem1.awaddr   ),
                .s_axi4_mem1_awburst    (axi4_mem1.awburst  ),
                .s_axi4_mem1_awcache    (axi4_mem1.awcache  ),
                .s_axi4_mem1_awlen      (axi4_mem1.awlen    ),
                .s_axi4_mem1_awlock     (axi4_mem1.awlock   ),
                .s_axi4_mem1_awprot     (axi4_mem1.awprot   ),
                .s_axi4_mem1_awqos      (axi4_mem1.awqos    ),
    //          .s_axi4_mem1_awregion   (axi4_mem1.awregion ),
                .s_axi4_mem1_awsize     (axi4_mem1.awsize   ),
                .s_axi4_mem1_awvalid    (axi4_mem1.awvalid  ),
                .s_axi4_mem1_awready    (axi4_mem1.awready  ),
                .s_axi4_mem1_wstrb      (axi4_mem1.wstrb    ),
                .s_axi4_mem1_wdata      (axi4_mem1.wdata    ),
                .s_axi4_mem1_wlast      (axi4_mem1.wlast    ),
                .s_axi4_mem1_wvalid     (axi4_mem1.wvalid   ),
                .s_axi4_mem1_wready     (axi4_mem1.wready   ),
                .s_axi4_mem1_bid        (axi4_mem1.bid      ),
                .s_axi4_mem1_bresp      (axi4_mem1.bresp    ),
                .s_axi4_mem1_bvalid     (axi4_mem1.bvalid   ),
                .s_axi4_mem1_bready     (axi4_mem1.bready   ),
                .s_axi4_mem1_araddr     (axi4_mem1.araddr   ),
                .s_axi4_mem1_arburst    (axi4_mem1.arburst  ),
                .s_axi4_mem1_arcache    (axi4_mem1.arcache  ),
                .s_axi4_mem1_arid       (axi4_mem1.arid     ),
                .s_axi4_mem1_arlen      (axi4_mem1.arlen    ),
                .s_axi4_mem1_arlock     (axi4_mem1.arlock   ),
                .s_axi4_mem1_arprot     (axi4_mem1.arprot   ),
                .s_axi4_mem1_arqos      (axi4_mem1.arqos    ),
    //          .s_axi4_mem1_arregion   (axi4_mem1.arregion ),
                .s_axi4_mem1_arsize     (axi4_mem1.arsize   ),
                .s_axi4_mem1_arvalid    (axi4_mem1.arvalid  ),
                .s_axi4_mem1_arready    (axi4_mem1.arready  ),
                .s_axi4_mem1_rid        (axi4_mem1.rid      ),
                .s_axi4_mem1_rresp      (axi4_mem1.rresp    ),
                .s_axi4_mem1_rdata      (axi4_mem1.rdata    ),
                .s_axi4_mem1_rlast      (axi4_mem1.rlast    ),
                .s_axi4_mem1_rvalid     (axi4_mem1.rvalid   ),
                .s_axi4_mem1_rready     (axi4_mem1.rready   ),

                .DDR_addr               (DDR_addr           ),
                .DDR_ba                 (DDR_ba             ),
                .DDR_cas_n              (DDR_cas_n          ),
                .DDR_ck_n               (DDR_ck_n           ),
                .DDR_ck_p               (DDR_ck_p           ),
                .DDR_cke                (DDR_cke            ),
                .DDR_cs_n               (DDR_cs_n           ),
                .DDR_dm                 (DDR_dm             ),
                .DDR_dq                 (DDR_dq             ),
                .DDR_dqs_n              (DDR_dqs_n          ),
                .DDR_dqs_p              (DDR_dqs_p          ),
                .DDR_odt                (DDR_odt            ),
                .DDR_ras_n              (DDR_ras_n          ),
                .DDR_reset_n            (DDR_reset_n        ),
                .DDR_we_n               (DDR_we_n           ),
                .FIXED_IO_ddr_vrn       (FIXED_IO_ddr_vrn   ),
                .FIXED_IO_ddr_vrp       (FIXED_IO_ddr_vrp   ),
                .FIXED_IO_mio           (FIXED_IO_mio       ),
                .FIXED_IO_ps_clk        (FIXED_IO_ps_clk    ),
                .FIXED_IO_ps_porb       (FIXED_IO_ps_porb   ),
                .FIXED_IO_ps_srstb      (FIXED_IO_ps_srstb  ),
                
                .IIC_0_0_scl_i          (IIC_0_0_scl_i      ),
                .IIC_0_0_scl_o          (IIC_0_0_scl_o      ),
                .IIC_0_0_scl_t          (IIC_0_0_scl_t      ),
                .IIC_0_0_sda_i          (IIC_0_0_sda_i      ),
                .IIC_0_0_sda_o          (IIC_0_0_sda_o      ),
                .IIC_0_0_sda_t          (IIC_0_0_sda_t      )
            );
    
    IOBUF
        u_IOBUF_cam_scl
            (
                .IO     (cam_scl        ),
                .I      (IIC_0_0_scl_o  ),
                .O      (IIC_0_0_scl_i  ),
                .T      (IIC_0_0_scl_t  )
            );

    IOBUF
        u_iobuf_cam_sda
            (
                .IO     (cam_sda        ),
                .I      (IIC_0_0_sda_o  ),
                .O      (IIC_0_0_sda_i  ),
                .T      (IIC_0_0_sda_t  )
            );
    

    // ----------------------------------------
    //  Address decoder
    // ----------------------------------------

    localparam DEC_SYS      = 0;
    localparam DEC_TGEN     = 1;
    localparam DEC_FMTR     = 2;
    localparam DEC_WDMA_IMG = 3;
    localparam DEC_WDMA_BLK = 4;
    localparam DEC_TBLMOD   = 5;
    localparam DEC_LPF      = 6;
    localparam DEC_HUB75    = 7;
    localparam DEC_NUM      = 8;

    jelly3_axi4l_if
            #(
                .ADDR_BITS      (AXI4L_PERI_ADDR_BITS),
                .DATA_BITS      (AXI4L_PERI_DATA_BITS)
            )
        axi4l_dec [DEC_NUM]
            (
                .aresetn        (axi4l_peri_aresetn  ),
                .aclk           (axi4l_peri_aclk     ),
                .aclken         (1'b1                )
            );
    
    // address map
    assign {axi4l_dec[DEC_SYS     ].addr_base, axi4l_dec[DEC_SYS     ].addr_high} = {32'h4000_0000, 32'h4000_ffff};
    assign {axi4l_dec[DEC_TGEN    ].addr_base, axi4l_dec[DEC_TGEN    ].addr_high} = {32'h4001_0000, 32'h4001_ffff};
    assign {axi4l_dec[DEC_FMTR    ].addr_base, axi4l_dec[DEC_FMTR    ].addr_high} = {32'h4010_0000, 32'h4010_ffff};
    assign {axi4l_dec[DEC_WDMA_IMG].addr_base, axi4l_dec[DEC_WDMA_IMG].addr_high} = {32'h4021_0000, 32'h4021_ffff};
    assign {axi4l_dec[DEC_WDMA_BLK].addr_base, axi4l_dec[DEC_WDMA_BLK].addr_high} = {32'h4022_0000, 32'h4022_ffff};
    assign {axi4l_dec[DEC_TBLMOD  ].addr_base, axi4l_dec[DEC_TBLMOD  ].addr_high} = {32'h4030_0000, 32'h4030_ffff};
    assign {axi4l_dec[DEC_LPF     ].addr_base, axi4l_dec[DEC_LPF     ].addr_high} = {32'h4032_0000, 32'h4032_ffff};
    assign {axi4l_dec[DEC_HUB75   ].addr_base, axi4l_dec[DEC_HUB75   ].addr_high} = {32'h4040_0000, 32'h4040_ffff};

    jelly3_axi4l_addr_decoder
            #(
                .NUM            (DEC_NUM    ),
                .DEC_ADDR_BITS  (28         )
            )
        u_axi4l_addr_decoder
            (
                .s_axi4l        (axi4l_peri   ),
                .m_axi4l        (axi4l_dec    )
            );

    // ----------------------------------------
    //  System Control
    // ----------------------------------------

    localparam  SYSREG_ID             = 4'h0;
    localparam  SYSREG_SW_RESET       = 4'h1;
    localparam  SYSREG_CAM_ENABLE     = 4'h2;
    localparam  SYSREG_CSI_DATA_TYPE  = 4'h3;
    localparam  SYSREG_DPHY_INIT_DONE = 4'h4;
    localparam  SYSREG_FPS_COUNT      = 4'h6;
    localparam  SYSREG_FRAME_COUNT    = 4'h7;
    localparam  SYSREG_IMG_WIDTH      = 4'h8;
    localparam  SYSREG_IMG_HEIGHT     = 4'h9;
    localparam  SYSREG_BLK_WIDTH      = 4'ha;
    localparam  SYSREG_BLK_HEIGHT     = 4'hb;
    localparam  SYSREG_DMA_SEL        = 4'hf;

    (* MARK_DEBUG=DEBUG *)  logic               reg_sw_reset        ;
    (* MARK_DEBUG=DEBUG *)  logic               reg_cam_enable      ;
    (* MARK_DEBUG=DEBUG *)  logic   [7:0]       reg_csi_data_type   ;
    (* MARK_DEBUG=DEBUG *)  logic               reg_dphy_init_done  ;
                            logic   [31:0]      reg_fps_count       ;
                            logic   [31:0]      reg_frame_count = 0 ;
                            width_t             reg_image_width     ;
                            height_t            reg_image_height    ;
                            width_t             reg_black_width     ;
                            height_t            reg_black_height    ;

    always_ff @(posedge axi4l_dec[DEC_SYS].aclk) begin
        if ( ~axi4l_dec[DEC_SYS].aresetn ) begin
            axi4l_dec[DEC_SYS].bvalid <= 1'b0   ;
            axi4l_dec[DEC_SYS].rdata  <= '0     ;
            axi4l_dec[DEC_SYS].rvalid <= 1'b0   ;

            reg_sw_reset      <= 1'b0       ;
            reg_cam_enable    <= 1'b0       ;
            reg_csi_data_type <= 8'h2b      ;
            reg_image_width   <= IMG_WIDTH  ;
            reg_image_height  <= IMG_HEIGHT ;
            reg_black_width   <= 1280       ;
            reg_black_height  <=    1       ;
        end
        else begin
            // write
            if ( axi4l_dec[DEC_SYS].bready ) begin
                axi4l_dec[DEC_SYS].bvalid <= 1'b0;
            end
            if ( axi4l_dec[DEC_SYS].awvalid && axi4l_dec[DEC_SYS].awready 
                    && axi4l_dec[DEC_SYS].wvalid && axi4l_dec[DEC_SYS].wready
                    && axi4l_dec[DEC_SYS].wstrb[0] ) begin
                case ( axi4l_dec[DEC_SYS].awaddr[5:2] )
                SYSREG_SW_RESET     :   reg_sw_reset      <=         1'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_CAM_ENABLE   :   reg_cam_enable    <=         1'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_CSI_DATA_TYPE:   reg_csi_data_type <=         8'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_IMG_WIDTH    :   reg_image_width   <=   width_t'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_IMG_HEIGHT   :   reg_image_height  <=  height_t'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_BLK_WIDTH    :   reg_black_width   <=   width_t'(axi4l_dec[DEC_SYS].wdata);
                SYSREG_BLK_HEIGHT   :   reg_black_height  <=  height_t'(axi4l_dec[DEC_SYS].wdata);
                default:;
                endcase
                axi4l_dec[DEC_SYS].bvalid <= 1'b1;
            end

            // read
            if ( axi4l_dec[DEC_SYS].rready ) begin
                axi4l_dec[DEC_SYS].rdata  <= '0;
                axi4l_dec[DEC_SYS].rvalid <= 1'b0;
            end
            if ( axi4l_dec[DEC_SYS].arvalid && axi4l_dec[DEC_SYS].arready ) begin
                case ( axi4l_dec[DEC_SYS].araddr[5:2] )
                SYSREG_ID            :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(32'h55aa0101)      ;
                SYSREG_SW_RESET      :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_sw_reset)      ;
                SYSREG_CAM_ENABLE    :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_cam_enable)    ;
                SYSREG_CSI_DATA_TYPE :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_csi_data_type) ;
                SYSREG_DPHY_INIT_DONE:  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_dphy_init_done);
                SYSREG_FPS_COUNT     :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_fps_count)     ;
                SYSREG_FRAME_COUNT   :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_frame_count)   ;
                SYSREG_IMG_WIDTH     :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_image_width)   ;
                SYSREG_IMG_HEIGHT    :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_image_height)  ;
                SYSREG_BLK_WIDTH     :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_black_width)   ;
                SYSREG_BLK_HEIGHT    :  axi4l_dec[DEC_SYS].rdata  <= axi4l_dec[DEC_SYS].DATA_BITS'(reg_black_height)  ;
                default:    axi4l_dec[DEC_SYS].rdata  <= '0    ;
                endcase
                axi4l_dec[DEC_SYS].rvalid <= 1'b1;
            end
        end
    end
    assign axi4l_dec[DEC_SYS].awready = axi4l_dec[DEC_SYS].wvalid  && !axi4l_dec[DEC_SYS].bvalid;
    assign axi4l_dec[DEC_SYS].wready  = axi4l_dec[DEC_SYS].awvalid && !axi4l_dec[DEC_SYS].bvalid;
    assign axi4l_dec[DEC_SYS].bresp   = '0;
    assign axi4l_dec[DEC_SYS].arready = !axi4l_dec[DEC_SYS].rvalid;
    assign axi4l_dec[DEC_SYS].rresp   = '0;

    assign cam_gpio0 = reg_cam_enable;


    // ----------------------------------------
    //  Timing Generator
    // ----------------------------------------

    logic   [31:0]       timegen_frames;

    timing_generator
            #(
                .TIMER_BITS             (     32),
                .REGADR_BITS            (      8),
                .INIT_CTL_CONTROL       (  2'b11),
                .INIT_PARAM_PERIOD      ( 100000),  // 1ms  (100MHz)
                .INIT_PARAM_TRIG0_START (      1),
                .INIT_PARAM_TRIG0_END   (  90000),
                .INIT_PARAM_TRIG0_POL   (      0)
            )
        u_timing_generator
            (
                .s_axi4l                (axi4l_dec[DEC_TGEN].s  ),
                .out_trig0              (cam_gpio1              ),
                .out_frames             (timegen_frames         )
            );


    
    // ----------------------------------------
    //  MIPI D-PHY RX
    // ----------------------------------------
    
                            logic               rxbyteclkhs         ;
    (* mark_debug=DEBUG *)  logic               system_rst_out      ;
    (* mark_debug=DEBUG *)  logic               init_done           ;
    
                            logic               cl_rxclkactivehs    ;
                            logic               cl_stopstate        ;
                            logic               cl_enable           ;
                            logic               cl_rxulpsclknot     ;
                            logic               cl_ulpsactivenot    ;
    
    (* mark_debug=DEBUG *)  logic   [7:0]       dl0_rxdatahs        ;
    (* mark_debug=DEBUG *)  logic               dl0_rxvalidhs       ;
    (* mark_debug=DEBUG *)  logic               dl0_rxactivehs      ;
    (* mark_debug=DEBUG *)  logic               dl0_rxsynchs        ;
                            logic               dl0_forcerxmode     ;
                            logic               dl0_stopstate       ;
                            logic               dl0_enable          ;
                            logic               dl0_ulpsactivenot   ;
                            logic               dl0_rxclkesc        ;
                            logic               dl0_rxlpdtesc       ;
                            logic               dl0_rxulpsesc       ;
                            logic   [3:0]       dl0_rxtriggeresc    ;
                            logic   [7:0]       dl0_rxdataesc       ;
                            logic               dl0_rxvalidesc      ;
                            logic               dl0_errsoths        ;
                            logic               dl0_errsotsynchs    ;
                            logic               dl0_erresc          ;
                            logic               dl0_errsyncesc      ;
                            logic               dl0_errcontrol      ;
    
    (* mark_debug=DEBUG *)  logic   [7:0]       dl1_rxdatahs        ;
    (* mark_debug=DEBUG *)  logic               dl1_rxvalidhs       ;
    (* mark_debug=DEBUG *)  logic               dl1_rxactivehs      ;
    (* mark_debug=DEBUG *)  logic               dl1_rxsynchs        ;
                            logic               dl1_forcerxmode     ;
                            logic               dl1_stopstate       ;
                            logic               dl1_enable          ;
                            logic               dl1_ulpsactivenot   ;
                            logic               dl1_rxclkesc        ;
                            logic               dl1_rxlpdtesc       ;
                            logic               dl1_rxulpsesc       ;
                            logic   [3:0]       dl1_rxtriggeresc    ;
                            logic   [7:0]       dl1_rxdataesc       ;
                            logic               dl1_rxvalidesc      ;
                            logic               dl1_errsoths        ;
                            logic               dl1_errsotsynchs    ;
                            logic               dl1_erresc          ;
                            logic               dl1_errsyncesc      ;
                            logic               dl1_errcontrol      ;
    
    mipi_dphy_cam
        i_mipi_dphy_cam
            (
                .core_clk           (sys_clk200         ),
                .core_rst           (sys_reset | reg_sw_reset),
                .rxbyteclkhs        (rxbyteclkhs        ),
                .system_rst_out     (system_rst_out     ),
                .init_done          (init_done          ),
                
                .cl_rxclkactivehs   (cl_rxclkactivehs   ),
                .cl_stopstate       (cl_stopstate       ),
                .cl_enable          (cl_enable          ),
                .cl_rxulpsclknot    (cl_rxulpsclknot    ),
                .cl_ulpsactivenot   (cl_ulpsactivenot   ),
                
                .dl0_rxdatahs       (dl0_rxdatahs       ),
                .dl0_rxvalidhs      (dl0_rxvalidhs      ),
                .dl0_rxactivehs     (dl0_rxactivehs     ),
                .dl0_rxsynchs       (dl0_rxsynchs       ),
                
                .dl0_forcerxmode    (dl0_forcerxmode    ),
                .dl0_stopstate      (dl0_stopstate      ),
                .dl0_enable         (dl0_enable         ),
                .dl0_ulpsactivenot  (dl0_ulpsactivenot  ),
                
                .dl0_rxclkesc       (dl0_rxclkesc       ),
                .dl0_rxlpdtesc      (dl0_rxlpdtesc      ),
                .dl0_rxulpsesc      (dl0_rxulpsesc      ),
                .dl0_rxtriggeresc   (dl0_rxtriggeresc   ),
                .dl0_rxdataesc      (dl0_rxdataesc      ),
                .dl0_rxvalidesc     (dl0_rxvalidesc     ),
                
                .dl0_errsoths       (dl0_errsoths       ),
                .dl0_errsotsynchs   (dl0_errsotsynchs   ),
                .dl0_erresc         (dl0_erresc         ),
                .dl0_errsyncesc     (dl0_errsyncesc     ),
                .dl0_errcontrol     (dl0_errcontrol     ),
                
                .dl1_rxdatahs       (dl1_rxdatahs       ),
                .dl1_rxvalidhs      (dl1_rxvalidhs      ),
                .dl1_rxactivehs     (dl1_rxactivehs     ),
                .dl1_rxsynchs       (dl1_rxsynchs       ),
                
                .dl1_forcerxmode    (dl1_forcerxmode    ),
                .dl1_stopstate      (dl1_stopstate      ),
                .dl1_enable         (dl1_enable         ),
                .dl1_ulpsactivenot  (dl1_ulpsactivenot  ),
                
                .dl1_rxclkesc       (dl1_rxclkesc       ),
                .dl1_rxlpdtesc      (dl1_rxlpdtesc      ),
                .dl1_rxulpsesc      (dl1_rxulpsesc      ),
                .dl1_rxtriggeresc   (dl1_rxtriggeresc   ),
                .dl1_rxdataesc      (dl1_rxdataesc      ),
                .dl1_rxvalidesc     (dl1_rxvalidesc     ),
                
                .dl1_errsoths       (dl1_errsoths       ),
                .dl1_errsotsynchs   (dl1_errsotsynchs   ),
                .dl1_erresc         (dl1_erresc         ),
                .dl1_errsyncesc     (dl1_errsyncesc     ),
                .dl1_errcontrol     (dl1_errcontrol     ),
                
                .clk_hs_rxp         (cam_clk_hs_p       ),
                .clk_hs_rxn         (cam_clk_hs_n       ),
                .clk_lp_rxp         (cam_clk_lp_p       ),
                .clk_lp_rxn         (cam_clk_lp_n       ),
                .data_hs_rxp        (cam_data_hs_p      ),
                .data_hs_rxn        (cam_data_hs_n      ),
                .data_lp_rxp        (cam_data_lp_p      ),
                .data_lp_rxn        (cam_data_lp_n      )
           );

    assign cl_enable         = 1'b1;
    assign dl0_forcerxmode   = 1'b0;
    assign dl0_enable        = 1'b1;
    assign dl1_forcerxmode   = 1'b0;
    assign dl1_enable        = 1'b1;
    always_ff @(posedge axi4l_dec[DEC_SYS].aclk) begin
        reg_dphy_init_done <= init_done;
    end

    logic   dphy_clk    ;
    logic   dphy_reset  ;
    assign dphy_clk   = rxbyteclkhs;
    assign dphy_reset = system_rst_out;

    

   // -------------------------------------
    //  RTCL-P3S7 Recv
    // -------------------------------------

    logic   axi4s_cam_aresetn   ;
    logic   axi4s_cam_aclk      ;
    assign axi4s_cam_aresetn = ~sys_reset   ;
//  assign axi4s_cam_aclk    = sys_clk250   ;
    assign axi4s_cam_aclk    = sys_clk200   ;

    logic   axi4s_img_aresetn   ;
    logic   axi4s_img_aclk      ;
    assign axi4s_img_aresetn = ~sys_reset   ;
    assign axi4s_img_aclk    = sys_clk100   ;

    jelly3_axi4s_if
            #(
                .USE_LAST       (1'b1               ),
                .USE_USER       (1'b1               ),
                .DATA_BITS      (10                 ),
                .USER_BITS      (1                  ),
                .DEBUG          (DEBUG              )
            )
        axi4s_blk
            (
                .aresetn        (axi4s_cam_aresetn  ),
                .aclk           (axi4s_cam_aclk     ),
                .aclken         (1'b1               )
            );

    jelly3_axi4s_if
            #(
                .USE_LAST       (1'b1               ),
                .USE_USER       (1'b1               ),
                .DATA_BITS      (10                 ),
                .USER_BITS      (1                  ),
                .DEBUG          (DEBUG              )
            )
        axi4s_img
            (
                .aresetn        (axi4s_cam_aresetn  ),
                .aclk           (axi4s_cam_aclk     ),
                .aclken         (1'b1               )
            );

    rtcl_p3s7_hs_dphy_recv
            #(
                .X_BITS             ($bits(width_t)     ),
                .Y_BITS             ($bits(height_t)    ),
                .CHANNELS           (1                  ),
                .RAW_BITS           (10                 ),
                .DPHY_LANES         (2                  ),
                .DEBUG              ("false"            )
            )
        u_rtcl_p3s7_hs_dphy_recv
            (
                .param_black_width  (reg_black_width    ),
                .param_black_height (reg_black_height   ),
                .param_image_width  (reg_image_width    ),
                .param_image_height (reg_image_height   ),

                .header_data        (                   ),
                .header_valid       (                   ),

                .dphy_reset         (dphy_reset         ),
                .dphy_clk           (dphy_clk           ),
                .dphy_data          ({
                                        dl1_rxdatahs,
                                        dl0_rxdatahs
                                    }),
                .dphy_valid         (dl0_rxvalidhs      ),

                .m_axi4s_black      (axi4s_blk          ),
                .m_axi4s_image      (axi4s_img          )
            );

    // FIFO
    jelly3_axi4s_if
            #(
                .DATA_BITS  (10               )
            )
        axi4s_img_fifo
            (
                .aresetn    (axi4s_img_aresetn),
                .aclk       (axi4s_img_aclk   ),
                .aclken     (1'b1             )
            );
    
    jelly3_axi4s_fifo
            #(
                .ASYNC          (1                  ),
                .PTR_BITS       (9                  ),
                .RAM_TYPE       ("block"            ),
                .DOUT_REG       (1                  ),
                .S_REG          (1                  ),
                .M_REG          (1                  )
            )
        u_axi4s_fifo
            (
                .s_axi4s        (axi4s_img.s        ),
                .m_axi4s        (axi4s_img_fifo.m   ),
                .s_free_size    (                   ),
                .m_data_size    (                   )
            );

    // format regularizer
    logic   [WIDTH_BITS-1:0]    fmtr_param_width;
    logic   [HEIGHT_BITS-1:0]   fmtr_param_height;

    jelly3_axi4s_if
            #(
                .DATA_BITS  (10                     ),
                .DEBUG      ("true"                 )
            )
        axi4s_fmtr
            (
                .aresetn    (axi4s_img_aresetn      ),
                .aclk       (axi4s_img_aclk         ),
                .aclken     (1'b1                   )
            );
    
    // video_format_regularizer
    jelly3_video_format_regularizer
            #(
                .width_t                (logic [WIDTH_BITS-1:0] ),
                .height_t               (logic [HEIGHT_BITS-1:0]),
                .INIT_CTL_CONTROL       (2'b00                  ),
                .INIT_CTL_SKIP          (1                      ),
                .INIT_PARAM_WIDTH       (WIDTH_BITS'(IMG_WIDTH) ),
                .INIT_PARAM_HEIGHT      (HEIGHT_BITS'(IMG_HEIGHT)),
                .INIT_PARAM_FILL        (10'd0                  ),
                .INIT_PARAM_TIMEOUT     (32'h00010000           )
            )
        u_video_format_regularizer
            (
                .s_axi4s                (axi4s_img_fifo.s       ),
                .m_axi4s                (axi4s_fmtr.m           ),
                .s_axi4l                (axi4l_dec[DEC_FMTR].s  ),
                .out_param_width        (fmtr_param_width       ),
                .out_param_height       (fmtr_param_height      )
            );
    
    // binary modulation
    logic   [0:0]               axi4s_bin_tuser     ;
    logic                       axi4s_bin_tlast     ;
    logic   [9:0]               axi4s_bin_tdata     ;
    logic   [0:0]               axi4s_bin_tbinary   ;
    logic                       axi4s_bin_tvalid    ;
    logic                       axi4s_bin_tready    ;
    
    video_tbl_modulator
            #(
                .TUSER_BITS             (1                      ),
                .TDATA_BITS             (10                     ),
                .INIT_PARAM_END         (0                      ),
                .INIT_PARAM_INV         (0                      )
            )
        u_video_tbl_modulator
            (
                .s_axi4l                (axi4l_dec[DEC_TBLMOD]  ),

                .aresetn                (axi4s_img_aresetn      ),
                .aclk                   (axi4s_img_aclk         ),
                .aclken                 (1'b1                   ),
                
                .s_axi4s_tuser          (axi4s_fmtr.tuser       ),
                .s_axi4s_tlast          (axi4s_fmtr.tlast       ),
                .s_axi4s_tdata          (axi4s_fmtr.tdata       ),
                .s_axi4s_tvalid         (axi4s_fmtr.tvalid      ),
                .s_axi4s_tready         (axi4s_fmtr.tready      ),
                
                .m_axi4s_tuser          (axi4s_bin_tuser        ),
                .m_axi4s_tlast          (axi4s_bin_tlast        ),
                .m_axi4s_tbinary        (axi4s_bin_tbinary      ),
                .m_axi4s_tdata          (axi4s_bin_tdata        ),
                .m_axi4s_tvalid         (axi4s_bin_tvalid       ),
                .m_axi4s_tready         (axi4s_bin_tready       )
            );
    
    // mnist
    logic   [0:0]       axi4s_mnist_tuser   ;
    logic               axi4s_mnist_tlast   ;
    logic   [9:0]       axi4s_mnist_tdata   ;
    logic   [10:0]      axi4s_mnist_tclass  ;
    logic               axi4s_mnist_tvalid  ;
    logic               axi4s_mnist_tready  ;

    if ( 1 ) begin : mnist
        mnist_seg
                #(
                    .TUSER_WIDTH        (10 + 1     ),
                    .MAX_X_NUM          (1024       ),
                    .RAM_TYPE           ("block"    ),
                    .IMG_Y_NUM          (480        ),
                    .IMG_Y_WIDTH        (12         ),
                    .S_TDATA_WIDTH      (1          ),
                    .M_TDATA_WIDTH      (11         ),
                    .DEVICE             ("rtl"      )
                )
            u_mnist_seg
                (
                    .reset              (~axi4s_img_aresetn ),
                    .clk                (axi4s_img_aclk     ),
                    
                    .param_blank_num    (8'd30),
                    
                    .s_axi4s_tuser      ({
                                            axi4s_bin_tdata,
                                            axi4s_bin_tuser
                                        }),
                    .s_axi4s_tlast      (axi4s_bin_tlast    ),
                    .s_axi4s_tdata      (axi4s_bin_tbinary  ),
                    .s_axi4s_tvalid     (axi4s_bin_tvalid   ),
                    .s_axi4s_tready     (axi4s_bin_tready   ),
                    
                    .m_axi4s_tuser      ({
                                            axi4s_mnist_tdata ,
                                            axi4s_mnist_tuser
                                        }),
                    .m_axi4s_tlast      (axi4s_mnist_tlast  ),
                    .m_axi4s_tdata      (axi4s_mnist_tclass ),
                    .m_axi4s_tvalid     (axi4s_mnist_tvalid ),
                    .m_axi4s_tready     (axi4s_mnist_tready )
                );
    end
    else begin : bypass_mnist
        assign axi4s_mnist_tuser  = axi4s_bin_tuser ;
        assign axi4s_mnist_tlast  = axi4s_bin_tlast ;
        assign axi4s_mnist_tdata  = axi4s_bin_tdata ;
        assign axi4s_mnist_tclass = '0;
        assign axi4s_mnist_tvalid = axi4s_bin_tvalid;
        assign axi4s_bin_tready = axi4s_mnist_tready;
    end

    logic   [10:0][7:0]                 axi4s_mnist_tclass_u8;
    always_comb begin
        for ( int i = 0; i < 10; i++ ) begin
            axi4s_mnist_tclass_u8[i] = {8{axi4s_mnist_tclass[i]}};
        end

        // 背景の学習状況が悪いので補正
        axi4s_mnist_tclass_u8[10] = {8{~|axi4s_mnist_tclass[9:0]}};
    end

    // LowPass-filter
    logic   [0:0]               axi4s_lpf_tuser;
    logic                       axi4s_lpf_tlast;
    logic   [7:0]               axi4s_lpf_tdata;
    logic   [10:0][7:0]         axi4s_lpf_tclass;
    logic                       axi4s_lpf_tvalid;
    logic                       axi4s_lpf_tready;
    
    video_lpf_ram
            #(
                .NUM                    (11 + 1             ),
                .DATA_BITS              (8                  ),
                .ADDR_BITS              (14                 ),
                .RAM_TYPE               ("block"            ),
                .TUSER_BITS             (1                  ),
                .INIT_PARAM_ALPHA       (8'h0               )
            )
        u_video_lpf_ram
            (
                .s_axi4l                (axi4l_dec[DEC_LPF] ),

                .aresetn                (axi4s_img_aresetn  ),
                .aclk                   (axi4s_img_aclk     ),
                
                .s_axi4s_tuser          (axi4s_mnist_tuser  ),
                .s_axi4s_tlast          (axi4s_mnist_tlast  ),
                .s_axi4s_tdata          ({axi4s_mnist_tclass_u8, axi4s_mnist_tdata[9:2]}),
                .s_axi4s_tvalid         (axi4s_mnist_tvalid ),
                .s_axi4s_tready         (axi4s_mnist_tready ),
                
                .m_axi4s_tuser          (axi4s_lpf_tuser    ),
                .m_axi4s_tlast          (axi4s_lpf_tlast    ),
                .m_axi4s_tdata          ({axi4s_lpf_tclass, axi4s_lpf_tdata}),
                .m_axi4s_tvalid         (axi4s_lpf_tvalid   ),
                .m_axi4s_tready         (axi4s_lpf_tready   )
            );

    // argmax
    logic   [0:0]               axi4s_max_tuser     ;
    logic                       axi4s_max_tlast     ;
    logic   [7:0]               axi4s_max_tdata     ;
    logic   [7:0]               axi4s_max_targmax   ;
    logic                       axi4s_max_tvalid    ;
    logic                       axi4s_max_tready    ;

    video_argmax
            #(
                .CLASS_NUM              (11                 ),
                .CLASS_WIDTH            (8                  ),
                .ARGMAX_WIDTH           (8                  ),
                .TDATA_WIDTH            (8                  ),
                .TUSER_WIDTH            (1                  )
            )
        u_video_argmax
            (
                .aresetn                (axi4s_img_aresetn  ),
                .aclk                   (axi4s_img_aclk     ),

                .s_axi4s_tuser          (axi4s_lpf_tuser    ),
                .s_axi4s_tlast          (axi4s_lpf_tlast    ),
                .s_axi4s_tdata          (axi4s_lpf_tdata    ),
                .s_axi4s_tclass         (axi4s_lpf_tclass   ),
                .s_axi4s_tvalid         (axi4s_lpf_tvalid   ),
                .s_axi4s_tready         (axi4s_lpf_tready   ),

                .m_axi4s_tuser          (axi4s_max_tuser    ),
                .m_axi4s_tlast          (axi4s_max_tlast    ),
                .m_axi4s_tdata          (axi4s_max_tdata    ),
                .m_axi4s_targmax        (axi4s_max_targmax  ),
                .m_axi4s_tvalid         (axi4s_max_tvalid   ),
                .m_axi4s_tready         (axi4s_max_tready   )
            );

    // DMA write
    jelly3_axi4s_if
            #(
                .DATA_BITS  (16                 ),
                .DEBUG      ("true"             )
            )
        axi4s_dma
            (
                .aresetn    (axi4s_img_aresetn  ),
                .aclk       (axi4s_img_aclk     ),
                .aclken     (1'b1               )
            );

    jelly3_axi4s_debug_monitor
        u_axi4s_debug_monitor_dma
            (
                .mon_axi4s       (axi4s_dma.mon)
            );


    assign  axi4s_dma.tuser        = axi4s_max_tuser         ;
    assign  axi4s_dma.tlast        = axi4s_max_tlast         ;
    assign  axi4s_dma.tdata[7:0]   = axi4s_max_tdata         ;
    assign  axi4s_dma.tdata[15:8]  = axi4s_max_targmax       ;
    assign  axi4s_dma.tvalid       = axi4s_max_tvalid        ;
    assign  axi4s_max_tready = axi4s_dma.tready;

    // FIFO
    jelly3_axi4s_if
            #(
                .DATA_BITS  (16               )
            )
        axi4s_fifo
            (
                .aresetn    (axi4s_img_aresetn),
                .aclk       (axi4s_img_aclk   ),
                .aclken     (1'b1             )
            );
    
    jelly3_axi4s_fifo
            #(
                .ASYNC          (0          ),
                .PTR_BITS       (10         ),
                .RAM_TYPE       ("block"    ),
                .DOUT_REG       (1          ),
                .S_REG          (1          ),
                .M_REG          (1          )
            )
        u_axi4s_fifo_dma
            (
                .s_axi4s        (axi4s_dma.s    ),
                .m_axi4s        (axi4s_fifo.m   ),
                .s_free_size    (               ),
                .m_data_size    (               )
            );

    // DMA write
    jelly3_dma_video_write
            #(
                .AXI4L_ASYNC            (1                      ),
                .AXI4S_ASYNC            (1                      ),
                .ADDR_BITS              (AXI4_MEM_ADDR_BITS     ),
                .INDEX_BITS             (1                      ),
                .SIZE_OFFSET            (1'b1                   ),
                .H_SIZE_BITS            (14                     ),
                .V_SIZE_BITS            (14                     ),
                .F_SIZE_BITS            (14                     ),
                .LINE_STEP_BITS         (16                     ),
                .FRAME_STEP_BITS        (32                     ),
                
                .INIT_CTL_CONTROL       (4'b0000                ),
                .INIT_IRQ_ENABLE        (1'b0                   ),
                .INIT_PARAM_ADDR        (0                      ),
                .INIT_PARAM_AWLEN_MAX   (8'd255                 ),
                .INIT_PARAM_H_SIZE      (14'(IMG_WIDTH-1)       ),
                .INIT_PARAM_V_SIZE      (14'(IMG_HEIGHT-1)      ),
                .INIT_PARAM_LINE_STEP   (16'd8192               ),
                .INIT_PARAM_F_SIZE      (14'd0                  ),
                .INIT_PARAM_FRAME_STEP  (32'(IMG_HEIGHT*8192)   ),
                .INIT_SKIP_EN           (1'b1                   ),
                .INIT_DETECT_FIRST      (3'b010                 ),
                .INIT_DETECT_LAST       (3'b001                 ),
                .INIT_PADDING_EN        (1'b1                   ),
                .INIT_PADDING_DATA      (10'd0                  ),
                
                .BYPASS_GATE            (0                      ),
                .BYPASS_ALIGN           (0                      ),
                .DETECTOR_ENABLE        (1                      ),
                .ALLOW_UNALIGNED        (1                      ),
                .CAPACITY_BITS          (32                     ),
                
                .WFIFO_PTR_BITS         (9                      ),
                .WFIFO_RAM_TYPE         ("block"                )
            )
        u_dma_video_write_img
            (
                .endian                 (1'b0                   ),

                .s_axi4s                (axi4s_fifo.s           ),
                .m_axi4                 (axi4_mem0.mw           ),

                .s_axi4l                (axi4l_dec[DEC_WDMA_IMG].s),
                .out_irq                (                       ),
                
                .buffer_request         (                       ),
                .buffer_release         (                       ),
                .buffer_addr            ('0                     )
            );

    // DMA write black
    jelly3_axi4s_if
            #(
                .DATA_BITS  (16                 ),
                .DEBUG      ("true"             )
            )
        axi4s_wdma_blk
            (
                .aresetn    (axi4s_cam_aresetn  ),
                .aclk       (axi4s_cam_aclk     ),
                .aclken     (1'b1               )
            );


    assign axi4s_wdma_blk.tuser  = axi4s_blk.tuser        ;
    assign axi4s_wdma_blk.tlast  = axi4s_blk.tlast        ;
    assign axi4s_wdma_blk.tdata  = 16'(axi4s_blk.tdata)   ;
    assign axi4s_wdma_blk.tstrb = '1;
    assign axi4s_wdma_blk.tvalid = axi4s_blk.tvalid       ;
    assign axi4s_blk.tready = axi4s_wdma_blk.tready;

    jelly3_dma_video_write
            #(
                .AXI4L_ASYNC            (1                      ),
                .AXI4S_ASYNC            (1                      ),
                .ADDR_BITS              (AXI4_MEM_ADDR_BITS     ),
                .INDEX_BITS             (1                      ),
                .SIZE_OFFSET            (1'b1                   ),
                .H_SIZE_BITS            (14                     ),
                .V_SIZE_BITS            (14                     ),
                .F_SIZE_BITS            (14                     ),
                .LINE_STEP_BITS         (16                     ),
                .FRAME_STEP_BITS        (32                     ),
                
                .INIT_CTL_CONTROL       (4'b0000                ),
                .INIT_IRQ_ENABLE        (1'b0                   ),
                .INIT_PARAM_ADDR        (0                      ),
                .INIT_PARAM_AWLEN_MAX   (8'd255                 ),
                .INIT_PARAM_H_SIZE      (14'(1280-1)            ),
                .INIT_PARAM_V_SIZE      (14'(1-1)               ),
                .INIT_PARAM_LINE_STEP   (16'd8192               ),
                .INIT_PARAM_F_SIZE      (14'd0                  ),
                .INIT_PARAM_FRAME_STEP  (32'(1*8192)            ),
                .INIT_SKIP_EN           (1'b1                   ),
                .INIT_DETECT_FIRST      (3'b010                 ),
                .INIT_DETECT_LAST       (3'b001                 ),
                .INIT_PADDING_EN        (1'b1                   ),
                .INIT_PADDING_DATA      (10'd0                  ),
                
                .BYPASS_GATE            (0                      ),
                .BYPASS_ALIGN           (0                      ),
                .DETECTOR_ENABLE        (1                      ),
                .ALLOW_UNALIGNED        (0                      ),
                .CAPACITY_BITS          (32                     ),
                
                .WFIFO_PTR_BITS         (8                      ),
                .WFIFO_RAM_TYPE         ("block"                )
            )
        u_dma_video_write_blk
            (
                .endian                 (1'b0                   ),

                .s_axi4s                (axi4s_wdma_blk.s       ),
                .m_axi4                 (axi4_mem1.mw           ),

                .s_axi4l                (axi4l_dec[DEC_WDMA_BLK].s),
                .out_irq                (                       ),
                
                .buffer_request         (                       ),
                .buffer_release         (                       ),
                .buffer_addr            ('0                     )
            );


    // read は未使用
    assign axi4_mem1.arid     = 0;
    assign axi4_mem1.araddr   = 0;
    assign axi4_mem1.arburst  = 0;
    assign axi4_mem1.arcache  = 0;
    assign axi4_mem1.arlen    = 0;
    assign axi4_mem1.arlock   = 0;
    assign axi4_mem1.arprot   = 0;
    assign axi4_mem1.arqos    = 0;
    assign axi4_mem1.arregion = 0;
    assign axi4_mem1.arsize   = 0;
    assign axi4_mem1.arvalid  = 0;
    assign axi4_mem1.rready   = 0;
    
        


    // ----------------------------------------
    //  HUB-75E
    // ----------------------------------------

    logic   hub75e_a;
    logic   hub75e_b;
    logic   hub75e_c;
    logic   hub75e_d;
    logic   hub75e_e;

    logic   hub75e_oe;
    logic   hub75e_lat;
    logic   hub75e_cke;

    logic   hub75e_r1;
    logic   hub75e_g1;
    logic   hub75e_b1;
    logic   hub75e_r2;
    logic   hub75e_g2;
    logic   hub75e_b2;

    assign pmod_d[0] = hub75e_g1    ;
    assign pmod_d[1] = 1'b0         ;
    assign pmod_d[2] = hub75e_g2    ;
    assign pmod_d[3] = hub75e_e     ;
    assign pmod_d[4] = hub75e_r1    ;
    assign pmod_d[5] = hub75e_b1    ;
    assign pmod_d[6] = hub75e_r2    ;
    assign pmod_d[7] = hub75e_b2    ;

    assign pmod_e[0] = hub75e_b     ;
    assign pmod_e[1] = hub75e_d     ;
    assign pmod_e[2] = hub75e_lat   ;
    assign pmod_e[3] = 1'b0         ;
    assign pmod_e[4] = hub75e_a     ;
    assign pmod_e[5] = hub75e_c     ;
    assign pmod_e[6] = hub75e_cke   ;
    assign pmod_e[7] = hub75e_oe    ;

    logic           hub75_st0_last      ;
    logic           hub75_st0_valid     ;
    logic           hub75_st0_mem_we    ;
    logic [9:0]     hub75_st0_mem_xaddr ;
    logic [8:0]     hub75_st0_mem_yaddr ;
    logic [7:0]     hub75_st0_mem_r     ;
    logic [7:0]     hub75_st0_mem_g     ;
    logic [7:0]     hub75_st0_mem_b     ;

    logic           hub75_st1_mem_we    ;
    logic [5:0]     hub75_st1_mem_xaddr ;
    logic [5:0]     hub75_st1_mem_yaddr ;
    logic [7:0]     hub75_st1_mem_r     ;
    logic [7:0]     hub75_st1_mem_g     ;
    logic [7:0]     hub75_st1_mem_b     ;

    always_ff @(posedge axi4s_dma.aclk) begin
        if ( ~axi4s_dma.aresetn ) begin
            hub75_st0_last      <= '0   ;
            hub75_st0_valid     <= '0   ;
            hub75_st0_mem_we    <= 1'b0 ;
            hub75_st0_mem_xaddr <= 'x   ;
            hub75_st0_mem_yaddr <= 'x   ;
            hub75_st0_mem_r     <= 'x   ;
            hub75_st0_mem_g     <= 'x   ;
            hub75_st0_mem_b     <= 'x   ;
            hub75_st1_mem_we    <= '0   ;
            hub75_st1_mem_xaddr <= 'x   ;
            hub75_st1_mem_yaddr <= 'x   ;
            hub75_st1_mem_r     <= 'x   ;
            hub75_st1_mem_g     <= 'x   ;
            hub75_st1_mem_b     <= 'x   ;
        end
        else if ( axi4s_dma.aclken ) begin
            // stage 0
            hub75_st0_last      <= axi4s_dma.tvalid && axi4s_dma.tready && axi4s_dma.tlast;
            hub75_st0_valid     <= axi4s_dma.tvalid && axi4s_dma.tready;
            hub75_st0_mem_we    <= axi4s_dma.tvalid && axi4s_dma.tready;
            hub75_st0_mem_r     <= axi4s_dma.tdata[7:0];
            hub75_st0_mem_g     <= axi4s_dma.tdata[7:0];
            hub75_st0_mem_b     <= axi4s_dma.tdata[7:0];
            if ( hub75_st0_valid ) begin
                hub75_st0_mem_xaddr <= hub75_st0_mem_xaddr + 1;
                if ( hub75_st0_last ) begin
                    hub75_st0_mem_xaddr <= '0;
                    hub75_st0_mem_yaddr <= hub75_st0_mem_yaddr + 1;
                end
            end
            if ( axi4s_dma.tvalid && axi4s_dma.tready && axi4s_dma.tuser[0] ) begin
                hub75_st0_mem_xaddr <= 0;
                hub75_st0_mem_yaddr <= 0;
            end
            case ( axi4s_dma.tdata[15:8] )
            8'd0: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd0,   8'd0,   8'd0  };  // 黒 (black)
            8'd1: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd42,  8'd42,  8'd165};  // 茶 (brown)
            8'd2: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd0,   8'd0,   8'd255};  // 赤 (red)
            8'd3: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd0,   8'd165, 8'd255};  // 橙 (orange)
            8'd4: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd0,   8'd255, 8'd255};  // 黄 (yellow)
            8'd5: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd0,   8'd255, 8'd0  };  // 緑 (green)
            8'd6: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd255, 8'd0,   8'd0  };  // 青 (blue)
            8'd7: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd128, 8'd0,   8'd128};  // 紫 (purple)
            8'd8: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd192, 8'd192, 8'd192};  // 灰 (gray)
            8'd9: {hub75_st0_mem_b, hub75_st0_mem_g, hub75_st0_mem_r} <= {8'd255, 8'd255, 8'd255};  // 白 (white)
            default: ;
            endcase

            // stage 1
            hub75_st1_mem_we    <= hub75_st0_valid
                                    && hub75_st0_mem_xaddr < 64
                                    && hub75_st0_mem_yaddr < 64;
            hub75_st1_mem_xaddr <= hub75_st0_mem_xaddr[5:0]  ;
            hub75_st1_mem_yaddr <= hub75_st0_mem_yaddr[5:0]  ;
            hub75_st1_mem_r     <= hub75_st0_mem_r      ;
            hub75_st1_mem_g     <= hub75_st0_mem_g      ;
            hub75_st1_mem_b     <= hub75_st0_mem_b      ;
        end
    end

    hub75_driver
            #(
                .CLK_DIV            (2          ),
                .N                  (2          ),
                .WIDTH              (64         ),
                .HEIGHT             (32         ),
                .DATA_BITS          (8          ),
                .DISP_BITS          (16         ),
                .RAM_TYPE           ("block"    ),
                .INIT_CTL_CONTROL   (1'b1       ),
                .INIT_RATE          (1          )
            )
        u_hub75_driver
            (
                .reset              (~axi4l_dec[DEC_HUB75].aresetn  ),
                .clk                (axi4l_dec[DEC_HUB75].aclk      ),
                .hub75_cke          (hub75e_cke                     ),
                .hub75_oe_n         (hub75e_oe                      ),
                .hub75_lat          (hub75e_lat                     ),
                .hub75_sel          ({
                                        hub75e_e,
                                        hub75e_d,
                                        hub75e_c,
                                        hub75e_b,
                                        hub75e_a
                                    }),
                .hub75_r            ({hub75e_r2, hub75e_r1}         ),
                .hub75_g            ({hub75e_g2, hub75e_g1}         ),
                .hub75_b            ({hub75e_b2, hub75e_b1}         ),

                .mem_clk            (axi4s_fmtr.aclk                ),
                .mem_we             (hub75_st1_mem_we               ),
                .mem_xaddr          (hub75_st1_mem_xaddr            ),
                .mem_yaddr          (hub75_st1_mem_yaddr            ),
                .mem_r              (hub75_st1_mem_r                ),
                .mem_g              (hub75_st1_mem_g                ),
                .mem_b              (hub75_st1_mem_b                ),

                .s_axi4l            (axi4l_dec[DEC_HUB75].s         )
        );

    
    // ----------------------------------------
    //  Debug
    // ----------------------------------------
    
    reg     [31:0]      reg_counter_rxbyteclkhs;
    always @(posedge rxbyteclkhs)   reg_counter_rxbyteclkhs <= reg_counter_rxbyteclkhs + 1;
    
    reg     [31:0]      reg_counter_clk200;
    always @(posedge sys_clk200)    reg_counter_clk200 <= reg_counter_clk200 + 1;
    
    reg     [31:0]      reg_counter_clk100;
    always @(posedge sys_clk100)    reg_counter_clk100 <= reg_counter_clk100 + 1;
    
    reg     [31:0]      reg_counter_peri_aclk;
    always @(posedge axi4l_peri_aclk)   reg_counter_peri_aclk <= reg_counter_peri_aclk + 1;
    
    reg     [31:0]      reg_counter_mem_aclk;
    always @(posedge axi4_mem_aclk) reg_counter_mem_aclk <= reg_counter_mem_aclk + 1;
   
    
    // frame monitor
    (* mark_debug = "true" *) logic   [31:0]  mon_frame_rate_count;
    (* mark_debug = "true" *) logic   [31:0]  mon_frame_rate_value;
    (* mark_debug = "true" *) logic   [31:0]  mon_frame_count;
    always_ff @(posedge axi4s_cam_aclk) begin
        mon_frame_rate_count <= mon_frame_rate_count + 1;
        if ( axi4s_img.tuser[0] && axi4s_img.tvalid ) begin
            mon_frame_rate_value <= mon_frame_rate_count;
            mon_frame_rate_count <= '0;
            mon_frame_count      <= mon_frame_count + 1;
        end
    end

    always_ff @(posedge axi4l_dec[DEC_SYS].aclk) begin
        reg_fps_count   <= mon_frame_rate_value;
        reg_frame_count <= mon_frame_count;
    end

    
    reg     frame_toggle = 0;
    always @(posedge axi4s_cam_aclk) begin
        if ( axi4s_img.tuser[0] && axi4s_img.tvalid && axi4s_img.tready ) begin
            frame_toggle <= ~frame_toggle;
        end
    end
    
    assign led[0] = reg_counter_rxbyteclkhs[24];
    assign led[1] = reg_counter_peri_aclk[24]; // reg_counter_clk200[24];
    assign led[2] = reg_counter_mem_aclk[24];  // reg_counter_clk100[24];
    assign led[3] = cam_gpio0;
    
    assign pmod_a[0]   = frame_toggle;
    assign pmod_a[1]   = reg_counter_rxbyteclkhs[5];
    assign pmod_a[2]   = reg_counter_clk200[5];
    assign pmod_a[3]   = reg_counter_clk100[5];
    assign pmod_a[7:4] = 0;
    
    
endmodule


`default_nettype wire

