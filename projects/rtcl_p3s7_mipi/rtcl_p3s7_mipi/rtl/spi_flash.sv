// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none

module spi_flash
        (
            input   var logic               reset       ,
            input   var logic               clk         ,

            input   var logic               s_last      ,
            input   var logic   [0:0]       s_len       ,
            input   var logic   [1:0][7:0]  s_wdata     ,
            input   var logic               s_valid     ,
            output  var logic               s_ready     ,

            output  var logic   [1:0][7:0]  m_rdata     ,
            output  var logic               m_rvalid    ,

            output  var logic               spi_wp_n    ,
            output  var logic               spi_hold_n  ,
            output  var logic               spi_cs_n    ,
            output  var logic               spi_sck     ,
            output  var logic               spi_mosi    ,
            input   var logic               spi_miso    
        );
    
    // 分周
    logic   [2:0]   clk_div;
    logic           clk_puls;
    always_ff @(posedge clk ) begin
        if (reset) begin
            clk_div  <= '1;
            clk_puls <= 1'b0;
        end
        else begin
            clk_div  <= clk_div - 1'b1;
            clk_puls <= clk_div == '0;
        end
    end

    typedef enum {
        IDLE    ,
        START   ,
        SEND    ,
        STOP0   ,
        STOP1   ,
        END0    ,
        END1    
    } state_t;

    localparam type count_t = logic [5:0];

    logic                   busy    ;
    state_t                 state   ;
    logic    [0:0]          len     ;
    logic                   last    ;
    count_t                 count   ;
    logic    [1:0][7:0]     data    ;
    always_ff @(posedge clk) begin
        if ( reset ) begin
            busy     <= 1'b0    ;
            state    <= IDLE    ;
            count    <= 'x      ;
            data     <= '0      ;
            m_rvalid <= '0      ;
            spi_cs_n <= 1'b1    ;
            spi_sck  <= 1'b0    ;
            spi_mosi <= 1'b0    ;
        end
        else begin
            m_rvalid <= 1'b0;
            if ( s_valid && s_ready ) begin
                busy     <= 1'b1    ;
                state    <= IDLE    ;
                count    <= '0      ;
                len      <= s_len   ;
                last     <= s_last  ;
                data     <= s_wdata ;
//              spi_cs_n <= 1'b1    ;
                spi_sck  <= 1'b0    ;
                spi_mosi <= 1'b0    ;
            end
            else if ( busy && clk_puls ) begin
                case ( state )
                IDLE:
                    begin
                        state    <= START   ;
                        spi_cs_n <= 1'b0    ;
                        spi_sck  <= 1'b0    ;
                    end

                START:
                    begin
                        state    <= SEND        ;
                        count    <= '0          ;
                        spi_cs_n <= 1'b0        ;
                        spi_sck  <= 1'b0        ;
                        {spi_mosi, data} <= {data, spi_miso};
                    end

                SEND:
                    begin
                        spi_sck <= ~spi_sck;
                        if ( spi_sck ) begin
                            count            <= count + 1'b1;   ;
                            {spi_mosi, data} <= {data, spi_miso};
                            if ( count == (count_t'(len) + 1) * 8 - 1 ) begin
                                state    <= STOP0;
                                spi_mosi <= 1'b0;
                                m_rvalid <= 1'b1;
                            end
                        end
                    end

                STOP0:
                    begin
                        state <= STOP1;
                    end

                STOP1:
                    begin
                        state    <= END0;
                        spi_cs_n <= last;
                    end

                END0:
                    begin
                        state    <= END1;
                    end

                END1:
                    begin
                        busy    <= 1'b0;
                        state   <= IDLE;
                    end
                endcase
            end
        end
    end

    assign m_rdata = data;
    assign s_ready = !busy;

    assign spi_wp_n   = 1'b1;
    assign spi_hold_n = 1'b1;

endmodule

`default_nettype wire

// end of file
