// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module pmod_control
        (
            input   var logic               reset       ,
            input   var logic               clk         ,

            inout   tri logic   [7:0]       pmod        ,
            output  var logic   [7:0]       pkt_hdr     ,

            input   var logic   [0:0]       trigger     ,
            input   var logic   [1:0]       monitor     ,
            input   var logic   [7:0]       test0       ,

            input   var logic   [15:0]      mode        ,
            output  var logic   [7:0]       gpio_in     ,
            input   var logic   [7:0]       gpio_out    ,
            input   var logic   [7:0]       gpio_dir    ,

            input   var logic   [1:0]       trg_sel     ,
            input   var logic   [1:0]       hdr_sel     ,
            input   var logic   [3:0]       ptn_len     ,
            input   var logic   [15:0][7:0] ptn_tbl     
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
    logic   [0:0]   sync_trigger    ;
    logic   [1:0]   sync_monitor    ;
    logic   [7:0]   sync_test0      ;
    logic   [7:0]   sync_pmod       ;
    jelly3_async_latch
            #(
                .WIDTH      (  $bits(trigger)
                             + $bits(monitor)
                             + $bits(test0  )   
                             + $bits(pmod   )   
                             ),
                .SYNC_FF    (3                  )
            )
        u_async_latch
            (
                .clk        (clk                ),
                .in_data    ({
                                trigger ,
                                monitor ,
                                test0   ,
                                pmod_i  
                            }),
                .out_data   ({
                                sync_trigger,
                                sync_monitor,
                                sync_test0  ,
                                sync_pmod   
                            })
            );

    // trigger select
    logic   [1:0]   ff_trigger;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            ff_trigger <= '0;
        end
        else begin
            case ( trg_sel )
            2'b00:  ff_trigger[0] <= sync_trigger;
            2'b01:  ff_trigger[0] <= sync_trigger;
            2'b10:  ff_trigger[0] <= sync_monitor[0];
            2'b01:  ff_trigger[0] <= sync_monitor[1];
            endcase
        end
        ff_trigger[0] <= ff_trigger[1];
    end

    // light rotation
    logic   [3:0]   pattern_idx     ;
    logic   [7:0]   light_pattern   ;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            light_pattern <= 8'h00;
        end
        else begin
            if ( ff_trigger == 2'b01 ) begin
                pattern_idx <= pattern_idx + 1;
                if ( pattern_idx >= ptn_len ) begin
                    light_pattern <= 8'h00;
                end
            end
            light_pattern <= ptn_tbl[pattern_idx];
        end
    end

    // pmod output
    always_ff @(posedge clk) begin
        if ( reset ) begin
            pmod_o <= '0;
            pmod_t <= '1;
        end
        else begin
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
                    pmod_o <= sync_trigger ? light_pattern : '0;
                    pmod_t <= 8'h00;
                end

            16'hff00:
                begin
                    pmod_o <= test0;
                    pmod_t <= 8'h00;
                end
            endcase
        end
    end

    logic   [7:0]   hdr_pmod  ;
    always_ff @(posedge clk) begin
        if ( reset ) begin
            hdr_pmod  <= '0;
        end
        else begin
            // 露光終了時のPMODの状態をキャプチャ
            if ( ff_trigger == 2'b10 ) begin
                hdr_pmod <= sync_pmod;
            end
        end
    end

    // packet header output
    always_ff @(posedge clk) begin
        if ( reset ) begin
            pkt_hdr <= '0;
        end
        else begin
            case ( hdr_sel )
            2'd0:       pkt_hdr <= sync_pmod        ;
            2'd1:       pkt_hdr <= hdr_pmod         ;
            2'd2:       pkt_hdr <= light_pattern    ;
            2'd3:       pkt_hdr <= 8'(pattern_idx)  ;
            default:    pkt_hdr <= '0               ;
            endcase
        end
    end

    // gpio
    assign gpio_in = pmod_i;
    
endmodule


`default_nettype wire


// end of file
