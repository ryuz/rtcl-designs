// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module dphy_rx
        #(
            parameter int LANES           = 2     ,
            parameter int IDLE_MASK_COUNT = 16    ,
            parameter int HS_MASK_COUNT   = 10    ,
            parameter int LS01_MASK_COUNT = 3     
        )
        (
            input   var logic                       reset           ,
            input   var logic                       clk             ,

            input   var logic   [LANES-1:0][1:0]    dphy_lp         ,
            input   var logic   [LANES-1:0][7:0]    dphy_hs_data    ,
            input   var logic   [LANES-1:0]         dphy_hs_valid   ,
            output  var logic   [LANES-1:0]         dphy_term_en    ,
            
            output  var logic   [LANES-1:0][7:0]    out_data        ,
            output  var logic                       out_valid       
        );

    logic [LANES-1:0][7:0]   byte_data    ;
    logic [LANES-1:0]        byte_valid   ;
    for ( genvar i = 0; i < LANES; i++ ) begin : lane_rx
        gowin_dphy_rx_lane
                #(
                    .IDLE_MASK_COUNT    (IDLE_MASK_COUNT    ),
                    .LS01_MASK_COUNT    (LS01_MASK_COUNT    ),
                    .HS_MASK_COUNT      (HS_MASK_COUNT      )
                )
            u_gowin_dphy_lane_rx
                (
                    .reset              (reset              ),
                    .clk                (clk                ),
                    .dphy_lp            (dphy_lp      [i]   ),
                    .dphy_hs_data       (dphy_hs_data [i]   ),
                    .dphy_hs_valid      (dphy_hs_valid[i]   ),
                    .dphy_term_en       (dphy_term_en [i]   ),
                    .out_data           (byte_data    [i]   ),
                    .out_valid          (byte_valid   [i]   )
                );
    end

    // レーン間調整(最大で1サイクルのずれとする)
    logic   [LANES-1:0]         st0_skip    ;
    logic   [LANES-1:0][7:0]    st0_data    ;
    logic   [LANES-1:0]         st0_valid   ;
    logic   [LANES-1:0][7:0]    st1_data    ;
    logic   [LANES-1:0]         st1_valid   ;
    always_ff @( posedge clk or posedge reset ) begin
        if ( reset ) begin
            st0_skip  <= 'x     ;
            st0_data  <= 'x     ;
            st0_valid <= '0     ;
            st1_data  <= 'x     ;
            st1_valid <= '0     ;
        end
        else begin
            // stage0
            if ( byte_valid == '0 ) begin
                st0_skip <= '0     ;
            end
            else begin
                if ( byte_valid != '0 ) begin
                    st0_skip <= ~byte_valid;
                end
            end
            st0_data  <= byte_data;
            st0_valid <= byte_valid;

            // stage1
            for ( int i = 0; i < LANES; i++ ) begin
                if ( st0_skip[i] ) begin
                    st1_data [i] <= byte_data [i];
                    st1_valid[i] <= byte_valid[i];
                end
                else begin
                    st1_data [i] <= st0_data[i];
                    st1_valid[i] <= st0_valid[i];
                end
            end
        end
    end

    assign out_data  = st1_data     ;
    assign out_valid = st1_valid[0] ;

endmodule


`default_nettype wire
