
`default_nettype none

module rtcl_tp25k_usb3_blinking_led
        (
            input   var logic           in_clk50        ,

            output  var logic   [3:0]   led             ,

            output  var logic   [7:0]   pmod            ,
            output  var logic           ft601_reset_n   ,
            output  var logic           ft601_wakeup    
        );
    
    logic   reset = 0;

    logic   [26:0]  counter;
    always_ff @(posedge in_clk50) begin
        counter <= counter + 1;
    end
    assign led = ~counter[26:23];

    assign pmod = counter[9:2];

    assign ft601_reset_n = 1'b1;
    assign ft601_wakeup  = 1'b1;

endmodule


`default_nettype wire
