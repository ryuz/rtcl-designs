module Gowin_PLL(
    clkin,
    clkout0,
    lock,
    mdclk,
    reset
);

input clkin;
output clkout0;
output lock;
input mdclk;
input reset;

assign lock = ~reset;

endmodule
