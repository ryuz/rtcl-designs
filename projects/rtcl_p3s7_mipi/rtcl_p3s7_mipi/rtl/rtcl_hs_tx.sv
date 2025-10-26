// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


// Original Protocol
module rtcl_hs_tx
        #(
            parameter   int     CHANNELS   = 4          ,
            parameter   int     RAW_BITS   = 10         ,
            parameter   int     DPHY_LANES = 2          ,
            parameter           DEVICE     = "RTL"      ,
            parameter           SIMULATION = "false"    ,
            parameter           DEBUG      = "false"    
        )
        (
            input   var logic   [DPHY_LANES*8-1:0]  header_data     ,
            output  var logic                       header_update   ,

            jelly3_axi4s_if.s                       s_axi4s         ,
            jelly3_axi4s_if.m                       m_axi4s         
        );

    localparam  type    raw_t  = logic [RAW_BITS-1:0];

    // Zero Stuffing
    logic                       stuff_busy  ;
    logic                       stuff_first ;
    logic                       stuff_last  ;
    raw_t   [CHANNELS-1:0]      stuff_data  ;
    logic                       stuff_valid ;
    logic                       stuff_ready ;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            stuff_busy  <= 1'b0 ;
            stuff_first <= 'x   ;
            stuff_last  <= 'x   ;
            stuff_data  <= 'x   ;
            stuff_valid <= 1'b0 ;
        end
        else if ( s_axi4s.aclken ) begin
            if ( stuff_ready ) begin
                stuff_valid <= 1'b0;
            end

            if ( s_axi4s.tready ) begin
                if ( stuff_busy ) begin
                    stuff_first <= s_axi4s.tvalid ? s_axi4s.tuser[0] : '0;
                    stuff_last  <= s_axi4s.tvalid ? s_axi4s.tlast    : '0;
                    stuff_data  <= s_axi4s.tvalid ? s_axi4s.tdata    : '0;
                    stuff_valid <= 1'b1;  // always valid
                    if ( s_axi4s.tvalid && s_axi4s.tlast ) begin
                        stuff_busy <= 1'b0;
                    end
                end
                else begin
                    if ( s_axi4s.tvalid ) begin
                        stuff_busy  <= 1'b1             ;
                        stuff_first <= s_axi4s.tuser[0] ;
                        stuff_last  <= s_axi4s.tlast    ;
                        stuff_data  <= s_axi4s.tdata    ;
                        stuff_valid <= 1'b1;
                    end
                end
            end
        end
    end

    assign s_axi4s.tready = !stuff_valid || stuff_ready;


    // width convert
    logic                           byte_first  ;
    logic                           byte_last   ;
    logic   [DPHY_LANES-1:0][7:0]   byte_data   ;
    logic                           byte_valid  ;
    logic                           byte_ready  ;

    jelly2_stream_width_convert
            #(
                .UNIT_WIDTH         (2                      ),
                .S_NUM              (CHANNELS*5             ),
                .M_NUM              (DPHY_LANES*4           ),
                .HAS_FIRST          (1                      ),
                .HAS_LAST           (1                      ),
                .HAS_STRB           (0                      ),
                .HAS_KEEP           (0                      ),
                .AUTO_FIRST         (0                      ),
                .HAS_ALIGN_S        (0                      ),
                .HAS_ALIGN_M        (0                      ),
                .FIRST_OVERWRITE    (0                      ),
                .FIRST_FORCE_LAST   (0                      ),
                .REDUCE_KEEP        (0                      ),
                .USER_F_WIDTH       (0                      ),
                .USER_L_WIDTH       (0                      ),
                .S_REGS             (1                      ),
                .M_REGS             (1                      )
            )
        u_stream_width_convert
            (
                .reset              (~s_axi4s.aresetn       ),
                .clk                (s_axi4s.aclk           ),
                .cke                (s_axi4s.aclken         ),

                .endian             (1'b0                   ),
                .padding            ('0                     ),
                
                .s_align_s          ('0                     ),
                .s_align_m          ('0                     ),
                .s_first            (stuff_first            ),
                .s_last             (stuff_last             ),
                .s_data             (stuff_data             ),
                .s_strb             ('1                     ),
                .s_keep             ('1                     ),
                .s_user_f           ('0                     ),
                .s_user_l           ('0                     ),
                .s_valid            (stuff_valid            ),
                .s_ready            (stuff_ready            ),

                .m_first            (byte_first             ),
                .m_last             (byte_last              ),
                .m_data             (byte_data              ),
                .m_strb             (                       ),
                .m_keep             (                       ),
                .m_user_f           (                       ),
                .m_user_l           (                       ),
                .m_valid            (byte_valid             ),
                .m_ready            (byte_ready             )
            );

    // Insert Header
    logic                           inshdr_header   ;
    logic                           inshdr_first    ;
    logic                           inshdr_last     ;
    logic   [DPHY_LANES-1:0][7:0]   inshdr_data     ;
    logic                           inshdr_valid    ;
    logic                           inshdr_ready    ;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            inshdr_header <= 1'b1;
            inshdr_first  <= 1'b1;
            inshdr_last   <= 'x;
            inshdr_data   <= 'x;
            inshdr_valid  <= 1'b0;
            header_update <= 1'b0;
        end
        else if ( s_axi4s.aclken ) begin
            header_update <= 1'b0;
            if ( !inshdr_valid || inshdr_ready ) begin
                if ( inshdr_header ) begin
                    if ( byte_valid && byte_first ) begin
                        // header insert
                        inshdr_header <= 1'b0       ;
                        inshdr_first  <= 1'b1       ;
                        inshdr_last   <= 1'b0       ;
                        inshdr_data   <= header_data;
                        inshdr_valid  <= 1'b1       ;
                        header_update <= 1'b1       ;
                    end
                    else begin
                        inshdr_first  <= 1'bx       ;
                        inshdr_last   <= 1'bx       ;
                        inshdr_data   <= 'x         ;
                        inshdr_valid  <= 1'b0       ;
                    end
                end
                else begin
                    inshdr_header <= byte_last      ;
                    inshdr_first  <= 1'b0           ;
                    inshdr_last   <= byte_last      ;
                    inshdr_data   <= byte_data      ;
                    inshdr_valid  <= byte_valid     ;
                end
            end
        end
    end

    assign byte_ready = (!inshdr_valid || inshdr_ready) && !inshdr_header;

    // output
    assign m_axi4s.tuser[0] = inshdr_first  ;
    assign m_axi4s.tlast    = inshdr_last   ;
    assign m_axi4s.tdata    = inshdr_data   ;
    assign m_axi4s.tvalid   = inshdr_valid  ;
    assign inshdr_ready = m_axi4s.tready;

endmodule


`default_nettype wire


// end of file
