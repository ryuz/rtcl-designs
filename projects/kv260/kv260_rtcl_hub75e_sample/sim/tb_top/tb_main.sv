
`timescale 1ns / 1ps
`default_nettype none


module tb_main
        (
            input   var logic           reset                   ,
            input   var logic           clk50                   ,
            input   var logic           clk100                  ,
            input   var logic           clk200                  ,
            
            output  var logic           s_axi4l_aresetn         ,
            output  var logic           s_axi4l_aclk            ,
            input   var logic   [39:0]  s_axi4l_awaddr          ,
            input   var logic   [2:0]   s_axi4l_awprot          ,
            input   var logic           s_axi4l_awvalid         ,
            output  var logic           s_axi4l_awready         ,
            input   var logic   [63:0]  s_axi4l_wdata           ,
            input   var logic   [7:0]   s_axi4l_wstrb           ,
            input   var logic           s_axi4l_wvalid          ,
            output  var logic           s_axi4l_wready          ,
            output  var logic   [1:0]   s_axi4l_bresp           ,
            output  var logic           s_axi4l_bvalid          ,
            input   var logic           s_axi4l_bready          ,
            input   var logic   [39:0]  s_axi4l_araddr          ,
            input   var logic   [2:0]   s_axi4l_arprot          ,
            input   var logic           s_axi4l_arvalid         ,
            output  var logic           s_axi4l_arready         ,
            output  var logic   [63:0]  s_axi4l_rdata           ,
            output  var logic   [1:0]   s_axi4l_rresp           ,
            output  var logic           s_axi4l_rvalid          ,
            input   var logic           s_axi4l_rready          ,

            output  var logic           s_axi4_aresetn          ,
            output  var logic           s_axi4_aclk             ,
            input   var logic   [15:0]  s_axi4_awid             ,
            input   var logic   [19:0]  s_axi4_awaddr           ,
            input   var logic   [7:0]   s_axi4_awlen            ,
            input   var logic   [2:0]   s_axi4_awsize           ,
            input   var logic   [1:0]   s_axi4_awburst          ,
            input   var logic   [0:0]   s_axi4_awlock           ,
            input   var logic   [3:0]   s_axi4_awcache          ,
            input   var logic   [2:0]   s_axi4_awprot           ,
            input   var logic   [3:0]   s_axi4_awqos            ,
            input   var logic   [3:0]   s_axi4_awregion         ,
            input   var logic           s_axi4_awvalid          ,
            output  var logic           s_axi4_awready          ,
            input   var logic   [31:0]  s_axi4_wdata            ,
            input   var logic   [2:0]   s_axi4_wstrb            ,
            input   var logic           s_axi4_wlast            ,
            input   var logic           s_axi4_wvalid           ,
            output  var logic           s_axi4_wready           ,
            output  var logic   [15:0]  s_axi4_bid              ,
            output  var logic   [1:0]   s_axi4_bresp            ,
            output  var logic           s_axi4_bvalid           ,
            input   var logic           s_axi4_bready           ,
            input   var logic   [15:0]  s_axi4_arid             ,
            input   var logic   [39:0]  s_axi4_araddr           ,
            input   var logic   [7:0]   s_axi4_arlen            ,
            input   var logic   [2:0]   s_axi4_arsize           ,
            input   var logic   [1:0]   s_axi4_arburst          ,
            input   var logic   [0:0]   s_axi4_arlock           ,
            input   var logic   [3:0]   s_axi4_arcache          ,
            input   var logic   [2:0]   s_axi4_arprot           ,
            input   var logic   [3:0]   s_axi4_arqos            ,
            input   var logic   [3:0]   s_axi4_arregion         ,
            input   var logic           s_axi4_arvalid          ,
            output  var logic           s_axi4_arready          ,
            output  var logic   [15:0]  s_axi4_rid              ,
            output  var logic   [31:0]  s_axi4_rdata            ,
            output  var logic   [1:0]   s_axi4_rresp            ,
            output  var logic           s_axi4_rlast            ,
            output  var logic           s_axi4_rvalid           ,
            input   var logic           s_axi4_rready
        );
    

    // -----------------------------
    //  DUT
    // -----------------------------

    parameter   int     HUB75E_CLK_DIV      = 2                                         ;
    parameter   int     HUB75E_DISP_BITS    = 16                                        ;
    parameter   int     HUB75E_N            = 2                                         ;
    parameter   int     HUB75E_WIDTH        = 64                                        ;
    parameter   int     HUB75E_HEIGHT       = 32                                        ;
    parameter   int     HUB75E_SEL_BITS     = $clog2(HUB75E_HEIGHT)                     ;
    parameter   int     HUB75E_DATA_BITS    = 10                                        ;
    parameter   int     HUB75E_SLOTS        = $bits(HUB75E_DATA_BITS)                   ;
    parameter   int     HUB75E_DEPTH        = HUB75E_N * HUB75E_HEIGHT * HUB75E_WIDTH   ;
    parameter   int     HUB75E_ADDR_BITS    = $clog2(HUB75E_DEPTH)                      ;
    parameter           HUB75E_RAM_TYPE     = "block"                                   ;
    parameter   bit     HUB75E_READMEMH     = 1'b1                                      ;
    parameter           HUB75E_READMEM_FILE = "../../../syn/image.hex"                  ;

    logic   [7:0]       pmod  ;

    kv260_rtcl_hub75e_sample
            #(
                .HUB75E_CLK_DIV         (HUB75E_CLK_DIV         ),
                .HUB75E_DISP_BITS       (HUB75E_DISP_BITS       ),
                .HUB75E_N               (HUB75E_N               ),
                .HUB75E_WIDTH           (HUB75E_WIDTH           ),
                .HUB75E_HEIGHT          (HUB75E_HEIGHT          ),
                .HUB75E_SEL_BITS        (HUB75E_SEL_BITS        ),
                .HUB75E_DATA_BITS       (HUB75E_DATA_BITS       ),
                .HUB75E_SLOTS           (HUB75E_SLOTS           ),
                .HUB75E_DEPTH           (HUB75E_DEPTH           ),
                .HUB75E_ADDR_BITS       (HUB75E_ADDR_BITS       ),
                .HUB75E_RAM_TYPE        (HUB75E_RAM_TYPE        ),
                .HUB75E_READMEMH        (HUB75E_READMEMH        ),
                .HUB75E_READMEM_FILE    (HUB75E_READMEM_FILE    )
            )
        u_top
            (
                .fan_en                 (                       ),
                .pmod                   (pmod                   )
            );
    
    logic   [7:0]   pmod_p;
    logic   [7:0]   pmod_n;
    always_ff @(posedge pmod[7]) begin
        pmod_p <= pmod;
    end
    always_ff @(negedge pmod[7]) begin
        pmod_n <= pmod;
    end

    logic hub75e_oe     ;
    logic hub75e_lat    ;
    logic hub75e_cke    ;
    logic hub75e_a      ;
    logic hub75e_b      ;
    logic hub75e_c      ;
    logic hub75e_d      ;
    logic hub75e_e      ;
    logic hub75e_r1     ;
    logic hub75e_g1     ;
    logic hub75e_b1     ;
    logic hub75e_r2     ;
    logic hub75e_g2     ;
    logic hub75e_b2     ;
    always_ff @(posedge pmod[7]) begin
        hub75e_oe  <= pmod_p[0];
        hub75e_lat <= pmod_p[1];
        hub75e_cke <= pmod_p[2];
        hub75e_a   <= pmod_p[3];
        hub75e_b   <= pmod_p[4];
        hub75e_c   <= pmod_p[5];
        hub75e_d   <= pmod_p[6];
        hub75e_e   <= pmod_n[0];
        hub75e_r1  <= pmod_n[1];
        hub75e_g1  <= pmod_n[2];
        hub75e_b1  <= pmod_n[3];
        hub75e_r2  <= pmod_n[4];
        hub75e_g2  <= pmod_n[5];
        hub75e_b2  <= pmod_n[6];
    end


    // -----------------------------
    //  Clock & Reset
    // -----------------------------
    
    always_comb force u_top.u_design_1.out_reset  = reset;
    always_comb force u_top.u_design_1.out_clk50  = clk50;
    always_comb force u_top.u_design_1.out_clk100 = clk100;
    always_comb force u_top.u_design_1.out_clk200 = clk200;
    always_comb force u_top.u_design_1.m_axi4l_aresetn = ~reset;
    always_comb force u_top.u_design_1.m_axi4l_aclk    = clk200;
    always_comb force u_top.u_design_1.m_axi4_aresetn = ~reset;
    always_comb force u_top.u_design_1.m_axi4_aclk    = clk200;


    // -----------------------------
    //  Peripheral Bus
    // -----------------------------

    assign s_axi4l_aresetn = u_top.u_design_1.m_axi4l_aresetn ;
    assign s_axi4l_aclk    = u_top.u_design_1.m_axi4l_aclk    ;
    assign s_axi4l_awready = u_top.u_design_1.m_axi4l_awready ;
    assign s_axi4l_wready  = u_top.u_design_1.m_axi4l_wready  ;
    assign s_axi4l_bresp   = u_top.u_design_1.m_axi4l_bresp   ;
    assign s_axi4l_bvalid  = u_top.u_design_1.m_axi4l_bvalid  ;
    assign s_axi4l_arready = u_top.u_design_1.m_axi4l_arready ;
    assign s_axi4l_rdata   = u_top.u_design_1.m_axi4l_rdata   ;
    assign s_axi4l_rresp   = u_top.u_design_1.m_axi4l_rresp   ;
    assign s_axi4l_rvalid  = u_top.u_design_1.m_axi4l_rvalid  ;

    always_comb force u_top.u_design_1.m_axi4l_awaddr  = s_axi4l_awaddr ;
    always_comb force u_top.u_design_1.m_axi4l_awprot  = s_axi4l_awprot ;
    always_comb force u_top.u_design_1.m_axi4l_awvalid = s_axi4l_awvalid;
    always_comb force u_top.u_design_1.m_axi4l_wdata   = s_axi4l_wdata  ;
    always_comb force u_top.u_design_1.m_axi4l_wstrb   = s_axi4l_wstrb  ;
    always_comb force u_top.u_design_1.m_axi4l_wvalid  = s_axi4l_wvalid ;
    always_comb force u_top.u_design_1.m_axi4l_bready  = s_axi4l_bready ;
    always_comb force u_top.u_design_1.m_axi4l_araddr  = s_axi4l_araddr ;
    always_comb force u_top.u_design_1.m_axi4l_arprot  = s_axi4l_arprot ;
    always_comb force u_top.u_design_1.m_axi4l_arvalid = s_axi4l_arvalid;
    always_comb force u_top.u_design_1.m_axi4l_rready  = s_axi4l_rready ;


    // -----------------------------
    //  VRAM Bus
    // -----------------------------

    assign s_axi4_aresetn  = u_top.u_design_1.m_axi4_aresetn    ;
    assign s_axi4_aclk     = u_top.u_design_1.m_axi4_aclk       ;
    assign s_axi4_awready  = u_top.u_design_1.m_axi4_awready    ;
    assign s_axi4_wready   = u_top.u_design_1.m_axi4_wready     ;
    assign s_axi4_bid      = u_top.u_design_1.m_axi4_bid        ;
    assign s_axi4_bresp    = u_top.u_design_1.m_axi4_bresp      ;
    assign s_axi4_bvalid   = u_top.u_design_1.m_axi4_bvalid     ;
    assign s_axi4_arready  = u_top.u_design_1.m_axi4_arready    ;
    assign s_axi4_rid      = u_top.u_design_1.m_axi4_rid        ;
    assign s_axi4_rdata    = u_top.u_design_1.m_axi4_rdata      ;
    assign s_axi4_rresp    = u_top.u_design_1.m_axi4_rresp      ;
    assign s_axi4_rlast    = u_top.u_design_1.m_axi4_rlast      ;
    assign s_axi4_rvalid   = u_top.u_design_1.m_axi4_rvalid     ;

    always_comb force u_top.u_design_1.m_axi4_awid     = s_axi4_awid     ;
    always_comb force u_top.u_design_1.m_axi4_awaddr   = s_axi4_awaddr   ;
    always_comb force u_top.u_design_1.m_axi4_awlen    = s_axi4_awlen    ;
    always_comb force u_top.u_design_1.m_axi4_awsize   = s_axi4_awsize   ;
    always_comb force u_top.u_design_1.m_axi4_awburst  = s_axi4_awburst  ;
    always_comb force u_top.u_design_1.m_axi4_awlock   = s_axi4_awlock   ;
    always_comb force u_top.u_design_1.m_axi4_awcache  = s_axi4_awcache  ;
    always_comb force u_top.u_design_1.m_axi4_awprot   = s_axi4_awprot   ;
    always_comb force u_top.u_design_1.m_axi4_awqos    = s_axi4_awqos    ;
