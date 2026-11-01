// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module usermodule
        (
            // PC との接続インターフェース
            jelly3_axi4l_if.s           s_axi4l ,   // AXI4-Lite
            jelly3_axi4s_if.s           s_axi4s ,   // AXI4-Stream Input
            jelly3_axi4s_if.m           m_axi4s ,   // AXI4-Stream Output

            // ボードの周辺信号
            input   var logic   [1:0]   push_sw ,   // Push-Switch
            input   var logic   [1:0]   dip_sw  ,   // DIP-Switch
            output  var logic   [3:0]   led     ,   // LED
            output  var logic   [7:0]   pmod        // PMOD
        );

    
    // -----------------------------
    //  AXI4-Lite Register Address
    // -----------------------------
    
    // Register Addresses
    localparam  bit     [31:0]  ADDR_ID         = 32'h0000_0000;
    localparam  bit     [31:0]  ADDR_VERSION    = 32'h0000_0004;
    localparam  bit     [31:0]  ADDR_USER0      = 32'h0000_0008;
    localparam  bit     [31:0]  ADDR_USER1      = 32'h0000_000c;
    localparam  bit     [31:0]  ADDR_PUSH_SW    = 32'h0000_0010;
    localparam  bit     [31:0]  ADDR_DIP_SW     = 32'h0000_0014;
    localparam  bit     [31:0]  ADDR_LED        = 32'h0000_0018;
    localparam  bit     [31:0]  ADDR_PMOD       = 32'h0000_001c;


    // user register
    logic   [31:0]      user0;
    logic   [31:0]      user1;

    // write mask
    function [31:0] write_mask(
                                        input logic [31:0]  orgn,
                                        input logic [31:0]  data,
                                        input logic [3:0]   strb
                                    );
        // strb の立っているバイトのみを更新
        for ( int i = 0; i < 32; i++ ) begin
            write_mask[i] = strb[i/8] ? data[i] : orgn[i];
        end
    endfunction

    // registers control
    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            user0 <= '0;
            user1 <= '0;
            led   <= '0;
            pmod  <= '0;

            s_axi4l.bvalid <= 1'b0  ;
            s_axi4l.rdata  <= '0    ;
            s_axi4l.rvalid <= 1'b0  ;
        end
        else if ( s_axi4l.aclken ) begin
            // write
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 1'b0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( s_axi4l.awaddr )
                ADDR_USER0 : user0 <=    write_mask(user0, s_axi4l.wdata, s_axi4l.wstrb);
                ADDR_USER1 : user1 <=    write_mask(user1, s_axi4l.wdata, s_axi4l.wstrb);
                ADDR_LED   : led   <= 4'(write_mask(led  , s_axi4l.wdata, s_axi4l.wstrb));
                ADDR_PMOD  : pmod  <= 8'(write_mask(pmod , s_axi4l.wdata, s_axi4l.wstrb));
                default: ;
                endcase
                s_axi4l.bvalid <= 1'b1; // 書き込みと同時に応答を返す
            end

            // read
            if ( s_axi4l.rready ) begin
                s_axi4l.rvalid <= 1'b0;
            end
            if ( s_axi4l.arvalid && s_axi4l.arready ) begin
                s_axi4l.rdata <= '0;
                case ( s_axi4l.araddr )
                ADDR_ID       :  s_axi4l.rdata <= 32'h1234_abcd;
                ADDR_VERSION  :  s_axi4l.rdata <= 32'h0001_0000;
                ADDR_USER0    :  s_axi4l.rdata <= user0;
                ADDR_USER1    :  s_axi4l.rdata <= user1;
                ADDR_PUSH_SW  :  s_axi4l.rdata <= 32'(push_sw);
                ADDR_DIP_SW   :  s_axi4l.rdata <= 32'(dip_sw );
                ADDR_LED      :  s_axi4l.rdata <= 32'(led    );
                ADDR_PMOD     :  s_axi4l.rdata <= 32'(pmod   );
                default       :  s_axi4l.rdata <= '0;
                endcase
                s_axi4l.rvalid <= 1'b1;
            end
        end
    end

    assign s_axi4l.awready = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.wvalid;
    assign s_axi4l.wready  = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.awvalid;
    assign s_axi4l.bresp   = '0;
    assign s_axi4l.arready = ~s_axi4l.rvalid || s_axi4l.rready;
    assign s_axi4l.rresp   = '0;


    // -----------------------------
    //  AXI4-Stream
    // -----------------------------

    assign s_axi4s.tready = m_axi4s.tready;
    
    assign m_axi4s.tlast  = s_axi4s.tlast;
    assign m_axi4s.tdata  = s_axi4s.tdata + 1; // 1加算する
    assign m_axi4s.tstrb  = s_axi4s.tstrb;
    assign m_axi4s.tvalid = s_axi4s.tvalid;

endmodule

`default_nettype wire

// end of file
