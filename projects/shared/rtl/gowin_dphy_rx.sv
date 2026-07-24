// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module gowin_dphy_rx
        #(
            parameter int LANES             = 4     ,
            parameter int DPHY_RESET_TIMING = 16    ,
            parameter int IDLE_MASK_COUNT   = 16    ,
            parameter int LP01_MASK_COUNT   = 3     ,
            parameter int HS_MASK_COUNT     = 3     
        )
        (
            input   var logic                       reset           ,
            input   var logic                       clk             ,

            input   var logic   [LANES-1:0]         dphy_lprx_n     ,
            input   var logic   [LANES-1:0]         dphy_lprx_p     ,
            input   var logic   [LANES-1:0][7:0]    dphy_hsrxd      ,
            input   var logic   [LANES-1:0]         dphy_hsrxd_vld  ,
            output  var logic   [LANES-1:0]         dphy_odten      ,
            output  var logic                       dphy_rx_drst_n  ,
            
            output  var logic   [LANES-1:0][7:0]    out_data        ,
            output  var logic                       out_valid       
        );


    // dphy_rx_drst_n による全レーン一括リセット＆同期という
    // 仕組みのようなのでやや乱暴だが、レーン0 のみ見て
    // 全レーンを纏めて処理する
    
    logic   [1:0]   ff0_dphy_lprx, ff1_dphy_lprx;
    always_ff @( posedge clk ) begin
        ff0_dphy_lprx <= {dphy_lprx_p[0], dphy_lprx_n[0]};
        ff1_dphy_lprx <= ff0_dphy_lprx;
    end


    localparam type count_t = logic [11:0];

    typedef enum logic [1:0] {
        STATE_IDLE = 2'd0,
        STATE_LP01 = 2'd1,
        STATE_LP00 = 2'd2,
        STATE_HS   = 2'd3
    } state_t;

    state_t         state       ;
    count_t         counter     ;
    always_ff @(posedge clk or posedge reset) begin
        if ( reset ) begin
            dphy_odten     <= '0;
            dphy_rx_drst_n <= 1'b1;
            state          <= STATE_IDLE;
            counter        <= '0;
            out_data       <= '0;
            out_valid      <= '0;
        end
        else begin
            dphy_rx_drst_n <= 1'b1      ;
            out_data       <= dphy_hsrxd;
            out_valid      <= 1'b0      ;
            dphy_odten     <= '0        ;

            if ( counter != '1 ) begin
                counter <= counter + 1'b1;
            end

            case ( state )
            STATE_IDLE:
                begin
                    if ( ff1_dphy_lprx != 2'b11 ) begin
                        counter <= '0;
                    end
                    if ( ff1_dphy_lprx == 2'b01 && counter >= count_t'(IDLE_MASK_COUNT) ) begin
                        state   <= STATE_LP01;
                        counter <= '0;
                    end
                end

            STATE_LP01:
                begin
                    if ( ff1_dphy_lprx == 2'b00 && counter >= count_t'(LP01_MASK_COUNT) ) begin
                        state        <= STATE_LP00;
                        counter      <= '0;
                        dphy_odten   <= '1;
                    end
                    else if ( ff1_dphy_lprx != 2'b01 ) begin
                        state   <= STATE_IDLE;
                        counter <= '0;
                    end
                end

            STATE_LP00:
                begin
                    dphy_odten <= '1;
                    if ( counter == count_t'(DPHY_RESET_TIMING) ) begin
                        state          <= STATE_HS  ;
                        counter        <= '0        ;
                        dphy_rx_drst_n <= 1'b0      ;
                    end
                    else if ( ff1_dphy_lprx != 2'b00 ) begin
                        state          <= STATE_IDLE;
                        counter        <= '0;
                        dphy_odten     <= '0;
                    end
                end

            STATE_HS:
                begin
                    dphy_odten <= '1;
                    out_valid  <= &dphy_hsrxd_vld[0] && counter >= count_t'(HS_MASK_COUNT);
                    if ( ff1_dphy_lprx != 2'b00 ) begin
                        state        <= STATE_IDLE;
                        counter      <= '0;
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



    /*
    logic   [LANES-1:0]     ff0_dphy_lprx_n, ff1_dphy_lprx_n;
    logic   [LANES-1:0]     ff0_dphy_lprx_p, ff1_dphy_lprx_p;
    always_ff @(posedge clk) begin
        ff0_dphy_lprx_n <= dphy_lprx_n      ;
        ff0_dphy_lprx_p <= dphy_lprx_p      ;
        ff1_dphy_lprx_n <= ff0_dphy_lprx_n  ;
        ff1_dphy_lprx_p <= ff0_dphy_lprx_p  ;
    end

    localparam type count_t = logic [7:0];

    typedef enum logic [1:0] {
        STATE_IDLE = 2'd0,
        STATE_LP01 = 2'd1,
        STATE_LP00 = 2'd2,
        STATE_HS   = 2'd3
    } state_t;

    state_t         state       ;
    count_t         counter     ;
    always_ff @(posedge clk or posedge reset) begin
        if ( reset ) begin
            dphy_odten     <= '0;
            dphy_rx_drst_n <= 1'b1;
            state          <= STATE_IDLE;
            counter        <= '0;
            out_data       <= '0;
            out_valid      <= '0;
        end
        else begin
            dphy_odten     <= '0    ;
            dphy_rx_drst_n <= 1'b1  ;
            out_valid      <= 1'b0  ;

            if ( counter != '1 ) begin
                counter <= counter + 1'b1;
            end

            case ( state )
            STATE_IDLE:
                begin
                    if ( {&ff1_dphy_lprx_p, &ff1_dphy_lprx_n} != 2'b11 ) begin
                        counter <= '0;
                    end
                    if ( {|ff1_dphy_lprx_p, &ff1_dphy_lprx_n} == 2'b01
                           && counter > count_t'(IDLE_MASK_COUNT) ) begin
                        state   <= STATE_LP01;
                        counter <= '0;
                    end
                end

            STATE_LP01:
                begin
                    if ( {|ff1_dphy_lprx_p, |ff1_dphy_lprx_n} == 2'b00
                        && counter > count_t'(LP01_MASK_COUNT) ) begin
                        state        <= STATE_LP00;
                        counter      <= '0;
//                      dphy_odten   <= '1;
                    end
                    else if ( |ff1_dphy_lprx_p ) begin
                        state   <= STATE_IDLE;
                        counter <= '0;
                    end
                end

            STATE_LP00:
                begin
                    dphy_odten <= '1;
                    if ( counter == count_t'(DPHY_RESET_TIMING) ) begin
                        state          <= STATE_HS  ;
                        counter        <= '0        ;
                        dphy_rx_drst_n <= 1'b0      ;
                    end
                    if ( {|ff1_dphy_lprx_p, |ff1_dphy_lprx_n} != 2'b00 ) begin
                        state          <= STATE_IDLE;
                        counter        <= '0;
                        dphy_odten     <= '0;
                    end
                end

            STATE_HS:
                begin
                    dphy_odten <= '1;
                    out_data   <= dphy_hsrxd;
                    out_valid  <= &dphy_hsrxd_vld && counter > count_t'(HS_MASK_COUNT);
                    if ( {|ff1_dphy_lprx_p, |ff1_dphy_lprx_n} != 2'b00 ) begin
                        state        <= STATE_IDLE;
                        counter      <= '0;
                        dphy_odten   <= '0;
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
    */

endmodule

`default_nettype wire

