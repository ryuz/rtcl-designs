// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fifo32_cmd_axi4s_tx
        #(
            parameter   bit     ASYNC         = 0                       ,
            parameter   int     DATA_BUF_SIZE = 1024                    ,
            parameter   int     CMD_BUF_SIZE  = 128                     ,
            parameter   int     DATA_PTR_BITS = $clog2(DATA_BUF_SIZE)   ,
            parameter   int     CND_PTR_BITS  = $clog2(CMD_BUF_SIZE)    ,
            parameter   int     LEN_BITS      = DATA_PTR_BITS + 1       ,
            parameter   type    len_t         = logic [LEN_BITS-1:0]    ,
            parameter   int     TIMER_BITS    = 16                      ,
            parameter   type    timer_t       = logic [TIMER_BITS-1:0]  
        )
        (
            jelly3_axi4s_if.s   s_axi4s     ,
            jelly3_axi4s_if.m   m_axi4s     ,
            input   var len_t   max_len     ,
            input   var len_t   limit_len   ,
            input   var timer_t timeout     
        );
    
    localparam int      SIZE_BITS      = DATA_PTR_BITS + 1    ;
    localparam type     size_t         = logic [SIZE_BITS-1:0];

    localparam type     user_t = logic [s_axi4s.USER_BITS-1:0];
    localparam type     data_t = logic [s_axi4s.DATA_BITS-1:0];
    localparam type     strb_t = logic [s_axi4s.STRB_BITS-1:0];


    // --------------------------------
    //  FIFO
    // --------------------------------

    // command fifo
    user_t  cmd_wr_user     ;
    logic   cmd_wr_last     ;
    len_t   cmd_wr_len      ;
    logic   cmd_wr_valid    ;
    logic   cmd_wr_ready    ;

    user_t  cmd_rd_user     ;
    logic   cmd_rd_last     ;
    len_t   cmd_rd_len      ;
    logic   cmd_rd_valid    ;
    logic   cmd_rd_ready    ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC              ),
                .PTR_BITS       (CND_PTR_BITS       ),
                .DATA_BITS      (  $bits(user_t)
                                 + 1
                                 + $bits(len_t)     ),
                .S_SYNC_FF      (4                  ),
                .M_SYNC_FF      (4                  ),
                .RAM_TYPE       ("distributed"      )
            )
        u_stream_fifo_cmd
            (
                .s_reset         (~s_axi4s.aresetn  ),
                .s_clk           (s_axi4s.aclk      ),
                .s_cke           (s_axi4s.aclken    ),
                .s_data          ({
                                    cmd_wr_user,
                                    cmd_wr_last,
                                    cmd_wr_len
                                }),
                .s_valid        (cmd_wr_valid       ),
                .s_ready        (cmd_wr_ready       ),
                .s_free_size    (                   ),

                .m_reset        (~m_axi4s.aresetn   ),
                .m_clk          (m_axi4s.aclk       ),
                .m_cke          (m_axi4s.aclken     ),
                .m_data         ({
                                    cmd_rd_user,
                                    cmd_rd_last,
                                    cmd_rd_len
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
    size_t  buf_rd_size     ;

    jelly3_stream_fifo
            #(
                .ASYNC          (ASYNC              ),
                .PTR_BITS       (DATA_PTR_BITS      ),
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
                .m_data_size    (buf_rd_size        )
            );



    // --------------------------------
    //  length counter
    // --------------------------------

    assign buf_wr_strb  = s_axi4s.tstrb ;
    assign buf_wr_data  = s_axi4s.tdata ;
    assign buf_wr_valid = s_axi4s.tvalid && (!cmd_wr_valid || cmd_wr_ready);
    assign s_axi4s.tready = buf_wr_ready && (!cmd_wr_valid || cmd_wr_ready);

    logic   packet_first;
    len_t   buf_counter ;
    always_ff @(posedge s_axi4s.aclk) begin
        if ( ~s_axi4s.aresetn ) begin
            buf_counter  <= '0      ;
            packet_first <= 1'b1    ;
            cmd_wr_user  <= 1'bx    ;
            cmd_wr_last  <= 1'bx    ;
            cmd_wr_len   <= 'x      ;
            cmd_wr_valid <= 1'b0    ;
        end
        else if ( s_axi4s.aclken ) begin
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                if ( packet_first ) begin
                    packet_first <= 1'b0;
                    cmd_wr_user  <= s_axi4s.tuser   ;
                end
                if ( s_axi4s.tlast ) begin
                    packet_first <= 1'b1;
                end
            end

            if ( cmd_wr_ready ) begin
                cmd_wr_valid <= 1'b0    ;
            end
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                if ( s_axi4s.tlast || buf_counter >= max_len ) begin
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

    logic   [15:0]  packet_len  ;
    always_comb begin
        packet_len = (16'(cmd_rd_len) + 16'd1) * 16'd4;
    end

    logic           send_busy   ;
    len_t           send_len    ;

    user_t          out_tuser   ;
    logic           out_tlast   ;
    data_t          out_tdata   ;
    strb_t          out_tstrb   ;
    logic           out_tvalid  ;
    logic           out_tready  ;
    always_ff @(posedge m_axi4s.aclk) begin
        if ( ~m_axi4s.aresetn ) begin
            send_busy   <= 1'b0 ;
            send_len       <= 'x   ;
            out_tuser   <= '0   ;
            out_tlast   <= 1'bx ;
            out_tdata   <= 'x   ;
            out_tstrb   <= 'x   ;
            out_tvalid  <= 1'b0 ;
        end
        else if ( m_axi4s.aclken ) begin
            out_tuser  <= '0   ;

            if ( out_tready ) begin
                out_tvalid <= 1'b0;
            end

            if ( !out_tvalid || out_tready ) begin
                if ( !send_busy ) begin
                    if ( cmd_rd_valid ) begin
                        send_busy <= 1'b1        ;
                        send_len  <= cmd_rd_len  ;

                        out_tuser[0]     <= 1'b1            ;
                        out_tlast        <= 1'b0            ;
                        out_tdata[7:0]   <= 8'h10           ;   // opcode
                        out_tdata[14:8]  <= 7'(cmd_rd_user) ;   // user
                        out_tdata[15]    <= cmd_rd_last     ;   // last
                        out_tdata[31:16] <= packet_len      ;   // length
                        out_tdata[31:28] <= 4'h0            ;   // reserved
                        out_tstrb        <= '1              ;
                        out_tvalid       <= 1'b1            ;
                    end
                end
                else begin
                    send_len <= send_len - 1;
                    if ( send_len == '0 ) begin
                        send_busy <= 1'b0;
                    end

                    out_tlast  <= send_len == '0;
                    out_tdata  <= buf_rd_data   ;
                    out_tstrb  <= buf_rd_strb   ;
                    out_tvalid <= buf_rd_valid  ;
                end
            end
        end
    end

    assign cmd_rd_ready = !send_busy && (!out_tvalid || out_tready);
    assign buf_rd_ready =  send_busy && (!out_tvalid || out_tready);


    // timeout
    timer_t     timer_counter   ;
    logic       output_enable   ;
    always_ff @(posedge m_axi4s.aclk) begin
        if ( ~m_axi4s.aresetn ) begin
            timer_counter <= '0     ;
            output_enable <= 1'b0   ;
        end
        else if ( m_axi4s.aclken ) begin
            if ( output_enable ) begin
                if ( !buf_rd_valid ) begin
                    if ( timeout > 0 ) begin
                        output_enable <= 1'b0   ;
                        timer_counter <= '0     ;
                    end
                end
            end
            else begin
                if ( buf_rd_size >= size_t'(limit_len) ) begin
                    output_enable <= 1'b1   ;
                end
                else if ( timer_counter >= timeout ) begin
                    output_enable <= 1'b1   ;
                end
                else if ( buf_rd_valid ) begin
                    timer_counter <= timer_counter + 1;
                end
            end
        end
    end

    assign m_axi4s.tuser  = out_tuser  ;
    assign m_axi4s.tlast  = out_tlast  ;
    assign m_axi4s.tdata  = out_tdata  ;
    assign m_axi4s.tstrb  = out_tstrb  ;
    assign m_axi4s.tvalid = out_tvalid     & output_enable;
    assign out_tready     = m_axi4s.tready & output_enable;

 endmodule

`default_nettype wire

