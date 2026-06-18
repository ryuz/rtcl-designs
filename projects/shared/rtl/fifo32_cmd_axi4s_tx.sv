// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`default_nettype none


module fifo32_cmd_axi4s_tx
        #(
            parameter   bit     ASYNC    = 0        ,
            parameter   int     CH_ID    = 0        ,
            parameter   int     MAX_LEN  = 512      ,
            parameter   int     BUF_SIZE = 1024     
        )
        (
            jelly3_axi4s.s      s_axi4s     ,
            jelly3_axi4s.m      m_axi4s     ,
        );
    
    localparam int   PTR_BITS  = $clog2(BUF_SIZE)       ;
    localparam int   LEN_BITS  = $clog2(MAX_LEN)        ;
    localparam type  len_t     = logic [LEN_BITS-1:0]   ;

    localparam type  data_t = logic [s_axi4s.DATA_BITS-1:0];
    localparam type  strb_t = logic [s_axi4s.STRB_BITS-1:0];


    // --------------------------------
    //  FIFO
    // --------------------------------

    // command fifo
    logic   cmd_wr_last     ;
    len_t   cmd_wr_len      ;
    logic   cmd_wr_valid    ;
    logic   cmd_wr_ready    ;

    logic   cmd_rd_last     ;
    len_t   cmd_rd_len      ;
    logic   cmd_rd_valid    ;
    logic   cmd_rd_ready    ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC              ),
                .PTR_BITS       (4                  ),
                .DATA_BITS      (1 + $bits(len_t)   ),
                .RAM_TYPE       ("distributed"      )
            )
        u_stream_fifo_cmd
            (
                .s_reset         (~s_axi4s.aresetn  ),
                .s_clk           (s_axi4s.aclk      ),
                .s_cke           (s_axi4s.aclken    ),
                .s_data          ({
                                    cmd_wr_strb,
                                    cmd_wr_data
                                }),
                .s_valid        (cmd_wr_valid       ),
                .s_ready        (cmd_wr_ready       ),
                .s_free_size    (                   ),

                .m_reset        (~m_axi4s.aresetn   ),
                .m_clk          (m_axi4s.aclk       ),
                .m_cke          (m_axi4s.aclken     ),
                .m_data         ({
                                    cmd_rd_strb,
                                    cmd_rd_data
                                }),
                .m_valid        (cmd_rd_valid       ),
                .m_ready        (cmd_rd_ready       ),
                .m_data_size    (                   )
            );


    // data buffer
    strb_t  buf_wr_strb     ;
    data_t  buf_wr_data     ;
    logic   buf_wr_valid    ;
    logic   buf_wr_ready    ;

    strb_t  buf_rd_strb     ;
    data_t  buf_rd_data     ;
    logic   buf_rd_valid    ;
    logic   buf_rd_ready    ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC              ),
                .PTR_BITS       (PTR_BITS           ),
                .DATA_BITS      ($bits(strb_t) 
                                + $bits(data_t)     ),
                .RAM_TYPE       ("block"            )
            )
        u_stream_fifo_data
            (
                .s_reset         (~s_axi4s.aresetn  ),
                .s_clk           (s_axi4s.aclk      ),
                .s_cke           (s_axi4s.aclken    ),
                .s_data          ({
                                    buf_wr_strb,
                                    buf_wr_data
                                }),
                .s_valid        (buf_wr_valid       ),
                .s_ready        (buf_wr_ready       ),
                .s_free_size    (                   ),

                .m_reset        (~m_axi4s.aresetn   ),
                .m_clk          (m_axi4s.aclk       ),
                .m_cke          (m_axi4s.aclken     ),
                .m_data         ({
                                    buf_rd_strb,
                                    buf_rd_data
                                }),
                .m_valid        (buf_rd_valid       ),
                .m_ready        (buf_rd_ready       ),
                .m_data_size    (                   )
            );



    // --------------------------------
    //  length counter
    // --------------------------------

    assign buf_wr_strb  = s_axi4s.tstrb ;
    assign buf_wr_data  = s_axi4s.tdata ;
    assign buf_wr_valid = s_axi4s.valid && (!cmd_wr_valid || cmd_wr_ready);
    assign s_axi4s.ready = buf_wr_ready && (!cmd_wr_valid || cmd_wr_ready);

    size_t  buf_counter ;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            buf_counter <= '0   ;
            cmd_wr_last <= 1'bx ;
            cmd_wr_len  <= 'x   ;
            cmd_wr_valid<= 1'b0 ;
        end
        else if ( s_axi4s.aclken ) begin
            if ( cmd_wr_ready ) begin
                cmd_wr_valid <= 1'b0    ;
            end
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                if ( s_axi4s.tlast || (buf_counter + 1) >= MAX_LEN ) begin
                    buf_counter  <= '0;
                    cmd_wr_last  <= s_axi4s.tlast   ;
                    cmd_wr_len   <= buf_counter     ;
                    cmd_wr_valid <= 1'b1            ;
                end
                else begin
                    buf_counter <= buf_counter + 1  ;
                end
            end
        end
    end
    


    // --------------------------------
    //  Packet send
    // --------------------------------

    logic       send_busy   ;
    len_t       send_len    ;
    always_ff @(posedge m_axi4s.aclk) begin
        if ( ~m_axi4s.aresetn ) begin
            busy           <= 1'b0 ;
            send_len       <= 'x   ;
            m_axi4s.tlast  <= 1'bx ;
            m_axi4s.tdata  <= 'x   ;
            m_axi4s.tstrb  <= 'x   ;
            m_axi4s.tvalid <= 1'b0 ;
        end
        else if ( m_axi4s.aclken ) begin
            if ( m_axi4s.tready ) begin
                m_axi4s.tvalid <= 1'b0;
            end

            if ( !m_axi4s.tvalid || m_axi4s.tready ) begin
                if ( !busy ) begin
                    if ( cmd_rd_valid ) begin
                        send_busy <= 1'b1        ;
                        send_len  <= cmd_rd_len  ;

                        m_axi4s.tlast        <= 1'b0                    ;
                        m_axi4s.tdata[7:0]   <= 8'h0x10                 ;   // opcode
                        m_axi4s.tdata[14:8]  <= 7'(CH_ID)               ;   // channel ID
                        m_axi4s.tdata[15]    <= cmd_rd_last             ;   // last
                        m_axi4s.tdata[31:16] <= 32'({cmd_rd_len, 2'b00});   // length
                        m_axi4s.tstrb        <= '1                      ;
                        m_axi4s.tvalid       <= 1'b1                    ;
                    end
                end
                else begin
                    send_len <= send_len - 1;
                    if ( send_len == '0 ) begin
                        send_busy <= 1'b0;
                    end

                    m_axi4s.tlast  <= buf_rd_last   ;
                    m_axi4s.tdata  <= buf_rd_data   ;
                    m_axi4s.tstrb  <= buf_rd_strb   ;
                    m_axi4s.tvalid <= buf_rd_valid  ;
                end
            end
        end
    end

    assign cmd_rd_ready = !busy && (!m_axi4s.tvalid || m_axi4s.tready);
    assign buf_rd_ready =  busy && (!m_axi4s.tvalid || m_axi4s.tready);


 endmodule

`default_nettype wire

