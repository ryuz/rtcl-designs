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
            parameter           CORE_ID         = 32'h5254_3f21 ,
            parameter           CORE_VERSION    = 32'h0000_0001 ,
            parameter   int     FRAMES_BITS     = 16            
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
    localparam  regadr_t REGADR_CORE_ID         = regadr_t'('h00);
    localparam  regadr_t REGADR_CORE_VERSION    = regadr_t'('h01);
    localparam  regadr_t REGADR_ENABLE          = regadr_t'('h10);
    localparam  regadr_t REGADR_FRAMES          = regadr_t'('h11);


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

    localparam  type    frames_t = logic [FRAMES_BITS-1:0];

    logic       reg_enable      ;
    frames_t    reg_frames      ;

    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_enable     <= 1'b0      ;
            reg_frames     <= '0        ;

            s_axi4l.bvalid <= 1'b0      ;
            s_axi4l.rdata  <= 'x        ;
            s_axi4l.rvalid <= 1'b0      ;
        end
        else if ( s_axi4l.aclken ) begin
            // auto clear
            reg_frames <= '0   ;

            // write
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 1'b0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_ENABLE:  reg_enable <=        1'( write_mask(axi4l_data_t'(reg_enable), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_FRAMES:  reg_frames <= frames_t'( write_mask(axi4l_data_t'(reg_frames), s_axi4l.wdata, s_axi4l.wstrb));
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
                REGADR_ENABLE       :  s_axi4l.rdata <= axi4l_data_t'(reg_enable  );
                REGADR_FRAMES       :  s_axi4l.rdata <= axi4l_data_t'(reg_frames  );
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

    logic       ctl_enable      ;
    frames_t    capure_frames   ;
    logic       capure_valid    ;

    jelly3_cdc_single
        u_cdc_single
            (
                .src_clk    (s_axi4l.aclk   ),
                .src_in     (reg_enable     ),

                .dest_clk   (s_axi4s.aclk   ),
                .dest_out   (ctl_enable     )
            );


    jelly3_data_async
            #(
                .ASYNC      (1              ),
                .DATA_BITS  ($bits(frames_t))
            )
        u_data_async
            (
                .s_reset    (~s_axi4l.aresetn   ),
                .s_clk      (s_axi4l.aclk       ),
                .s_cke      (1'b1               ),
                .s_data     (reg_frames         ),
                .s_valid    (|reg_frames        ),
                .s_ready    (                   ),

                .m_reset    (~s_axi4s.aresetn   ),
                .m_clk      (s_axi4s.aclk       ),
                .m_cke      (1'b1               ),
                .m_data     (capure_frames      ),
                .m_valid    (capure_valid       ),
                .m_ready    (1'b1               )
            );
    

    frames_t    capture_counter, next_capture_counter   ;
    logic       capture_enable,  next_capture_enable    ;
    always_comb begin
        next_capture_counter = capture_counter  ;

        if ( capure_valid ) begin
            next_capture_counter += capure_frames;
        end

        if ( capture_counter > 0 && s_axi4s.tuser[0] && s_axi4s.tvalid && s_axi4s.tready ) begin
            next_capture_counter--;
        end

        next_capture_enable = next_capture_counter > 0 || ctl_enable;
    end

    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            capture_counter <= '0;
            capture_enable  <= 1'b0;
        end
        else if ( s_axi4s.aclken ) begin
            capture_counter <= next_capture_counter;
            capture_enable  <= next_capture_enable ;
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
                    ctl_busy       <= capture_enable    ;
                    m_axi4s.tuser  <= s_axi4s.tuser     ;
                    m_axi4s.tlast  <= s_axi4s.tlast     ;
                    m_axi4s.tdata  <= s_axi4s.tdata     ;
                    m_axi4s.tstrb  <= '1                ;
                    m_axi4s.tvalid <= capture_enable    ;
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
