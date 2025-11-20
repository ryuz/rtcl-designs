// ---------------------------------------------------------------------------
//
//                                 Copyright (C) 2015-2020 by Ryuji Fuchikami 
//                                 https://github.com/ryuz/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module tb_sim();
    
    initial begin
        $dumpfile("tb_sim.vcd");
        $dumpvars(2, tb_sim);
        
    #10000000
        $finish;
    end
    
    
    parameter   X_NUM = 28*3;
    parameter   Y_NUM = 28*3;


    // ---------------------------------
    //  clock & reset
    // ---------------------------------

    localparam RATE100 = 1000.0/100.00;
    localparam RATE200 = 1000.0/200.00;
    localparam RATE250 = 1000.0/250.00;
    localparam RATE133 = 1000.0/133.33;

    reg			reset = 1;
    initial #100 reset = 0;

    reg			clk100 = 1'b1;
    always #(RATE100/2.0) clk100 <= ~clk100;

    reg			clk200 = 1'b1;
    always #(RATE200/2.0) clk200 <= ~clk200;

    reg			clk250 = 1'b1;
    always #(RATE250/2.0) clk250 <= ~clk250;

    
    // ---------------------------------
    //  main
    // ---------------------------------

    parameter   int     AXI4L_ADDR_BITS = 40                    ;
    parameter   int     AXI4L_DATA_BITS = 64                    ;
    localparam  int     AXI4L_STRB_BITS = AXI4L_DATA_BITS / 8   ;

    logic       axi4l_aresetn ;
    logic       axi4l_aclk    ;

    jelly3_axi4l_if
            #(
                .ADDR_BITS  (AXI4L_ADDR_BITS        ),
                .DATA_BITS  (AXI4L_DATA_BITS        )
            )
        axi4l
            (
                .aresetn    (axi4l_aresetn          ),
                .aclk       (axi4l_aclk             ),
                .aclken     (1'b1                   )
            );


    tb_main
            #(
                .X_NUM              (X_NUM          ),
                .Y_NUM              (Y_NUM          )
            )
        u_tb_main
            (
                .reset              ,
                .clk100             ,
                .clk200             ,
                .clk250             ,

                .s_axi4l_aresetn    (axi4l_aresetn  ),
                .s_axi4l_aclk       (axi4l_aclk     ),
                .s_axi4l_awaddr     (axi4l.awaddr   ),
                .s_axi4l_awprot     (axi4l.awprot   ),
                .s_axi4l_awvalid    (axi4l.awvalid  ),
                .s_axi4l_awready    (axi4l.awready  ),
                .s_axi4l_wstrb      (axi4l.wstrb    ),
                .s_axi4l_wdata      (axi4l.wdata    ),
                .s_axi4l_wvalid     (axi4l.wvalid   ),
                .s_axi4l_wready     (axi4l.wready   ),
                .s_axi4l_bresp      (axi4l.bresp    ),
                .s_axi4l_bvalid     (axi4l.bvalid   ),
                .s_axi4l_bready     (axi4l.bready   ),
                .s_axi4l_araddr     (axi4l.araddr   ),
                .s_axi4l_arprot     (axi4l.arprot   ),
                .s_axi4l_arvalid    (axi4l.arvalid  ),
                .s_axi4l_arready    (axi4l.arready  ),
                .s_axi4l_rdata      (axi4l.rdata    ),
                .s_axi4l_rresp      (axi4l.rresp    ),
                .s_axi4l_rvalid     (axi4l.rvalid   ),
                .s_axi4l_rready     (axi4l.rready   ),

                .img_x_num          (),
                .img_y_num          ()
            );
    
    
    // ----------------------------------
    //  AXI4-Lite master
    // ----------------------------------
    
    jelly3_axi4l_accessor
            #(
                .RAND_RATE_AW   (0          ),
                .RAND_RATE_W    (0          ),
                .RAND_RATE_B    (0          ),
                .RAND_RATE_AR   (0          ),
                .RAND_RATE_R    (0          )
            )
        u_axi4l_accessor
            (
                .m_axi4l        (axi4l.m    )
            );
    
    localparam ADR_SYS      = 40'ha000_0000;
    localparam ADR_TGEN     = 40'ha001_0000;
    localparam ADR_FMTR     = 40'ha010_0000;
    localparam ADR_WDMA_IMG = 40'ha021_0000;
    localparam ADR_WDMA_BLK = 40'ha022_0000;
    localparam ADR_TBLMOD   = 40'ha030_0000;
    localparam ADR_LPF      = 40'ha032_0000;


`include "jelly/JellyRegs.vh"
    
    initial begin
        logic [AXI4L_DATA_BITS-1:0]  rdata;

        #1000;
        u_axi4l_accessor.read_reg(ADR_SYS,  0, rdata);
        u_axi4l_accessor.read_reg(ADR_TGEN, 0, rdata);

        // write test
        u_axi4l_accessor.write_reg(ADR_FMTR, `REG_VIDEO_FMTREG_PARAM_WIDTH,  X_NUM, 8'hff);
        u_axi4l_accessor.write_reg(ADR_FMTR, `REG_VIDEO_FMTREG_PARAM_HEIGHT, Y_NUM, 8'hff);
        u_axi4l_accessor.write_reg(ADR_FMTR, `REG_VIDEO_FMTREG_CTL_CONTROL,      3, 8'hff);

    end


endmodule


`default_nettype wire


// end of file
