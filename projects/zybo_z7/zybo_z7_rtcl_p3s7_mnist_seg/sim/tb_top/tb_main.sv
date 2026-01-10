
`timescale 1ns / 1ps
`default_nettype none


module tb_main
        (
            input   var logic           reset                   ,
            input   var logic           clk100                  ,
            input   var logic           clk200                  ,
            input   var logic           clk250                  ,
            
            output  var logic           s_axi4l_peri_aresetn    ,
            output  var logic           s_axi4l_peri_aclk       ,
            input   var logic   [31:0]  s_axi4l_peri_awaddr     ,
            input   var logic   [2:0]   s_axi4l_peri_awprot     ,
            input   var logic           s_axi4l_peri_awvalid    ,
            output  var logic           s_axi4l_peri_awready    ,
            input   var logic   [31:0]  s_axi4l_peri_wdata      ,
            input   var logic   [3:0]   s_axi4l_peri_wstrb      ,
            input   var logic           s_axi4l_peri_wvalid     ,
            output  var logic           s_axi4l_peri_wready     ,
            output  var logic   [1:0]   s_axi4l_peri_bresp      ,
            output  var logic           s_axi4l_peri_bvalid     ,
            input   var logic           s_axi4l_peri_bready     ,
            input   var logic   [31:0]  s_axi4l_peri_araddr     ,
            input   var logic   [2:0]   s_axi4l_peri_arprot     ,
            input   var logic           s_axi4l_peri_arvalid    ,
            output  var logic           s_axi4l_peri_arready    ,
            output  var logic   [31:0]  s_axi4l_peri_rdata      ,
            output  var logic   [1:0]   s_axi4l_peri_rresp      ,
            output  var logic           s_axi4l_peri_rvalid     ,
            input   var logic           s_axi4l_peri_rready     ,

            output  var logic   [31:0]  img_width               ,
            output  var logic   [31:0]  img_height              
        );
    

    // -----------------------------
    //  target
    // -----------------------------

    parameter   int     WIDTH_BITS  = 16    ;
    parameter   int     HEIGHT_BITS = 16    ;
    parameter   int     IMG_WIDTH   = 640   ;
    parameter   int     IMG_HEIGHT  = 64    ;

