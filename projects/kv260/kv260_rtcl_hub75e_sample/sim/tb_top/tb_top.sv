
`timescale 1ns / 1ps
`default_nettype none


module tb_top();
    
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    
    #10000000
        $finish;
    end
    

    // -----------------------------
    //  reset & clock
    // -----------------------------

    localparam RATE50  = 1000.0/50.00 ;
    localparam RATE100 = 1000.0/100.00;
    localparam RATE200 = 1000.0/200.00;

    logic       reset = 1;
    initial #100 reset = 0;

    logic       clk50 = 1'b1;
    initial forever #(RATE50/2.0) clk50 = ~clk50;

    logic       clk100 = 1'b1;
    initial forever #(RATE100/2.0) clk100 = ~clk100;

    logic       clk200 = 1'b1;
    initial forever #(RATE200/2.0) clk200 = ~clk200;



    // -----------------------------
    //  target
    // -----------------------------

    logic   [0:0]   axi4l_aresetn  ;
    logic           axi4l_aclk     ;

    jelly3_axi4l_if
            #(
                .ADDR_BITS  (40                     ),
                .DATA_BITS  (64                     )
            )
        axi4l
            (
                .aresetn    (axi4l_aresetn          ),
                .aclk       (axi4l_aclk             ),
                .aclken     (1'b1                   )
            );

    tb_main
        u_tb_main
            (
                .reset                  (reset              ),
                .clk50                  (clk50              ),
                .clk100                 (clk100             ),
                .clk200                 (clk200             ),
                
                .s_axi4l_aresetn        (axi4l_aresetn      ),
                .s_axi4l_aclk           (axi4l_aclk         ),
                .s_axi4l_awaddr         (axi4l.awaddr       ),
                .s_axi4l_awprot         (axi4l.awprot       ),
                .s_axi4l_awvalid        (axi4l.awvalid      ),
                .s_axi4l_awready        (axi4l.awready      ),
                .s_axi4l_wdata          (axi4l.wdata        ),
                .s_axi4l_wstrb          (axi4l.wstrb        ),
                .s_axi4l_wvalid         (axi4l.wvalid       ),
                .s_axi4l_wready         (axi4l.wready       ),
                .s_axi4l_bresp          (axi4l.bresp        ),
                .s_axi4l_bvalid         (axi4l.bvalid       ),
                .s_axi4l_bready         (axi4l.bready       ),
                .s_axi4l_araddr         (axi4l.araddr       ),
                .s_axi4l_arprot         (axi4l.arprot       ),
                .s_axi4l_arvalid        (axi4l.arvalid      ),
                .s_axi4l_arready        (axi4l.arready      ),
                .s_axi4l_rdata          (axi4l.rdata        ),
                .s_axi4l_rresp          (axi4l.rresp        ),
                .s_axi4l_rvalid         (axi4l.rvalid       ),
                .s_axi4l_rready         (axi4l.rready       )
            );



    // -----------------------------
    //  access
    // -----------------------------

    jelly3_axi4l_accessor
            #(
                .RAND_RATE_AW   (0),
                .RAND_RATE_W    (0),
                .RAND_RATE_B    (0),
                .RAND_RATE_AR   (0),
                .RAND_RATE_R    (0)
            )
        u_axi4l
            (
                .m_axi4l        (axi4l.m)
            );


    initial begin
        logic [63:0]    rdata;
        
        #(RATE100*200);
        $display("start");
        u_axi4l.read_reg(0, 0, rdata);
        u_axi4l.read_reg(0, 7, rdata);
        
        #2000000
        $finish();
    end

endmodule


`default_nettype wire


// end of file
