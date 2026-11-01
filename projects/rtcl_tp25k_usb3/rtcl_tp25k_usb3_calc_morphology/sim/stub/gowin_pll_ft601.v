module gowin_pll_ft601(
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
assign clkout0 = clkin;

endmodule
