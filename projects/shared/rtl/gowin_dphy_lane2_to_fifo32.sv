// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------

`timescale 1ps/1ps
`default_nettype none

module gowin_dphy_lane2_to_fifo32
        (
            input   var logic   [15:0]  dphy_data       ,
            input   var logic           dphy_valid      ,

            input   var logic   [7:0]   data_type       ,   // 0x2b
            
            jelly3_axi4s_if.m           m_axi4s
        );

    typedef enum {
        STATE_IDLE      ,
        STATE_HEADER0   ,
        STATE_HEADER1   ,
        STATE_PAYLOAD   ,
        STATE_FINAL     
    } state_t;


    // stage 0
    state_t         state           ;
    logic           frame_start     ;
    logic   [7:0]   header_dt       ;
    logic   [15:0]  header_wc       ;
    logic   [15:0]  counter         ;

    logic           st0_user        ;
    logic           st0_last        ;
    logic   [15:0]  st0_data        ;
    logic           st0_valid       ;

    always_ff @(posedge m_axi4s.aclk ) begin
        if ( ~m_axi4s.aresetn ) begin
            state       <= STATE_IDLE;
            frame_start <= 1'b0 ;
            header_dt   <= 'x   ;
            header_wc   <= 'x   ;
            counter     <= 'x   ;
            st0_user    <= 'x   ;
            st0_data    <= 'x   ;
            st0_valid   <= 1'b0 ;
        end
        else begin
            st0_last  <= 'x     ;
            st0_user  <= 'x     ;
            st0_data  <= 'x     ;
            st0_valid <= 1'b0   ;

            case ( state )
            STATE_IDLE:
                begin
                    if ( dphy_valid && dphy_data == 16'hb8b8 ) begin
                        state <= STATE_HEADER0;
                    end
                end

            STATE_HEADER0:
                begin
                    if ( dphy_valid ) begin
                        state          <= STATE_HEADER1    ;
                        header_dt      <= dphy_data[7:0]   ;
                        header_wc[7:0] <= dphy_data[15:8]  ;
                    end
                    else begin
                        state <= STATE_FINAL;
                    end
                end

            STATE_HEADER1:
                begin
                    if ( dphy_valid ) begin
                        header_wc[15:8] <= dphy_data[7:0];
                        if ( header_dt == data_type ) begin
                            state   <= STATE_PAYLOAD;
                            counter <= 16'h0002;
                        end
                        else begin
                            if ( header_dt == 8'h00 ) begin    // frame start
                                frame_start <= 1'b1;
                            end
                            if ( header_dt == 8'h01 ) begin    // frame end
                                // nop
                            end
                            state <= STATE_FINAL;
                        end
                    end
                    else begin
                        state <= STATE_FINAL;
                    end
                end

            STATE_PAYLOAD:
                begin
                    counter <= counter + 16'd2;
                    if ( st0_valid && st0_last ) begin
                        state <= STATE_FINAL;
                    end
                    else begin
                        if ( dphy_valid ) begin
                            frame_start <= 1'b0;
                            st0_last  <= (counter >= header_wc);
                            st0_user  <= frame_start;
                            st0_data  <= dphy_data;
                            st0_valid <= 1'b1;
                        end
                        else begin
                            state <= STATE_FINAL;
                        end
                    end
                end

                STATE_FINAL:
                    begin
                        if ( !dphy_valid ) begin
                            state <= STATE_IDLE;
                        end
                    end
                
                default:
                    begin
                        state <= STATE_FINAL;
                    end
            endcase
        end
    end

    // stage 1
    logic           st1_phase   ;
    logic           st1_user    ;
    logic           st1_last    ;
    logic   [31:0]  st1_data    ;
    logic           st1_valid   ;
    always_ff @(posedge m_axi4s.aclk ) begin
        if ( ~m_axi4s.aresetn ) begin
            st1_phase <= '0 ;
            st1_user  <= 'x ;
            st1_last  <= 'x ;
            st1_data  <= 'x ;
            st1_valid <= '0 ;
        end
        else begin
            if ( st0_valid ) begin
                st1_phase <= ~st1_phase;
                if ( st1_phase == 1'b0 ) begin
                    st1_user       <= st0_user;
                    st1_last       <= st0_last;
                    st1_data[15:0] <= st0_data;
                    st1_valid      <= 1'b0;
                end
                else begin
                    st1_last        <= st1_last || st0_last;
                    st1_data[31:16] <= st0_data;
                    st1_valid       <= 1'b1;
                end
            end
            else begin
                st1_phase <= '0 ;
                st1_user  <= 'x ;
                st1_last  <= 'x ;
                st1_data  <= 'x ;
                st1_valid <= '0 ;
            end
        end
    end

    assign m_axi4s.tuser  = st1_user    ;
    assign m_axi4s.tlast  = st1_last    ;
    assign m_axi4s.tdata  = st1_data    ;
    assign m_axi4s.tstrb  = '1          ;
    assign m_axi4s.tvalid = st1_valid   ;

endmodule


`default_nettype wire
