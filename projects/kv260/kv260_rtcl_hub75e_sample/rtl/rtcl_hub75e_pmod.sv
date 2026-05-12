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
            input   var logic           clk_x2          ,

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

    logic           phase_x1 = 0;
    always_ff @ ( posedge clk ) begin
        phase_x1 <= ~phase_x1;
    end

    logic   [1:0]   phase_x2   ;
    always_ff @ ( posedge clk_x2 ) begin
        phase_x2[0] <= phase_x1;
        phase_x2[1] <= phase_x2[0];
    end

    logic       reg_phase       ;
    logic       reg_toggle      ;
    logic       reg_hub75e_a    ;
    logic       reg_hub75e_b    ;
    logic       reg_hub75e_c    ;
    logic       reg_hub75e_d    ;
    logic       reg_hub75e_e    ;
    logic       reg_hub75e_oe   ;
    logic       reg_hub75e_lat  ;
    logic       reg_hub75e_cke  ;
    logic       reg_hub75e_r1   ;
    logic       reg_hub75e_g1   ;
    logic       reg_hub75e_b1   ;
    logic       reg_hub75e_r2   ;
    logic       reg_hub75e_g2   ;
    logic       reg_hub75e_b2   ;
    always_ff @ ( posedge clk_x2 ) begin
        if ( reset ) begin
            reg_phase      <= 0;
            reg_toggle     <= 0;
            reg_hub75e_a   <= 0;
            reg_hub75e_b   <= 0;
            reg_hub75e_c   <= 0;
            reg_hub75e_d   <= 0;
            reg_hub75e_e   <= 0;
            reg_hub75e_oe  <= 0;
            reg_hub75e_lat <= 0;
            reg_hub75e_cke <= 0;
            reg_hub75e_r1  <= 0;
            reg_hub75e_g1  <= 0;
            reg_hub75e_b1  <= 0;
            reg_hub75e_r2  <= 0;
            reg_hub75e_g2  <= 0;
            reg_hub75e_b2  <= 0;
        end
        else begin
            reg_phase <= phase_x2[0] == phase_x2[1];
            if ( reg_phase ) begin
                reg_toggle      <= ~reg_toggle;
                reg_hub75e_a    <= hub75e_a   ;
                reg_hub75e_b    <= hub75e_b   ;
                reg_hub75e_c    <= hub75e_c   ;
                reg_hub75e_d    <= hub75e_d   ;
                reg_hub75e_e    <= hub75e_e   ;
                reg_hub75e_oe   <= hub75e_oe  ;
                reg_hub75e_lat  <= hub75e_lat ;
                reg_hub75e_cke  <= hub75e_cke ;
                reg_hub75e_r1   <= hub75e_r1  ;
                reg_hub75e_g1   <= hub75e_g1  ;
                reg_hub75e_b1   <= hub75e_b1  ;
                reg_hub75e_r2   <= hub75e_r2  ;
                reg_hub75e_g2   <= hub75e_g2  ;
                reg_hub75e_b2   <= hub75e_b2  ;
            end

            if ( ~reg_phase ) begin
                pmod[0] <= hub75e_oe    ;
                pmod[1] <= hub75e_lat   ;
                pmod[2] <= hub75e_cke   ;
                pmod[3] <= hub75e_a     ;
                pmod[4] <= hub75e_b     ;
                pmod[5] <= hub75e_c     ;
                pmod[6] <= hub75e_d     ;
            end
            else begin
                pmod[0] <= hub75e_e     ;
                pmod[1] <= hub75e_r1    ;
                pmod[2] <= hub75e_g1    ;
                pmod[3] <= hub75e_b1    ;
                pmod[4] <= hub75e_r2    ;
                pmod[5] <= hub75e_g2    ;
                pmod[6] <= hub75e_b2    ;
            end
        end
    end

    ODDRE1
        u_oddr
            (
                .Q      (pmod[7]       ),
                .C      (clk_x2        ),
                .D1     (reg_phase     ),
                .D2     (~reg_phase    ),
                .SR     (reset         )
            );

    /*
    logic   [7:0]   pmod_p      ;
    logic   [7:0]   pmod_n      ;
    for ( genvar i = 0; i < 8; i++ ) begin : pmod_ddr
        ODDRE1
            u_oddr
                (
                    .Q      (pmod[i]       ),
                    .C      (clk_x2        ),
                    .D1     (pmod_p[i]     ),
                    .D2     (pmod_n[i]     ),
                    .SR     (reset         )
                );
    end
    */
    
endmodule


`default_nettype wire

