
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
    logic   [0:0]   axi4_aresetn   ;
    logic           axi4_aclk      ;

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

    jelly3_axi4_if
            #(
                .ID_BITS    (16                     ),
                .ADDR_BITS  (40                     ),
                .DATA_BITS  (32                     ),
                .USE_REGION (0                      )
            )
        axi4
            (
                .aresetn    (axi4_aresetn           ),
                .aclk       (axi4_aclk              ),
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
                .s_axi4l_rready         (axi4l.rready       ),

                .s_axi4_aresetn         (axi4_aresetn       ),
                .s_axi4_aclk            (axi4_aclk          ),
                .s_axi4_awid            (axi4.awid          ),
                .s_axi4_awaddr          (axi4.awaddr        ),
                .s_axi4_awlen           (axi4.awlen         ),
                .s_axi4_awsize          (axi4.awsize        ),
                .s_axi4_awburst         (axi4.awburst       ),
                .s_axi4_awlock          (axi4.awlock        ),
                .s_axi4_awcache         (axi4.awcache       ),
                .s_axi4_awprot          (axi4.awprot        ),
                .s_axi4_awqos           (axi4.awqos         ),
                .s_axi4_awregion        (axi4.awregion      ),
                .s_axi4_awvalid         (axi4.awvalid       ),
                .s_axi4_awready         (axi4.awready       ),
                .s_axi4_wdata           (axi4.wdata         ),
                .s_axi4_wstrb           (axi4.wstrb         ),
                .s_axi4_wlast           (axi4.wlast         ),
                .s_axi4_wvalid          (axi4.wvalid        ),
                .s_axi4_wready          (axi4.wready        ),
                .s_axi4_bid             (axi4.bid           ),
                .s_axi4_bresp           (axi4.bresp         ),
                .s_axi4_bvalid          (axi4.bvalid        ),
                .s_axi4_bready          (axi4.bready        ),
                .s_axi4_arid            (axi4.arid          ),
                .s_axi4_araddr          (axi4.araddr        ),
                .s_axi4_arlen           (axi4.arlen         ),
                .s_axi4_arsize          (axi4.arsize        ),
                .s_axi4_arburst         (axi4.arburst       ),
                .s_axi4_arlock          (axi4.arlock        ),
                .s_axi4_arcache         (axi4.arcache       ),
                .s_axi4_arprot          (axi4.arprot        ),
                .s_axi4_arqos           (axi4.arqos         ),
                .s_axi4_arregion        (axi4.arregion      ),
                .s_axi4_arvalid         (axi4.arvalid       ),
                .s_axi4_arready         (axi4.arready       ),
                .s_axi4_rid             (axi4.rid           ),
                .s_axi4_rdata           (axi4.rdata         ),
                .s_axi4_rresp           (axi4.rresp         ),
                .s_axi4_rlast           (axi4.rlast         ),
                .s_axi4_rvalid          (axi4.rvalid        ),
                .s_axi4_rready          (axi4.rready        )
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

    jelly3_axi4_accessor
            #(
                .RAND_RATE_AW   (0),
                .RAND_RATE_W    (0),
                .RAND_RATE_B    (0),
                .RAND_RATE_AR   (0),
                .RAND_RATE_R    (0)
            )
        u_axi4
            (
                .m_axi4         (axi4.m)
            );


    initial begin
        logic [63:0]    rdata;
        
        #(RATE100*200);
        $display("start");
        u_axi4l.read_reg(0, 0, rdata);
        u_axi4l.read_reg(0, 7, rdata);

        u_axi4.write(
                .id      (16'h18d),
                .addr    (32'h100),
                .size    (3'd2),
                .burst   (2'd1),
                .lock    (1'd0),
                .cache   (4'd0),
                .prot    (3'd0),
                .qos     (4'd0),
                .region  ('0),
                .user    (16'h8c),
                .data    ({32'h12345678, 32'h9abcdef0}),
                .strb    ({4'hf, 4'h3})
              );

        u_axi4.write_reg(0, 16, 2);
        u_axi4.write_reg(0, 24, 3);
        u_axi4.write_reg(0, 32, 4);
        u_axi4.write_reg(0, 16, 2);
        
        #2000000
        $finish();
    end

endmodule


`default_nettype wire


// end of file
