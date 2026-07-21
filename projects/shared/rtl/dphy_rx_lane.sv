// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module dphy_rx_lane
        #(
            parameter int IDLE_MASK_COUNT = 16    ,
            parameter int HS_MASK_COUNT   = 10    ,
            parameter int LS01_MASK_COUNT = 3     
        )
        (
            input   var logic           reset           ,
            input   var logic           clk             ,

            input   var logic   [1:0]   dphy_lp         ,
            input   var logic   [7:0]   dphy_hs_data    ,
            input   var logic           dphy_hs_valid   ,
            output  var logic           dphy_term_en    ,
            
            output  var logic   [7:0]   out_data        ,
            output  var logic           out_valid       
        );

    localparam type count_t = logic [11:0];

    typedef enum logic [1:0] {
        STATE_IDLE = 2'd0,
        STATE_LP01 = 2'd1,
        STATE_LP00 = 2'd2,
        STATE_HS   = 2'd3
    } state_t;

    state_t         state       ;
    count_t         counter     ;
    logic   [15:0]  rx_data     ;
    logic   [2:0]   bit_align   ;
    always_ff @(posedge clk or posedge reset) begin
        if ( reset ) begin
            state        <= STATE_IDLE;
            counter      <= '0;
            out_data     <= '0;
            out_valid    <= '0;
            dphy_term_en <= '0;
        end
        else begin
            rx_data      <= {dphy_hs_data, rx_data[15:8]};
            out_valid    <= 1'b0        ;
            dphy_term_en <= 1'b0        ;

            if ( counter != '1 ) begin
                counter <= counter + 1'b1;
            end

            case ( state )
            STATE_IDLE:
                begin
                    if ( dphy_lp != 2'b11 ) begin
                        counter <= '0;
                    end
                    if ( dphy_lp == 2'b01 && counter > count_t'(IDLE_MASK_COUNT) ) begin
                        state   <= STATE_LP01;
                        counter <= '0;
                    end
                end

            STATE_LP01:
                begin
                    if ( dphy_lp == 2'b00 && counter > count_t'(LS01_MASK_COUNT) ) begin
                        state        <= STATE_LP00;
                        counter      <= '0;
                        dphy_term_en <= 1'b1;
                    end
                    else if ( dphy_lp != 2'b01 ) begin
                        state   <= STATE_IDLE;
                        counter <= '0;
                    end
                end

            STATE_LP00:
                begin
                    dphy_term_en <= 1'b1;
                    if ( counter > count_t'(HS_MASK_COUNT) && dphy_hs_valid ) begin
                        for ( int i = 0; i < 8; i++ ) begin
                            if ( rx_data[i +: 8] == 8'hb8 ) begin
                                bit_align <= 3'(i);
                                state     <= STATE_HS;
                                counter   <= '0;
                            end
                        end
                    end
                    if ( dphy_lp != 2'b00 ) begin
                        state        <= STATE_IDLE;
                        counter      <= '0;
                        dphy_term_en <= 1'b0;
                    end
                end

            STATE_HS:
                begin
                    dphy_term_en <= 1'b1;
                    out_data     <= 8'(rx_data >> bit_align);
                    out_valid    <= 1'b1;

                    if ( dphy_lp != 2'b00 ) begin
                        state        <= STATE_IDLE;
                        counter      <= '0;
                        dphy_term_en <= 1'b0;
                        out_valid    <= 1'b0;
                    end
                end

            default:
                begin
                    state   <= STATE_IDLE;
                    counter <= '0;
                end
            endcase
        end
    end

endmodule


`default_nettype wire
