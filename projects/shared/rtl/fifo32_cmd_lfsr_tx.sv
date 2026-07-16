// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fifo32_cmd_lfsr_tx
        #(
            parameter   bit             ASYNC        = 1                ,
            parameter   logic   [31:0]  INIT_LFSR    = 32'h1234_5678    ,
            parameter   logic   [31:0]  INIT_TX_LEN  = 32'h0000_0000    ,
            parameter   logic   [31:0]  POLYNOMIAL   = 32'h8020_0003    ,
            parameter                   CORE_ID      = 32'h5254_1822    ,
            parameter                   CORE_VERSION = 32'h0000_0001    
        )
        (
            jelly3_axi4l_if.s   s_axi4l     ,
            jelly3_axi4s_if.m   m_axi4s     
        );
    

    localparam  int             REGADR_BITS       = 8                           ;
    localparam  type            regadr_t          = logic [REGADR_BITS-1:0]     ;


    // -------------------------------------
    //  Registers
    // -------------------------------------

    // AXI4L types
    localparam int  AXI4L_ADDR_BITS = s_axi4l.ADDR_BITS;
    localparam int  AXI4L_DATA_BITS = s_axi4l.DATA_BITS;
    localparam int  AXI4L_STRB_BITS = s_axi4l.STRB_BITS;
    localparam type axi4l_addr_t = logic [AXI4L_ADDR_BITS-1:0];
    localparam type axi4l_data_t = logic [AXI4L_DATA_BITS-1:0];
    localparam type axi4l_strb_t = logic [AXI4L_STRB_BITS-1:0];

    // register address offset
    localparam  regadr_t REGADR_CORE_ID      = regadr_t'('h00);
    localparam  regadr_t REGADR_CORE_VERSION = regadr_t'('h01);
    localparam  regadr_t REGADR_START        = regadr_t'('h10);
    localparam  regadr_t REGADR_LFSR_VALUE   = regadr_t'('h11);
    localparam  regadr_t REGADR_TX_LEN       = regadr_t'('h12);


    // write mask
    function [AXI4L_DATA_BITS-1:0] write_mask(
                                        input axi4l_data_t org,
                                        input axi4l_data_t data,
                                        input axi4l_strb_t strb
                                    );
        for ( int i = 0; i < AXI4L_DATA_BITS; i++ ) begin
            write_mask[i] = strb[i/8] ? data[i] : org[i];
        end
    endfunction

    // registers control
    regadr_t  regadr_write;
    regadr_t  regadr_read;
    assign regadr_write = regadr_t'(s_axi4l.awaddr / axi4l_addr_t'($bits(axi4l_strb_t)));
    assign regadr_read  = regadr_t'(s_axi4l.araddr / axi4l_addr_t'($bits(axi4l_strb_t)));


    logic           reg_start   ;
    logic  [31:0]   reg_lfsr    ;
    logic  [31:0]   reg_tx_len  ;

    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_start   <= 1'b0         ;
            reg_lfsr    <= INIT_LFSR    ;
            reg_tx_len  <= INIT_TX_LEN  ;

            s_axi4l.bvalid <= 1'b0      ;
            s_axi4l.rdata  <= 'x        ;
            s_axi4l.rvalid <= 1'b0      ;
        end
        else if ( s_axi4l.aclken ) begin
            // auto clear
            reg_start <= '0   ;

            // write
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 1'b0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_START        :  reg_start  <=  1'( write_mask(axi4l_data_t'(reg_start ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_LFSR_VALUE   :  reg_lfsr   <= 32'( write_mask(axi4l_data_t'(reg_lfsr  ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_TX_LEN       :  reg_tx_len <= 32'( write_mask(axi4l_data_t'(reg_tx_len), s_axi4l.wdata, s_axi4l.wstrb));
                default: ;
                endcase
                s_axi4l.bvalid <= 1'b1;
            end

            // read
            if ( s_axi4l.rready ) begin
                s_axi4l.rvalid <= 1'b0;
            end
            if ( s_axi4l.arvalid && s_axi4l.arready ) begin
                s_axi4l.rdata <= '0;
                case ( regadr_read )
                REGADR_CORE_ID      :  s_axi4l.rdata <= axi4l_data_t'(CORE_ID     );
                REGADR_CORE_VERSION :  s_axi4l.rdata <= axi4l_data_t'(CORE_VERSION);
                REGADR_START        :  s_axi4l.rdata <= axi4l_data_t'(reg_start   );
                REGADR_LFSR_VALUE   :  s_axi4l.rdata <= axi4l_data_t'(reg_lfsr    );
                REGADR_TX_LEN       :  s_axi4l.rdata <= axi4l_data_t'(reg_tx_len  );
                default             :  s_axi4l.rdata <= '0;
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


    // -------------------------------------
    //  Control
    // -------------------------------------

    logic           ctl_start   ;
    logic  [31:0]   ctl_lfsr    ;
    logic  [31:0]   ctl_tx_len  ;

    jelly3_data_async
            #(
                .ASYNC      (ASYNC                  ),
                .DATA_BITS  (32+32                  )
            )
        u_data_async
            (
                .s_reset    (~s_axi4l.aresetn       ),
                .s_clk      (s_axi4l.aclk           ),
                .s_cke      (1'b1                   ),
                .s_data     ({reg_lfsr, reg_tx_len} ),
                .s_valid    (reg_start              ),
                .s_ready    (                       ),

                .m_reset    (~m_axi4s.aresetn       ),
                .m_clk      (m_axi4s.aclk           ),
                .m_cke      (1'b1                   ),
                .m_data     ({ctl_lfsr, ctl_tx_len} ),
                .m_valid    (ctl_start              ),
                .m_ready    (1'b1                   )
            );

    jelly3_lfsr
            #(
                .DATA_BITS      (32                             ),
                .INIT           (INIT_LFSR                      )
            )
        u_lfsr_rx
            (
                .reset          (~m_axi4s.aresetn               ),
                .clk            (m_axi4s.aclk                   ),
                .cke            (m_axi4s.aclken                 ),
                
                .update         (m_axi4s.tvalid & m_axi4s.tready),
                .clear          (ctl_start                      ),
                .clear_value    (ctl_lfsr                       ),
                .polynomial     (POLYNOMIAL                     ),
                
                .dout           (m_axi4s.tdata                  )
            );

    logic   [31:0]  tx_count;
    always_ff @(posedge m_axi4s.aclk) begin
        if ( ~m_axi4s.aresetn ) begin
            tx_count <= '0;
            m_axi4s.tlast  <= 1'b0;
            m_axi4s.tvalid <= 1'b0;
        end
        else if ( m_axi4s.aclken ) begin
            if ( m_axi4s.tready ) begin
                m_axi4s.tvalid <= 1'b0;
            end
            if ( !m_axi4s.tvalid || m_axi4s.tready ) begin
                if ( tx_count > 0 ) begin
                    tx_count       <= tx_count - 1;
                    m_axi4s.tlast  <= (tx_count - 1) == 0;
                    m_axi4s.tvalid <= 1'b1;
                end
            end
            if ( ctl_start ) begin
                tx_count <= ctl_tx_len;
            end
        end
    end

    assign m_axi4s.tstrb = '1;

 endmodule

`default_nettype wire

