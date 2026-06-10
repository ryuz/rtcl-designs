

`timescale 1ns / 1ps
`default_nettype none

module IOBUF
        (
            input   var logic   I       ,
            output  var logic   O       ,
            input   var logic   OEN     ,
            inout   tri logic   IO      
        );

    assign IO = OEN ? 1'bz : I;
    assign O  = IO;

endmodule

`default_nettype wire