//  assign img_width  = IMG_WIDTH   ;
//  assign img_height = IMG_HEIGHT  ;

    zybo_z7_rtcl_p3s7_mnist_seg
            #(
                .WIDTH_BITS         (WIDTH_BITS     ),
                .HEIGHT_BITS        (HEIGHT_BITS    ),
                .IMG_WIDTH          (IMG_WIDTH      ),
                .IMG_HEIGHT         (IMG_HEIGHT     )
            )
        u_top
            (
                .in_clk125          (),
                .push_sw            (),
                .dip_sw             (),
                .led                (),
                .pmod_a             (),
                .pmod_b             (),
                .pmod_c             (),
                .pmod_d             (),
                .pmod_e             (),
                
                .cam_clk_hs_p       (),
                .cam_clk_hs_n       (),
                .cam_clk_lp_p       (),
                .cam_clk_lp_n       (),
                .cam_data_hs_p      (),
                .cam_data_hs_n      (),
                .cam_data_lp_p      (),
                .cam_data_lp_n      (),
                .cam_gpio0          (),
                .cam_gpio1          (),
                .cam_scl            (),
                .cam_sda            (),

                .DDR_addr           (),
                .DDR_ba             (),
                .DDR_cas_n          (),
                .DDR_ck_n           (),
                .DDR_ck_p           (),
                .DDR_cke            (),
                .DDR_cs_n           (),
                .DDR_dm             (),
                .DDR_dq             (),
                .DDR_dqs_n          (),
                .DDR_dqs_p          (),
                .DDR_odt            (),
                .DDR_ras_n          (),
                .DDR_reset_n        (),
                .DDR_we_n           (),
                .FIXED_IO_ddr_vrn   (),
                .FIXED_IO_ddr_vrp   (),
                .FIXED_IO_mio       (),
                .FIXED_IO_ps_clk    (),
                .FIXED_IO_ps_porb   (),
                .FIXED_IO_ps_srstb  ()
            );
    

    // -----------------------------
    //  Clock & Reset
    // -----------------------------
    
    always_comb force u_top.u_design_1.reset  = reset;
    always_comb force u_top.u_design_1.clk100 = clk100;
    always_comb force u_top.u_design_1.clk200 = clk200;
    always_comb force u_top.u_design_1.clk250 = clk250;


    // -----------------------------
    //  Peripheral Bus
    // -----------------------------
    
    assign s_axi4l_peri_aresetn = u_top.u_design_1.axi4l_peri_aresetn ;
    assign s_axi4l_peri_aclk    = u_top.u_design_1.axi4l_peri_aclk    ;

    assign s_axi4l_peri_awready = u_top.u_design_1.axi4l_peri_awready ;
    assign s_axi4l_peri_wready  = u_top.u_design_1.axi4l_peri_wready  ;
    assign s_axi4l_peri_bresp   = u_top.u_design_1.axi4l_peri_bresp   ;
    assign s_axi4l_peri_bvalid  = u_top.u_design_1.axi4l_peri_bvalid  ;
    assign s_axi4l_peri_arready = u_top.u_design_1.axi4l_peri_arready ;
    assign s_axi4l_peri_rdata   = u_top.u_design_1.axi4l_peri_rdata   ;
    assign s_axi4l_peri_rresp   = u_top.u_design_1.axi4l_peri_rresp   ;
    assign s_axi4l_peri_rvalid  = u_top.u_design_1.axi4l_peri_rvalid  ;

    always_comb force u_top.u_design_1.axi4l_peri_awaddr  = s_axi4l_peri_awaddr ;
    always_comb force u_top.u_design_1.axi4l_peri_awprot  = s_axi4l_peri_awprot ;
    always_comb force u_top.u_design_1.axi4l_peri_awvalid = s_axi4l_peri_awvalid;
    always_comb force u_top.u_design_1.axi4l_peri_wdata   = s_axi4l_peri_wdata  ;
    always_comb force u_top.u_design_1.axi4l_peri_wstrb   = s_axi4l_peri_wstrb  ;
    always_comb force u_top.u_design_1.axi4l_peri_wvalid  = s_axi4l_peri_wvalid ;
    always_comb force u_top.u_design_1.axi4l_peri_bready  = s_axi4l_peri_bready ;
    always_comb force u_top.u_design_1.axi4l_peri_araddr  = s_axi4l_peri_araddr ;
    always_comb force u_top.u_design_1.axi4l_peri_arprot  = s_axi4l_peri_arprot ;
    always_comb force u_top.u_design_1.axi4l_peri_arvalid = s_axi4l_peri_arvalid;
    always_comb force u_top.u_design_1.axi4l_peri_rready  = s_axi4l_peri_rready ;
    


    // -----------------------------
    //  Video input
    // -----------------------------

    logic   axi4s_src_aresetn;
    logic   axi4s_src_aclk;

    jelly3_axi4s_if
            #(
                .USER_BITS      (1),
                .DATA_BITS      (10)
            )
        axi4s_src
            (
                .aresetn        (axi4s_src_aresetn  ),
                .aclk           (axi4s_src_aclk     ),
                .aclken         (1'b1               )
            );

    assign axi4s_src_aresetn = u_top.axi4s_img.aresetn;
    assign axi4s_src_aclk    = u_top.axi4s_img.aclk;
    
    always_comb force u_top.axi4s_img.tuser  = axi4s_src.tuser ;
    always_comb force u_top.axi4s_img.tlast  = axi4s_src.tlast ;
    always_comb force u_top.axi4s_img.tdata  = axi4s_src.tdata ;
    always_comb force u_top.axi4s_img.tvalid = axi4s_src.tvalid;
    assign axi4s_src.tready = u_top.axi4s_img.tready;


    localparam DATA_WIDTH      = 10;
    localparam FILE_NAME       = "";
    localparam FILE_EXT        = "";
    localparam SEQUENTIAL_FILE = 1;
    localparam FILE_IMG_WIDTH  = 320;
    localparam FILE_IMG_HEIGHT = 320;
    localparam SIM_IMG_WIDTH   = 128;//320;
    localparam SIM_IMG_HEIGHT  = 128;//320;
    assign img_width  = SIM_IMG_WIDTH;
    assign img_height = SIM_IMG_HEIGHT;

    // master
    logic  [31:0]  out_x;
    logic  [31:0]  out_y;
    logic  [31:0]  out_f;
    jelly3_model_axi4s_m
            #(
                .COMPONENTS         (1              ),
                .DATA_BITS          (DATA_WIDTH     ),
                .IMG_WIDTH          (SIM_IMG_WIDTH  ),
                .IMG_HEIGHT         (SIM_IMG_HEIGHT ),
                .H_BLANK            (64             ),
                .V_BLANK            (32             ),
                .FILE_NAME          (FILE_NAME      ),
                .FILE_EXT           (FILE_EXT       ),
                .FILE_IMG_WIDTH     (FILE_IMG_WIDTH ),
                .FILE_IMG_HEIGHT    (FILE_IMG_HEIGHT),
                .SEQUENTIAL_FILE    (SEQUENTIAL_FILE),
                .BUSY_RATE          (10             ),
                .RANDOM_SEED        (0              )
            )
        u_model_axi4s_m
            (
                .enable             (1'b1           ),
                .busy               (               ),

                .m_axi4s            (axi4s_src.m    ),
                .out_x              (out_x          ),
                .out_y              (out_y          ),
                .out_f              (out_f          )
            );
    

    /*
    // -----------------------------
    //  RTCL-P3S7
    // -----------------------------

    tb_rtcl_p3s7_hs
        u_rtcl_p3s7_hs
            ();

    logic               rxreseths   ;
    logic               rxbyteclkhs ;
    logic   [1:0][7:0]  rxdatahs    ;
    logic   [1:0]       rxvalidhs   ;
    logic   [1:0]       rxactivehs  ;
    logic   [1:0]       rxsynchs    ;

    assign rxreseths   = u_rtcl_p3s7_hs.rxreseths  ;
    assign rxbyteclkhs = u_rtcl_p3s7_hs.rxbyteclkhs;
    assign rxdatahs    = u_rtcl_p3s7_hs.rxdatahs   ;
    assign rxvalidhs   = u_rtcl_p3s7_hs.rxvalidhs  ;
    assign rxactivehs  = u_rtcl_p3s7_hs.rxactivehs ;
    assign rxsynchs    = u_rtcl_p3s7_hs.rxsynchs   ;

    initial begin
        force u_top.system_rst_out = rxreseths;
        force u_top.rxbyteclkhs    = rxbyteclkhs;
        force u_top.dl0_rxdatahs   = rxdatahs[0];
        force u_top.dl1_rxdatahs   = rxdatahs[1];
        force u_top.dl0_rxactivehs = rxactivehs[0];
        force u_top.dl1_rxactivehs = rxactivehs[1];
        force u_top.dl0_rxsynchs   = rxsynchs[0];
        force u_top.dl1_rxsynchs   = rxsynchs[1];
        force u_top.dl0_rxvalidhs  = rxactivehs[0] & ~rxsynchs[0];
        force u_top.dl1_rxvalidhs  = rxactivehs[1] & ~rxsynchs[1];
    end
    */

endmodule


`default_nettype wire


// end of file
