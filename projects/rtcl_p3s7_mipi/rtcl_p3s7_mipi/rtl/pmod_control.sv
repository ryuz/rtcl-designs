// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module pmod_control
        #(
        )
        (
            input   var logic           reset       ,
            input   var logic           clk         ,

            inout   tri logic   [7:0]   pmod        ,

            input   var logic   [15:0]  mode        ,
            output  var logic   [7:0]   gpio_in     ,
            input   var logic   [7:0]   gpio_out    ,
            input   var logic   [7:0]   gpio_dir    ,
            input   var logic           trigger     ,
            input   var logic   [7:0]   test0       
        );
    
    // I/O
    logic   [7:0]   pmod_i     ;
    logic   [7:0]   pmod_o     ;
    logic   [7:0]   pmod_t     ;
    for ( genvar i = 0; i < 8; i++ ) begin
        IOBUF
            u_iobuf_pmod
                (
                    .I      (pmod_o[i]  ),
                    .O      (pmod_i[i]  ),
                    .T      (pmod_t[i]  ),
                    .IO     (pmod  [i]  )
                );
    end

    // trriger sync
    (* async_reg = "true" *)    logic ff0_trigger, ff1_trigger, ff2_trigger, ff3_trigger;
    always_ff @(posedge clk) begin
        ff0_trigger <= trigger;
        ff1_trigger <= ff0_trigger;
        ff2_trigger <= ff1_trigger;
        ff3_trigger <= ff2_trigger;
    end

    // light rotation
    logic   [7:0]   light_pattern;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            light_pattern <= 8'h00;
        end
        else if ( {ff2_trigger, ff1_trigger} == 2'b01 ) begin
            if ( light_pattern == 0 ) begin
                light_pattern <= 8'h01;
            end
            else begin
                light_pattern <= {light_pattern[6:0], light_pattern[7]};
            end
        end
    end

    // output
    always_ff @(posedge clk) begin
        pmod_o <= '0;
        pmod_t <= '1;
        case ( mode )
        16'h0000:   // GPIO mode
            begin
                pmod_o <= gpio_out   ;
                pmod_t <= ~gpio_dir  ;
            end

        16'h0010:   // light_pattern
            begin
                pmod_o <= ff3_trigger ? light_pattern : '0;
                pmod_t <= 8'h00;
            end

        16'hff00:
            begin
                pmod_o <= test0;
                pmod_t <= 8'h00;
            end
        endcase
    end

    assign gpio_in = pmod_i;
    
endmodule

`default_nettype wire

// end of file
