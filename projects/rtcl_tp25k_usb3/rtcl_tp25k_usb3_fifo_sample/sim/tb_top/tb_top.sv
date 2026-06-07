`timescale 1ns / 1ps
`default_nettype none


module tb_top();

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        #1000000;
            $finish;
    end

    localparam CLK_RATE   = 1000.0/50.0;
    localparam FT601_RATE = 1000.0/100.0;


    logic   reset = 1'b1;
    initial #(CLK_RATE*100) reset = 1'b0;

    logic   clk = 1'b1;
    initial forever #(CLK_RATE/2.0)  clk = ~clk;

    logic   ft601_clk = 1'b1;
    initial forever #(CLK_RATE/2.0)  ft601_clk = ~ft601_clk;


    tb_main
        u_tb_main
            (
                .reset      (reset    ),
                .clk        (clk      ),
                .ft601_clk  (ft601_clk)
            );

endmodule


`default_nettype wire


// end of file
