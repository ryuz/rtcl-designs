
`default_nettype none

module rtcl_tp25k_usb3_fifo_sample
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup_n  ,
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

            input   var logic   [1:0]   push_sw         ,
            input   var logic   [1:0]   dip_sw          ,
            output  var logic   [3:0]   led             ,
            output  var logic   [7:0]   pmod            
        );
    
    logic   reset = push_sw[0];

    logic   [24:0]  clk_counter;
    always_ff @(posedge in_clk50) begin
        clk_counter <= clk_counter + 1;
    end

    logic   [26:0]  usb_counter;
    always_ff @(posedge ft601_clk) begin
        usb_counter <= usb_counter + 1;
    end

    assign led[0] = clk_counter[24];
    assign led[1] = usb_counter[26];

//  assign pmod = counter[9:2];

    assign ft601_reset_n  = 1'b1; //~reset;
    assign ft601_wakeup_n = 1'bz  ;

    assign ft601_siwu_n = 1'b1   ;
    assign ft601_wr_n   = 1'b1   ;
    assign ft601_rd_n   = 1'b1   ;
    assign ft601_oe_n   = 1'b1   ;
    assign ft601_be     = 'z     ;
    assign ft601_data   = 'z     ;
    assign ft601_gpio   = 'z     ;

    assign pmod[0] = ft601_rxf_n    ;
    assign pmod[1] = ft601_txe_n    ;
    assign pmod[2] = ft601_wakeup_n ;
    assign pmod[7:3] = usb_counter[8:4];

endmodule


`default_nettype wire
