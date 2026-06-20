`timescale 1ns / 1ps
`default_nettype none


module tb_top();

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        #1000000;
            $finish;
    end

    localparam CLK50_RATE  = 1000.0/50.0;
    localparam CLK100_RATE = 1000.0/100.0;
    localparam FT601_RATE  = 1000.0/100.0;


    logic   reset = 1'b1;
    initial #(CLK50_RATE*100) reset = 1'b0;

    logic   clk50 = 1'b1;
    initial forever #(CLK50_RATE/2.0)   clk50 = ~clk50;

    logic   clk100 = 1'b1;
    initial forever #(CLK100_RATE/2.0)  clk100 = ~clk100;

    logic   ft601_clk = 1'b1;
    initial forever #(FT601_RATE/2.0)   ft601_clk = ~ft601_clk;


    tb_main
        u_tb_main
            (
                .reset      (reset      ),
                .clk50      (clk50      ),
                .clk100     (clk100     ),
                .ft601_clk  (ft601_clk  )
            );

endmodule


`default_nettype wire


// end of file
