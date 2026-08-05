
`default_nettype none

module rtcl_tp25k_usb3_blinking_led
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup_n  ,
            input   var logic           ft601_clk       ,

            input   var logic   [1:0]   push_sw         ,
            input   var logic   [1:0]   dip_sw          ,
            output  var logic   [3:0]   led             ,
            output  var logic   [7:0]   pmod            

        );
    
    assign ft601_reset_n  = 1'b1;
    assign ft601_wakeup_n = 1'bz;

    logic   [24:0]  clk_counter;
    always_ff @(posedge in_clk50) begin
        clk_counter <= clk_counter + 1;
    end

    logic   [24:0]  usb_counter;
    always_ff @(posedge ft601_clk) begin
        usb_counter <= usb_counter + 1;
    end

    assign led[1:0] = clk_counter[24:23];
    assign led[3:2] = usb_counter[24:23];

    assign pmod[3:0] = clk_counter[5:2];
    assign pmod[7:4] = usb_counter[5:2];

endmodule


`default_nettype wire