//  always_comb force u_top.u_design_1.m_axi4_awregion = s_axi4_awregion ;
    always_comb force u_top.u_design_1.m_axi4_awvalid  = s_axi4_awvalid  ;
    always_comb force u_top.u_design_1.m_axi4_wdata    = s_axi4_wdata    ;
    always_comb force u_top.u_design_1.m_axi4_wstrb    = s_axi4_wstrb    ;
    always_comb force u_top.u_design_1.m_axi4_wlast    = s_axi4_wlast    ;
    always_comb force u_top.u_design_1.m_axi4_wvalid   = s_axi4_wvalid   ;
    always_comb force u_top.u_design_1.m_axi4_bready   = s_axi4_bready   ;
    always_comb force u_top.u_design_1.m_axi4_arid     = s_axi4_arid     ;
    always_comb force u_top.u_design_1.m_axi4_araddr   = s_axi4_araddr   ;
    always_comb force u_top.u_design_1.m_axi4_arlen    = s_axi4_arlen    ;
    always_comb force u_top.u_design_1.m_axi4_arsize   = s_axi4_arsize   ;
    always_comb force u_top.u_design_1.m_axi4_arburst  = s_axi4_arburst  ;
    always_comb force u_top.u_design_1.m_axi4_arlock   = s_axi4_arlock   ;
    always_comb force u_top.u_design_1.m_axi4_arcache  = s_axi4_arcache  ;
    always_comb force u_top.u_design_1.m_axi4_arprot   = s_axi4_arprot   ;
    always_comb force u_top.u_design_1.m_axi4_arqos    = s_axi4_arqos    ;
//  always_comb force u_top.u_design_1.m_axi4_arregion = s_axi4_arregion ;
    always_comb force u_top.u_design_1.m_axi4_arvalid  = s_axi4_arvalid  ;
    always_comb force u_top.u_design_1.m_axi4_rready   = s_axi4_rready   ;

endmodule


`default_nettype wire


// end of file
