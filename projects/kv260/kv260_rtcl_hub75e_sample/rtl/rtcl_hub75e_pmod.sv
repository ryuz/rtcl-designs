// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module rtcl_hub75e_pmod
        #(
            parameter DEVICE     = "ULTRASCALE_PLUS"    ,
            parameter SIMULATION = "false"              ,
            parameter DEBUG      = "false"              
        )
        (
            input   var logic           reset           ,
            input   var logic           clk             ,
            input   var logic           clk_90          ,

            input   var logic           hub75e_a        ,
            input   var logic           hub75e_b        ,
            input   var logic           hub75e_c        ,
            input   var logic           hub75e_d        ,
            input   var logic           hub75e_e        ,
            input   var logic           hub75e_oe       ,
            input   var logic           hub75e_lat      ,
            input   var logic           hub75e_cke      ,
            input   var logic           hub75e_r1       ,
            input   var logic           hub75e_g1       ,
            input   var logic           hub75e_b1       ,
            input   var logic           hub75e_r2       ,
            input   var logic           hub75e_g2       ,
            input   var logic           hub75e_b2       ,

            output  var logic   [7:0]   pmod            
        );

    logic   [6:0]   pmod_p;
    logic   [6:0]   pmod_n;

    assign  pmod_p[0] = hub75e_oe    ;
    assign  pmod_p[1] = hub75e_lat   ;
    assign  pmod_p[2] = hub75e_cke   ;
    assign  pmod_p[3] = hub75e_a     ;
    assign  pmod_p[4] = hub75e_b     ;
    assign  pmod_p[5] = hub75e_c     ;
    assign  pmod_p[6] = hub75e_d     ;
    assign  pmod_n[0] = hub75e_e     ;
    assign  pmod_n[1] = hub75e_r1    ;
    assign  pmod_n[2] = hub75e_g1    ;
    assign  pmod_n[3] = hub75e_b1    ;
    assign  pmod_n[4] = hub75e_r2    ;
    assign  pmod_n[5] = hub75e_g2    ;
    assign  pmod_n[6] = hub75e_b2    ;

    for ( genvar i = 0; i < 7; i++ ) begin
        ODDRE1
            u_oddr_data
                (
                    .Q      (pmod[i]    ),
                    .C      (clk        ),
                    .D1     (pmod_p[i]  ),
                    .D2     (pmod_n[i]  ),
                    .SR     (reset      )
                );
    end

    ODDRE1
        u_oddr_clk
            (
                .Q      (pmod[7]    ),
                .C      (clk_90     ),
                .D1     (1'b1       ),
                .D2     (1'b0       ),
                .SR     (1'b0       )
            );
    
endmodule


`default_nettype wire

