// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module calc_summation
        (
            jelly3_axi4s_if.s   s_axi4s ,   // AXI4-Stream 入力
            jelly3_axi4s_if.m   m_axi4s     // AXI4-Stream 出力
        );

    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            m_axi4s.tlast  <= 1'b1  ;
            m_axi4s.tdata  <= 32'd0 ;
            m_axi4s.tstrb  <= '1    ;
            m_axi4s.tvalid <= 1'b0  ;
        end
        else begin
            // 送信完了
            if ( m_axi4s.tvalid && m_axi4s.tready ) begin
                m_axi4s.tvalid <= 1'b0  ;
            end

            // 受信データの累算
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                m_axi4s.tlast  <= 1'b1                          ;   // 1つだけ送信するのでtlastは常に1
                m_axi4s.tdata  <= m_axi4s.tdata + s_axi4s.tdata ;   // 累算
                m_axi4s.tstrb  <= '1                            ;   // すべてのバイトを有効(32bit)
                m_axi4s.tvalid <= s_axi4s.tlast                 ;   // 最後のデータの時に送信有効
            end
        end
    end

    // 送信データの受付が保留されていなければ、入力を受け付け可能
    assign s_axi4s.tready = !(m_axi4s.tvalid && ~m_axi4s.tready);

endmodule


`default_nettype wire


// end of file
