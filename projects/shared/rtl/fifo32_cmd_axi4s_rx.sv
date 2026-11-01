// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fifo32_cmd_axi4s_rx
        (
            jelly3_axi4s_if.s   s_axi4s     ,
            jelly3_axi4s_if.m   m_axi4s     
        );

    localparam type     user_t = logic [m_axi4s.USER_BITS-1:0];
    localparam type     data_t = logic [m_axi4s.DATA_BITS-1:0];
    localparam type     strb_t = logic [m_axi4s.STRB_BITS-1:0];
    localparam int      LEN_BITS = 16;
    localparam type     len_t  = logic [LEN_BITS-1:0];

    logic   payload_busy ;
    logic   packet_first ;
    user_t  packet_user  ;
    logic   packet_last  ;
    len_t   packet_len   ;

    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            payload_busy   <= 1'b0 ;
            packet_first   <= 1'b0 ;
            packet_user    <= '0   ;
            packet_last    <= 1'b0 ;
            packet_len     <= '0   ;
            m_axi4s.tuser  <= '0   ;
            m_axi4s.tlast  <= 1'b0 ;
            m_axi4s.tdata  <= '0   ;
            m_axi4s.tstrb  <= '0   ;
            m_axi4s.tvalid <= 1'b0 ;
        end
        else if ( s_axi4s.aclken ) begin
            if ( m_axi4s.tready ) begin
                m_axi4s.tvalid <= 1'b0;
            end

            if ( !m_axi4s.tvalid || m_axi4s.tready ) begin
                if ( !payload_busy ) begin
                    if ( s_axi4s.tvalid ) begin
                        payload_busy <= 1'b1                        ;
                        packet_first <= 1'b1                        ;
                        packet_user  <= user_t'(s_axi4s.tdata[14:8]);
                        packet_last  <= s_axi4s.tdata[15]           ;
                        packet_len   <= len_t'(s_axi4s.tdata[31:16] >> 2);
                    end
                end
                else begin
                    if ( s_axi4s.tvalid ) begin
                        m_axi4s.tuser  <= packet_first ? packet_user : '0;
                        m_axi4s.tlast  <= (packet_len <= 1) && packet_last;
                        m_axi4s.tdata  <= data_t'(s_axi4s.tdata)          ;
                        m_axi4s.tstrb  <= strb_t'(s_axi4s.tstrb)          ;
                        m_axi4s.tvalid <= 1'b1                             ;

                        packet_first <= 1'b0;
                        if ( packet_len <= 1 ) begin
                            payload_busy <= 1'b0;
                            packet_len   <= '0  ;
                        end
                        else begin
                            packet_len <= packet_len - 1'b1;
                        end
                    end
                end
            end
        end
    end

    assign s_axi4s.tready = !m_axi4s.tvalid || m_axi4s.tready;

endmodule

`default_nettype wire