
`default_nettype none

module rtcl_tp25k_usb3_fifo_sample
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup    ,
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

            output  var logic   [7:0]   pmod            ,
            output  var logic   [3:0]   led             
        );
    
    logic   reset = 0;

    logic   [26:0]  counter;
    always_ff @(posedge in_clk50) begin
        counter <= counter + 1;
    end
    assign led[1:0] = ~counter[24:23];

    logic   [26:0]  counter_usb;
    always_ff @(posedge ft601_clk) begin
        counter_usb <= counter_usb + 1;
    end
    assign led[3:2] = ~counter_usb[24:23];


    assign pmod = counter[9:2];

    assign ft601_reset_n = 1'b1;
    assign ft601_wakeup  = 1'bz;

    assign ft601_siwu_n = 1'b1   ;
    assign ft601_wr_n   = 1'b1   ;
    assign ft601_rd_n   = 1'b1   ;
    assign ft601_oe_n   = 1'b1   ;
    assign ft601_be     = 'z     ;
    assign ft601_data   = 'z     ;
    assign ft601_gpio   = 'z     ;

endmodule


`default_nettype wire
