
`timescale 1ns / 1ps
`default_nettype none

module tb_main
        (
            input   var logic   reset       ,
            input   var logic   clk         
        );


    // -------------------------
    //  DUT
    // -------------------------

    parameter   bit     ASYNC         = 0                       ;
    parameter   int     DATA_BUF_SIZE = 256                     ;
    parameter   int     CMD_BUF_SIZE  = 16                      ;
    parameter   int     DATA_PTR_BITS = $clog2(DATA_BUF_SIZE)   ;
    parameter   int     CND_PTR_BITS  = $clog2(CMD_BUF_SIZE)    ;
    parameter   int     LEN_BITS      = DATA_PTR_BITS + 1       ;
    parameter   type    len_t         = logic [LEN_BITS-1:0]    ;
    parameter   int     TIMER_BITS    = 16                      ;
    parameter   type    timer_t       = logic [TIMER_BITS-1:0]  ;

    jelly3_axi4s_if
            #(
                .DATA_BITS  (32      ),
                .USER_BITS  (1       )
            )
        s_axi4s
            (
                .aresetn    (~reset  ),
                .aclk       (clk     ),
                .aclken     (1'b1    )
            );

    jelly3_axi4s_if
            #(
                .DATA_BITS  (32      ),
                .USER_BITS  (1       )
            )
        m_axi4s
            (
                .aresetn    (~reset  ),
                .aclk       (clk     ),
                .aclken     (1'b1    )
            );


    len_t   max_len     ;
    len_t   limit_len   ;
    timer_t timeout     ;

    fifo32_cmd_axi4s_tx
            #(
                .ASYNC          (ASYNC          ),
                .DATA_BUF_SIZE  (DATA_BUF_SIZE  ),
                .CMD_BUF_SIZE   (CMD_BUF_SIZE   ),
                .DATA_PTR_BITS  (DATA_PTR_BITS  ),
                .CND_PTR_BITS   (CND_PTR_BITS   ),
                .LEN_BITS       (LEN_BITS       ),
                .TIMER_BITS     (TIMER_BITS     )
            )
        u_fifo32_cmd_axi4s_tx
            (
                .s_axi4s        (s_axi4s        ),
                .m_axi4s        (m_axi4s        ),
                .max_len        (max_len        ),
                .limit_len      (limit_len      ),
                .timeout        (timeout        )
            );


    // -------------------------
    //  Simulation
    // -------------------------

    assign max_len     = 64     ;
    assign limit_len   = 128    ;
    assign timeout     = 100    ;

    logic   [0:0]    tuser  ;
    logic   [31:0]   tdata  ;
    logic            tlast  ;
    logic            tvalid ;

    always_ff @(posedge clk) begin
        if ( reset ) begin
            tuser  <= 1'b1;
            tlast  <= 1'b0;
            tdata  <= '0;
            tvalid <= 1'b0;
        end
        else begin
            if ( s_axi4s.tvalid && s_axi4s.tready ) begin
                tdata <= tdata + 1;
                tuser <= s_axi4s.tlast && $urandom_range(0, 99) < 30;
            end
            if ( !s_axi4s.tvalid || s_axi4s.tready ) begin
                tvalid <= $urandom_range(0, 99) < 90;
                tlast  <= $urandom_range(0, 99) < 3;
            end
        end
    end

    assign s_axi4s.tuser  = tvalid ? tuser : 'x;
    assign s_axi4s.tlast  = tvalid ? tlast : 'x;
    assign s_axi4s.tdata  = tvalid ? tdata : 'x;
    assign s_axi4s.tstrb  = tvalid ? 4'b1111 : 'x;
    assign s_axi4s.tvalid = tvalid;
    
    always_ff @(posedge clk) begin
        m_axi4s.tready <= $urandom_range(0, 99) < 50;
    end

    int  fp = 0;
    initial begin
        fp = $fopen("out_log.txt", "w");
        #10000000;
        $fclose(fp);
        $finish;
    end

    logic           header;
    logic   [15:0]  counter;
    always_ff @(posedge clk) begin
        if ( reset ) begin
            header <= 1'b1;
        end
        else begin
            if ( m_axi4s.tvalid && m_axi4s.tready ) begin
                if ( header ) begin
                    counter <= m_axi4s.tdata[31:16] - 4;
                    header  <= m_axi4s.tdata[31:16] == 0;
                    $display("HEADER: %08x len:%0d", m_axi4s.tdata, m_axi4s.tdata[31:16]);
                end
                else begin
                    $fwrite(fp, "%08x\n", m_axi4s.tdata);
                    counter <= counter - 4;
                    if ( counter == 0 ) begin
                        header <= 1'b1;
                    end
                end
            end
        end
    end

endmodule


`default_nettype wire


// end of file
