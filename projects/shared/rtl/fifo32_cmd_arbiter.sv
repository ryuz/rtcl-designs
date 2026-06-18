// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none

module fifo32_cmd_arbiter
        #(
            parameter  int N  = 2
        )
        (
            jelly3_axi4s_if.s  s_axi4s  [N]   ,
            jelly3_axi4s_if.m  m_axi4s         
        );

    localparam  int     SEL_BITS = N > 1 ? $clog2(N) : 1;
    localparam  type    sel_t    = logic [SEL_BITS-1:0] ;

    localparam type  data_t = logic [31:0]  ;
    localparam type  strb_t = logic [3:0]   ;
    localparam type  len_t  = logic [15:0]  ;

    logic   [N-1:0]   s_axi4s_tlast ;
    data_t  [N-1:0]   s_axi4s_tdata ;
    strb_t  [N-1:0]   s_axi4s_tstrb ;
    logic   [N-1:0]   s_axi4s_tvalid;
    logic   [N-1:0]   s_axi4s_tready;
    for ( genvar i = 0; i < N; i++ ) begin : s_assign
        assign s_axi4s_tlast  [i] = s_axi4s[i].tlast ;
        assign s_axi4s_tdata  [i] = s_axi4s[i].tdata ;
        assign s_axi4s_tstrb  [i] = s_axi4s[i].tstrb ;
        assign s_axi4s_tvalid [i] = s_axi4s[i].tvalid;
        assign s_axi4s[i].tready = s_axi4s_tready [i] ;
    end


    logic       busy    ;
    sel_t       sel     ;
    len_t       count   ;

    always_ff @( posedge m_axi4s.aclk ) begin
        if ( ~m_axi4s.aresetn ) begin
            busy  <= 1'b0;
            sel   <= 'x;
            count <= 'x;
        end
        else if ( m_axi4s.aclken )  begin
            if ( !m_axi4s.tvalid || m_axi4s.tready ) begin
                if ( !busy ) begin
                    for ( int i = 0; i < N; i++ ) begin
                        if ( s_axi4s_tvalid[i] ) begin
                            m_axi4s.tlast  <= s_axi4s_tlast [i];
                            m_axi4s.tdata  <= s_axi4s_tdata [i];
                            m_axi4s.tstrb  <= s_axi4s_tstrb [i];
                            m_axi4s.tvalid <= 1'b1;
                            if ( s_axi4s_tdata[i][31:16] > 0 ) begin
                                busy  <= 1'b1;
                                count <= s_axi4s_tdata[i][31:16];
                            end
                        end
                    end
                end
                else begin
                    m_axi4s.tlast  <= s_axi4s_tlast [sel];
                    m_axi4s.tdata  <= s_axi4s_tdata [sel];
                    m_axi4s.tstrb  <= s_axi4s_tstrb [sel];
                    m_axi4s.tvalid <= s_axi4s_tvalid[sel];
                    if ( count > 4 ) begin
                        count <= count - len_t'(4);
                    end
                    else begin
                        busy <= 1'b0;
                    end
                end
            end
        end
    end

 endmodule

`default_nettype wire

