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
            parameter   int     TIME_DIV       = 72                       ,
            parameter   int     PMOD_BITS      = 8                        ,
            parameter   type    pmod_t         = logic [PMOD_BITS-1:0]    ,
            parameter   int     MODE_BITS      = 16                       ,
            parameter   type    mode_t         = logic [MODE_BITS-1:0]    ,
            parameter   int     SLOTS          = 16                       ,
            parameter   int     SLOT_BITS      = $clog2(SLOTS)            ,
            parameter   type    slot_t         = logic [SLOT_BITS-1:0]    ,
            parameter   int     TIMER_BITS     = 16                       ,
            parameter   type    timer_t        = logic [TIMER_BITS-1:0]   ,
            parameter   int     TRG_SEL_BITS   = 2                        ,
            parameter   type    trg_sel_t      = logic [TRG_SEL_BITS-1:0] ,
            parameter   int     HDR_SEL_BITS   = 3                        ,
            parameter   type    hdr_sel_t      = logic [HDR_SEL_BITS-1:0] 
        )
        (
            input   var logic               reset       ,
            input   var logic               clk         ,

            inout   tri pmod_t              pmod        ,
            output  var pmod_t              pkt_hdr     ,

            input   var logic   [0:0]       trigger     ,
            input   var logic   [1:0]       monitor     ,
            input   var pmod_t              test0       ,

            input   var mode_t              mode        ,
            output  var pmod_t              gpio_in     ,
            input   var pmod_t              gpio_out    ,
            input   var pmod_t              gpio_dir    ,

            input   var trg_sel_t           trg_sel     ,
            input   var hdr_sel_t           hdr_sel     ,
            input   var slot_t              slot_len    ,
            input   var pmod_t  [SLOTS-1:0] slot_ptn    ,
            input   var timer_t [SLOTS-1:0] slot_tim    
        );

    localparam  int     DIV_BITS = $clog2(TIME_DIV)     ;
    localparam  type    div_t    = logic [DIV_BITS-1:0] ;

    // I/O
    pmod_t  pmod_i ;
    pmod_t  pmod_o ;
    pmod_t  pmod_z ;
    for ( genvar i = 0; i < $bits(pmod_t); i++ ) begin
        IOBUF
            u_iobuf_pmod
                (
                    .I      (pmod_o[i]  ),
                    .O      (pmod_i[i]  ),
                    .T      (pmod_z[i]  ),
                    .IO     (pmod  [i]  )
                );
    end

    // trigger sync
    logic   [0:0]   sync_trigger    ;
    logic   [1:0]   sync_monitor    ;
    pmod_t          sync_test0      ;
    pmod_t          sync_pmod       ;
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
    logic   [2:0]   ff_trigger;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            ff_trigger <= '0;
        end
        else begin
            case ( trg_sel )
            2'b00:  ff_trigger[0] <= sync_monitor[0];
            2'b01:  ff_trigger[0] <= sync_monitor[1];
            2'b10:  ff_trigger[0] <= sync_trigger;
            2'b11:  ff_trigger[0] <= sync_trigger;
            endcase
        end
        ff_trigger[1] <= ff_trigger[0];
        ff_trigger[2] <= ff_trigger[1];
    end

    // light control time slot
    div_t       tim_divider     ;
    timer_t     tim_counter     ;
    slot_t      slot_idx        ;
    pmod_t      pmod_ptn        ;
    timer_t     pmod_tim        ;
    always_ff @( posedge clk ) begin
        if ( reset ) begin
            tim_divider <= '0   ;
            tim_counter <= '0   ;
            slot_idx    <= '0   ;
            pmod_ptn    <= '0   ;
            pmod_tim    <= '0   ;
        end
        else begin
            // timer count-up
            tim_divider <= tim_divider + 1'b1;
            if ( tim_divider >= div_t'(TIME_DIV - 1) ) begin
                tim_divider <= '0;
                tim_counter <= tim_counter + 1'b1;
            end

            // trigger
            if ( ff_trigger[1:0] == 2'b01 ) begin
                tim_divider <= '0;
                tim_counter <= '0;
                slot_idx <= slot_idx + 1;
                if ( slot_idx >= slot_len ) begin
                    slot_idx <= 0;
                end
            end

            pmod_ptn <= slot_ptn[slot_idx];
            pmod_tim <= slot_tim[slot_idx];
        end
    end

    // pmod output
    always_ff @(posedge clk) begin
        if ( reset ) begin
            pmod_z <= '1;
            pmod_o <= '0;
        end
        else begin
            pmod_z <= '1;
            pmod_o <= '0;
            case ( mode )
            16'h0000:   // GPIO mode
                begin
                    pmod_z <= ~gpio_dir  ;
                    pmod_o <= gpio_out   ;
                end

            16'h0010:   // light_pattern
                begin
                    pmod_z <= 8'h00 ;
                    pmod_o <= '0    ;
                    if ( &ff_trigger && tim_counter < pmod_tim ) begin
                        pmod_o <= pmod_ptn;
                    end
                end

            16'hff00:
                begin
                    pmod_z <= 8'h00;
                    pmod_o <= test0;
                end
            endcase
        end
    end

    (* MARK_DEBUG = "true" *)  logic   [7:0]   hdr_pmod  ;
    (* MARK_DEBUG = "true" *)  logic   [7:0]   hdr_ptn   ;
    (* MARK_DEBUG = "true" *)  logic   [3:0]   hdr_idx   ;
    always_ff @(posedge clk) begin
        if ( reset ) begin
            hdr_pmod <= '0;
            hdr_ptn  <= '0;
            hdr_idx  <= '0;
        end
        else begin
            // 露光終了時のPMODの状態をキャプチャ
            if ( ff_trigger[1:0] == 2'b10 ) begin
                hdr_pmod <= sync_pmod;
                hdr_ptn  <= pmod_ptn;
                hdr_idx  <= slot_idx;
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
            3'd0:       pkt_hdr <= hdr_pmod         ;
            3'd1:       pkt_hdr <= hdr_ptn          ;
            3'd2:       pkt_hdr <= 8'(hdr_idx)      ;
            3'd4:       pkt_hdr <= sync_pmod        ;
            3'd5:       pkt_hdr <= pmod_ptn         ;
            3'd6:       pkt_hdr <= 8'(slot_idx)     ;
            default:    pkt_hdr <= '0               ;
            endcase
        end
    end

    // gpio
    assign gpio_in = pmod_i;
    
endmodule


`default_nettype wire


// end of file
