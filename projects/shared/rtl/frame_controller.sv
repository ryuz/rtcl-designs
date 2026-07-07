// ---------------------------------------------------------------------------
//  Jelly  -- The platform for real-time computing
//   image processing
//
//                                 Copyright (C) 2008-2024 by Ryuji Fuchikami
//                                 https://github.com/ryuz/jelly.git
// ---------------------------------------------------------------------------



`timescale 1ns / 1ps
`default_nettype none


module frame_controller
        #(
            parameter                   CORE_ID           = 32'h5254_3f21   ,
            parameter                   CORE_VERSION      = 32'h0000_0001   
        )
        (
            jelly3_axi4l_if.s       s_axi4l        ,

            jelly3_axi4s_if.s       s_axi4s        ,
            jelly3_axi4s_if.m       m_axi4s        
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
    localparam  regadr_t REGADR_CORE_ID          = regadr_t'('h00);
    localparam  regadr_t REGADR_CORE_VERSION     = regadr_t'('h01);
    localparam  regadr_t REGADR_START            = regadr_t'('h10);

    // registers

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

    logic          reg_start = 1'b0;

    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_start <= 1'b0   ;

            s_axi4l.bvalid <= 1'b0      ;
            s_axi4l.rdata  <= 'x        ;
            s_axi4l.rvalid <= 1'b0      ;
        end
        else if ( s_axi4l.aclken ) begin
            // auto clear
            reg_start <= 1'b0   ;

            // write
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 1'b0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_START : reg_start <= 1'( write_mask(axi4l_data_t'(reg_start), s_axi4l.wdata, s_axi4l.wstrb));
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
                REGADR_CORE_ID       :  s_axi4l.rdata <= axi4l_data_t'(CORE_ID      );
                REGADR_CORE_VERSION  :  s_axi4l.rdata <= axi4l_data_t'(CORE_VERSION );
                REGADR_START         :  s_axi4l.rdata <= axi4l_data_t'(reg_start    );
                default              :  s_axi4l.rdata <= '0;
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

    logic       ctl_start   ;

    jelly3_pulse_async
        u_pulse_async
            (
                .s_reset    (~s_axi4l.aresetn   ),
                .s_clk      (s_axi4l.aclk       ),
                .s_cke      (s_axi4l.aclken     ),
                .s_pulse    (reg_start          ),
                
                .m_reset    (~s_axi4s.aresetn   ),
                .m_clk      (s_axi4s.aclk       ),
                .m_cke      (s_axi4s.aclken     ),
                .m_pulse    (ctl_start          )
            );


    logic   [3:0]   capture_counter, next_capture_counter;
    always_comb begin
        next_capture_counter = capture_counter;
        if ( ctl_start ) begin
            next_capture_counter++;
        end
        if ( capture_counter > 0 && s_axi4s.tuser[0] && s_axi4s.tvalid && s_axi4s.tready ) begin
            next_capture_counter--;
        end
    end
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            capture_counter <= '0;
        end
        else if ( s_axi4s.aclken ) begin
            capture_counter <= next_capture_counter;
        end
    end

    logic           ctl_busy    = 1'b0  ;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            ctl_busy       <= 1'b0  ;
            m_axi4s.tuser  <= 'x    ;
            m_axi4s.tlast  <= 1'bx  ;
            m_axi4s.tdata  <= 'x    ;
            m_axi4s.tstrb  <= '1    ;
            m_axi4s.tvalid <= 1'b0  ;
        end
        else if ( s_axi4s.aclken ) begin
            if ( !m_axi4s.tvalid || m_axi4s.tready ) begin
                if ( s_axi4s.tuser[0] && s_axi4s.tvalid && s_axi4s.tready ) begin
                    // frame start
                    ctl_busy       <= capture_counter > 0       ;
                    m_axi4s.tuser  <= s_axi4s.tuser             ;
                    m_axi4s.tlast  <= s_axi4s.tlast             ;
                    m_axi4s.tdata  <= s_axi4s.tdata             ;
                    m_axi4s.tstrb  <= '1                        ;
                    m_axi4s.tvalid <= capture_counter > 0       ;
                end
                else begin
                    // frame data
                    m_axi4s.tuser  <= s_axi4s.tuser             ;
                    m_axi4s.tlast  <= s_axi4s.tlast             ;
                    m_axi4s.tdata  <= s_axi4s.tdata             ;
                    m_axi4s.tstrb  <= '1                        ;
                    m_axi4s.tvalid <= s_axi4s.tvalid & ctl_busy ;
                end
            end
        end
    end

    assign s_axi4s.tready = !m_axi4s.tvalid || m_axi4s.tready;

endmodule

`default_nettype wire


// end of file
