
`default_nettype none

module rtcl_tp25k_usb3_blinking_led
        (
            input   var logic           in_clk50,     // 50MHz
            output  var logic   [3:0]   led
        );
    
    logic   reset = 0;

    logic   [26:0]  counter;
    always_ff @(posedge in_clk50) begin
        counter <= counter + 1;
    end
    assign led = ~counter[26:23];

endmodule


`default_nettype wire
