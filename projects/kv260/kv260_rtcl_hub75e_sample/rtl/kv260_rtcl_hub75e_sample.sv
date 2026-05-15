// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module kv260_rtcl_hub75e_sample
        #(
            parameter   int     HUB75E_CLK_DIV      = 2                                         ,
            parameter   int     HUB75E_DISP_BITS    = 16                                        ,
            parameter   int     HUB75E_N            = 2                                         ,
            parameter   int     HUB75E_WIDTH        = 64                                        ,
            parameter   int     HUB75E_HEIGHT       = 32                                        ,
            parameter   int     HUB75E_SEL_BITS     = $clog2(HUB75E_HEIGHT)                     ,
            parameter   int     HUB75E_DATA_BITS    = 10                                        ,
            parameter   int     HUB75E_SLOTS        = $bits(HUB75E_DATA_BITS)                   ,
            parameter   int     HUB75E_DEPTH        = HUB75E_N * HUB75E_HEIGHT * HUB75E_WIDTH   ,
            parameter   int     HUB75E_ADDR_BITS    = $clog2(HUB75E_DEPTH)                      ,
            parameter           HUB75E_RAM_TYPE     = "block"                                   ,
            parameter   bit     HUB75E_READMEMH     = 0                                         ,
            parameter           HUB75E_READMEM_FILE = "../../../image.hex"                      ,
            parameter           DEVICE              = "ULTRASCALE_PLUS"                         ,
            parameter           SIMULATION          = "false"                                   ,
            parameter           DEBUG               = "false"                                   
        )
        (
            output  var logic           fan_en      ,
            output  var logic   [7:0]   pmod        
        );
    

    // ----------------------------------------
    //  Zynq UltraScale+ MPSoC block
    // ----------------------------------------

    localparam  int     AXI4L_ADDR_BITS = 40;
    localparam  int     AXI4L_DATA_BITS = 64;
    localparam  int     AXI4_ID_BITS    = 16;
    localparam  int     AXI4_ADDR_BITS  = 40;
    localparam  int     AXI4_DATA_BITS  = 32;

    logic           axi4l_aresetn   ;
    logic           axi4l_aclk      ;
    logic           axi4_aresetn    ;
    logic           axi4_aclk       ;

    jelly3_axi4l_if
            #(
                .ADDR_BITS  (AXI4L_ADDR_BITS),
                .DATA_BITS  (AXI4L_DATA_BITS)
            )
        axi4l
            (
                .aresetn    (axi4l_aresetn  ),
                .aclk       (axi4l_aclk     ),
                .aclken     (1'b1           )
            );

    jelly3_axi4_if
            #(
                .ID_BITS    (AXI4_ID_BITS   ),
                .ADDR_BITS  (AXI4_ADDR_BITS ),
                .DATA_BITS  (AXI4_DATA_BITS ),
                .USE_REGION (0              )
            )
        axi4
            (
                .aresetn    (axi4_aresetn   ),
                .aclk       (axi4_aclk      ),
                .aclken     (1'b1           )
            );


    logic       sys_reset           ;
    logic       sys_clk100          ;
    logic       sys_clk50           ;
    logic       sys_clk50_90        ;

    design_1
        u_design_1
            (
                .fan_en                 (fan_en         ),
                
                .out_reset              (sys_reset      ),
                .out_clk100             (sys_clk100     ),
                .out_clk50              (sys_clk50      ),
                .out_clk50_90           (sys_clk50_90   ),

                .m_axi4l_aresetn        (axi4l_aresetn  ),
                .m_axi4l_aclk           (axi4l_aclk     ),
                .m_axi4l_awaddr         (axi4l.awaddr   ),
                .m_axi4l_awprot         (axi4l.awprot   ),
                .m_axi4l_awvalid        (axi4l.awvalid  ),
                .m_axi4l_awready        (axi4l.awready  ),
                .m_axi4l_wstrb          (axi4l.wstrb    ),
                .m_axi4l_wdata          (axi4l.wdata    ),
                .m_axi4l_wvalid         (axi4l.wvalid   ),
                .m_axi4l_wready         (axi4l.wready   ),
                .m_axi4l_bresp          (axi4l.bresp    ),
                .m_axi4l_bvalid         (axi4l.bvalid   ),
                .m_axi4l_bready         (axi4l.bready   ),
                .m_axi4l_araddr         (axi4l.araddr   ),
                .m_axi4l_arprot         (axi4l.arprot   ),
                .m_axi4l_arvalid        (axi4l.arvalid  ),
                .m_axi4l_arready        (axi4l.arready  ),
                .m_axi4l_rdata          (axi4l.rdata    ),
                .m_axi4l_rresp          (axi4l.rresp    ),
                .m_axi4l_rvalid         (axi4l.rvalid   ),
                .m_axi4l_rready         (axi4l.rready   ),
                
                .m_axi4_aresetn         (axi4_aresetn   ),
                .m_axi4_aclk            (axi4_aclk      ),
                .m_axi4_awid            (axi4.awid      ),
                .m_axi4_awuser          (               ),
                .m_axi4_awaddr          (axi4.awaddr    ),
                .m_axi4_awburst         (axi4.awburst   ),
                .m_axi4_awcache         (axi4.awcache   ),
                .m_axi4_awlen           (axi4.awlen     ),
                .m_axi4_awlock          (axi4.awlock    ),
                .m_axi4_awprot          (axi4.awprot    ),
                .m_axi4_awqos           (axi4.awqos     ),
    //          .m_axi4_awregion        (axi4.awregion  ),
                .m_axi4_awsize          (axi4.awsize    ),
                .m_axi4_awvalid         (axi4.awvalid   ),
                .m_axi4_awready         (axi4.awready   ),
                .m_axi4_wstrb           (axi4.wstrb     ),
                .m_axi4_wdata           (axi4.wdata     ),
                .m_axi4_wlast           (axi4.wlast     ),
                .m_axi4_wvalid          (axi4.wvalid    ),
                .m_axi4_wready          (axi4.wready    ),
                .m_axi4_bid             (axi4.bid       ),
                .m_axi4_bresp           (axi4.bresp     ),
                .m_axi4_bvalid          (axi4.bvalid    ),
                .m_axi4_bready          (axi4.bready    ),
                .m_axi4_aruser          (               ),
                .m_axi4_araddr          (axi4.araddr    ),
                .m_axi4_arburst         (axi4.arburst   ),
                .m_axi4_arcache         (axi4.arcache   ),
                .m_axi4_arid            (axi4.arid      ),
                .m_axi4_arlen           (axi4.arlen     ),
                .m_axi4_arlock          (axi4.arlock    ),
                .m_axi4_arprot          (axi4.arprot    ),
                .m_axi4_arqos           (axi4.arqos     ),
    //          .m_axi4_arregion        (axi4.arregion  ),
                .m_axi4_arsize          (axi4.arsize    ),
                .m_axi4_arvalid         (axi4.arvalid   ),
                .m_axi4_arready         (axi4.arready   ),
                .m_axi4_rid             (axi4.rid       ),
                .m_axi4_rresp           (axi4.rresp     ),
                .m_axi4_rdata           (axi4.rdata     ),
                .m_axi4_rlast           (axi4.rlast     ),
                .m_axi4_rvalid          (axi4.rvalid    ),
                .m_axi4_rready          (axi4.rready    )
            );
    
    // -----------------------------
    //  HUB-75E
    // -----------------------------

    logic   hub75e_reset    ;
    logic   hub75e_clk      ;
    logic   hub75e_clk_90   ;
    assign hub75e_reset  = sys_reset    ;
    assign hub75e_clk    = sys_clk50    ;
    assign hub75e_clk_90 = sys_clk50_90 ;

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

    logic                           mem_we     ;
    logic   [11:0]                  mem_addr   ;
    logic   [HUB75E_DATA_BITS-1:0]  mem_r      ;
    logic   [HUB75E_DATA_BITS-1:0]  mem_g      ;
    logic   [HUB75E_DATA_BITS-1:0]  mem_b      ;

    hub75_driver
            #(
                .CLK_DIV        (HUB75E_CLK_DIV         ),
                .DISP_BITS      (HUB75E_DISP_BITS       ),
                .N              (HUB75E_N               ),
                .WIDTH          (HUB75E_WIDTH           ),
                .HEIGHT         (HUB75E_HEIGHT          ),
                .SEL_BITS       (HUB75E_SEL_BITS        ),
                .DATA_BITS      (HUB75E_DATA_BITS       ),
                .RAM_TYPE       (HUB75E_RAM_TYPE        ),
                .READMEMH       (HUB75E_READMEMH        ),
                .READMEM_FILE   (HUB75E_READMEM_FILE    )
            )
        u_hub75_driver
            (
                .reset          (hub75e_reset           ),
                .clk            (hub75e_clk             ),

                .hub75_cke      (hub75e_cke             ),
                .hub75_oe_n     (hub75e_oe              ),
                .hub75_lat      (hub75e_lat             ),
                .hub75_sel      ({
                                    hub75e_e,
                                    hub75e_d,
                                    hub75e_c,
                                    hub75e_b,
                                    hub75e_a
                                }),
                .hub75_r        ({hub75e_r2, hub75e_r1} ),
                .hub75_g        ({hub75e_g2, hub75e_g1} ),
                .hub75_b        ({hub75e_b2, hub75e_b1} ),

                .s_axi4l        (axi4l                  ),

                .mem_clk        (axi4.aclk              ),
                .mem_we         (mem_we                 ),
                .mem_addr       (mem_addr               ),
                .mem_r          (mem_r                  ),
                .mem_g          (mem_g                  ),
                .mem_b          (mem_b                  )
            );

    jelly3_bram_if
            #(
                .ID_BITS    (AXI4_ID_BITS       ),
                .ADDR_BITS  (AXI4_ADDR_BITS-2   ) ,
                .DATA_BITS  (AXI4_DATA_BITS     )
            )
        bram
            (
                .reset      (~axi4.aresetn      ),
                .clk        (axi4.aclk          ),
                .cke        (axi4.aclken        )
            );
    
    jelly3_axi4_to_bram
        u_axi4_to_bram
            (
                .s_axi4     (axi4           ),
                .m_bram     (bram           )
            );

    jelly3_bram_accessor
            #(
                .WLATENCY   (1              ),
                .RLATENCY   (1              ),
                .ADDR_BITS  (12             ),
                .DATA_BITS  (30             ),
                .BYTE_BITS  (30             )
            )
        u_bram_accessor
            (
                .s_bram     (bram           ),

                .en         (               ),
                .we         (mem_we         ),
                .addr       (mem_addr       ),
                .wdata      ({
                                mem_r,
                                mem_g,
                                mem_b
                            }),
                .rdata      ('0             )
            );


    // ------------------------------
    //  RTCL-HUB75E-PMOD board
    // ------------------------------

    rtcl_hub75e_pmod
            #(
                .DEVICE     (DEVICE         ),
                .SIMULATION (SIMULATION     ),
                .DEBUG      (DEBUG          )
            )
        u_rtcl_hub75e_pmod
            (
                .reset          (hub75e_reset   ),
                .clk            (hub75e_clk     ),
                .clk_90         (hub75e_clk_90  ),

                .hub75e_a       (hub75e_a       ),
                .hub75e_b       (hub75e_b       ),
                .hub75e_c       (hub75e_c       ),
                .hub75e_d       (hub75e_d       ),
                .hub75e_e       (hub75e_e       ),
                .hub75e_oe      (hub75e_oe      ),
                .hub75e_lat     (hub75e_lat     ),
                .hub75e_cke     (hub75e_cke     ),
                .hub75e_r1      (hub75e_r1      ),
                .hub75e_g1      (hub75e_g1      ),
                .hub75e_b1      (hub75e_b1      ),
                .hub75e_r2      (hub75e_r2      ),
                .hub75e_g2      (hub75e_g2      ),
                .hub75e_b2      (hub75e_b2      ),

                .pmod           (pmod           )
            );
    
    
endmodule


`default_nettype wire

