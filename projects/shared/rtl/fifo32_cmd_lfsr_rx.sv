// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fifo32_cmd_lfsr_rx
        #(
            parameter   bit             ASYNC        = 1                ,
            parameter   logic   [31:0]  INIT_LFSR    = 32'h1234_5678    ,
            parameter   logic   [31:0]  POLYNOMIAL   = 32'h8020_0003    ,
            parameter                   CORE_ID      = 32'h5254_1821    ,
            parameter                   CORE_VERSION = 32'h0000_0001    
        )
        (
            jelly3_axi4l_if.s   s_axi4l     ,
            jelly3_axi4s_if.s   s_axi4s     ,

            output var logic    mon_error
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
    localparam  regadr_t REGADR_CLEAR        = regadr_t'('h10);
    localparam  regadr_t REGADR_LFSR_VALUE   = regadr_t'('h11);
    localparam  regadr_t REGADR_RX_LEN       = regadr_t'('h12);
    localparam  regadr_t REGADR_LFSR_ERROR   = regadr_t'('h13);


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


    logic           reg_clear   ;
    logic  [31:0]   reg_lfsr    ;
    logic  [31:0]   reg_rx_len  ;
    logic           reg_error   ;

    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_clear   <= 1'b0         ;
            reg_lfsr    <= INIT_LFSR    ;

            s_axi4l.bvalid <= 1'b0      ;
            s_axi4l.rdata  <= 'x        ;
            s_axi4l.rvalid <= 1'b0      ;
        end
        else if ( s_axi4l.aclken ) begin
            // auto clear
            reg_clear <= '0   ;

            // write
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 1'b0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_CLEAR        :  reg_clear  <=  1'( write_mask(axi4l_data_t'(reg_clear ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_LFSR_VALUE   :  reg_lfsr   <= 32'( write_mask(axi4l_data_t'(reg_lfsr  ), s_axi4l.wdata, s_axi4l.wstrb));
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
                REGADR_CLEAR        :  s_axi4l.rdata <= axi4l_data_t'(reg_clear   );
                REGADR_LFSR_VALUE   :  s_axi4l.rdata <= axi4l_data_t'(reg_lfsr    );
                REGADR_RX_LEN       :  s_axi4l.rdata <= axi4l_data_t'(reg_rx_len  );
                REGADR_LFSR_ERROR   :  s_axi4l.rdata <= axi4l_data_t'(reg_error   );
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

    logic           ctl_clear   ;
    logic  [31:0]   ctl_lfsr    ;
    logic  [31:0]   ctl_rx_len  ;
    logic           ctl_error   ;

    jelly3_pulse_async
            #(
                .ASYNC      (ASYNC          )
            )
        u_pulse_async
            (
                .s_reset    (~s_axi4l.aresetn   ),
                .s_clk      (s_axi4l.aclk       ),
                .s_cke      (s_axi4l.aclken     ),
                .s_pulse    (reg_clear          ),

                .m_reset    (~s_axi4s.aresetn   ),
                .m_clk      (s_axi4s.aclk       ),
                .m_cke      (s_axi4s.aclken     ),
                .m_pulse    (ctl_clear          )
            );

    jelly3_cdc_single
        u_cdc_single
            (
                .src_clk    (s_axi4s.aclk   ),
                .src_in     (ctl_error      ),

                .dest_clk   (s_axi4l.aclk   ),
                .dest_out   (reg_error      )
            );

    jelly3_data_async
            #(
                .ASYNC      (ASYNC                  ),
                .DATA_BITS  (32                     )
            )
        u_data_async
            (
                .s_reset    (~s_axi4s.aresetn   ),
                .s_clk      (s_axi4s.aclk       ),
                .s_cke      (1'b1               ),
                .s_data     (ctl_rx_len         ),
                .s_valid    (1'b1               ),
                .s_ready    (                   ),

                .m_reset    (~s_axi4l.aresetn   ),
                .m_clk      (s_axi4l.aclk       ),
                .m_cke      (1'b1               ),
                .m_data     (reg_rx_len         ),
                .m_valid    (                   ),
                .m_ready    (1'b1               )
            );

    logic  [31:0]   expected_lfsr;
    jelly3_lfsr
            #(
                .DATA_BITS      (32                             ),
                .INIT           (INIT_LFSR                      )
            )
        u_lfsr_rx
            (
                .reset          (~s_axi4s.aresetn               ),
                .clk            (s_axi4s.aclk                   ),
                .cke            (s_axi4s.aclken                 ),
                
                .update         (s_axi4s.tvalid & s_axi4s.tready),
                .clear          (ctl_clear                      ),
                .clear_value    (ctl_lfsr                       ),
                .polynomial     (POLYNOMIAL                     ),
                
                .dout           (expected_lfsr                  )
            );

    logic   [31:0]  ctl_rx_count;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            ctl_rx_count <= '0;
            ctl_error    <= 1'b0;
        end
        else if ( s_axi4s.aclken ) begin
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                if ( s_axi4s.tdata != expected_lfsr ) begin
                    ctl_error <= 1'b1;
                end
                ctl_rx_count <= ctl_rx_count + 1;
            end
            if ( ctl_clear ) begin
                ctl_rx_count <= '0;
                ctl_error    <= 1'b0;
            end
        end
    end

    assign s_axi4s.tready = 1'b1;

    assign mon_error = ctl_error;

 endmodule

`default_nettype wire

