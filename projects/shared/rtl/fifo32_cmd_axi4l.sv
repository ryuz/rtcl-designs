// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none

module fifo32_cmd_axi4l
        (
            input   var logic           reset           ,
            input   var logic           clk             ,
            input   var logic           cke             ,

            /*
            input   var logic   [31:0]  s_rx_data       ,
            input   var logic           s_rx_valid      ,
            output  var logic           s_rx_ready      ,
            output  var logic   [31:0]  m_tx_data       ,
            output  var logic           m_tx_valid      ,
            input   var logic           m_tx_ready      ,
            */
            jelly3_axi4s_if.s           s_axi4s_rx      ,
            jelly3_axi4s_if.m           m_axi4s_tx      ,

            jelly3_axi4l_if.m           m_axi4l         
        );


    localparam type  addr_t = logic [m_axi4l.DATA_BITS-1:0];
    localparam type  data_t = logic [m_axi4l.DATA_BITS-1:0];
    localparam type  strb_t = logic [m_axi4l.STRB_BITS-1:0];
    localparam type  prot_t = logic [m_axi4l.PROT_BITS-1:0];
    localparam type  resp_t = logic [m_axi4l.RESP_BITS-1:0];

    // -------------------------------------
    //  RX
    // -------------------------------------

    typedef enum {
        RX_IDLE,
        RX_WADDR,
        RX_WDATA,
        RX_WRITE,
        RX_RADDR,
        RX_READ
    } rx_state_t;

    rx_state_t  rx_state;

    always_ff @(posedge clk) begin
        if ( reset ) begin
            rx_state <= RX_IDLE;

            m_axi4l.awaddr  <= 'x   ;
            m_axi4l.awprot  <= 'x   ;
            m_axi4l.awvalid <= 1'b0 ;
            m_axi4l.wdata   <= 'x   ;
            m_axi4l.wstrb   <= 'x   ;
            m_axi4l.wvalid  <= 1'b0 ;
            m_axi4l.araddr  <= 'x   ;
            m_axi4l.arprot  <= 'x   ;
            m_axi4l.arvalid <= 1'b0 ;
        end
        else if ( cke ) begin
            if ( m_axi4l.awready ) m_axi4l.awvalid <= 1'b0;
            if ( m_axi4l.wready  ) m_axi4l.wvalid  <= 1'b0;
            if ( m_axi4l.arready ) m_axi4l.arvalid <= 1'b0;
            
            case ( rx_state )
            RX_IDLE:
                begin
                    if ( s_axi4s_rx.tvalid && s_axi4s_rx.tready ) begin
                        if ( s_axi4s_rx.tdata[7:0] == 8'h02 && s_axi4s_rx.tdata[31:16] == 16'd8 ) begin
                            rx_state <= RX_WADDR;
                            m_axi4l.awprot <= s_axi4s_rx.tdata[10:8];
                            m_axi4l.wstrb  <= s_axi4s_rx.tdata[15:12];
                        end
                        if ( s_axi4s_rx.tdata[7:0] == 8'h03 && s_axi4s_rx.tdata[31:16] == 16'd4 ) begin
                            rx_state <= RX_RADDR;
                            m_axi4l.arprot <= s_axi4s_rx.tdata[10:8];
                        end
                    end
                end
            
            RX_WADDR:
                begin
                    if ( s_axi4s_rx.tvalid && s_axi4s_rx.tready ) begin
                        rx_state <= RX_WDATA;
                        m_axi4l.awaddr <= s_axi4s_rx.tdata[31:0];
                    end
                end

            RX_WDATA:
                begin
                    if ( s_axi4s_rx.tvalid && s_axi4s_rx.tready ) begin
                        rx_state <= RX_IDLE;
                        m_axi4l.awvalid <= 1'b1;
                        m_axi4l.wdata   <= s_axi4s_rx.tdata[31:0];
                        m_axi4l.wvalid  <= 1'b1;
                    end
                end

            RX_RADDR:
                begin
                    if ( s_axi4s_rx.tvalid && s_axi4s_rx.tready ) begin
                        rx_state <= RX_IDLE;
                        m_axi4l.araddr  <= s_axi4s_rx.tdata[31:0];
                        m_axi4l.arvalid <= 1'b1;
                    end
                end
            
            default:     rx_state <= RX_IDLE;
            endcase
        end
    end

    assign s_axi4s_rx.tready = (!m_axi4l.awvalid || m_axi4l.awready)
                            && (!m_axi4l.wvalid  || m_axi4l.wready )
                            && (!m_axi4l.arvalid || m_axi4l.arready);


    // -------------------------------------
    //  TX
    // -------------------------------------

    typedef enum {
        TX_IDLE,
        TX_RDATA
    } tx_state_t;

    tx_state_t  tx_state;

    always_ff @(posedge clk) begin
        if ( reset ) begin
            tx_state <= TX_IDLE;
            m_axi4s_tx.tdata  <= 'x    ;
            m_axi4s_tx.tvalid <= 1'b0  ;
        end
        else if ( cke ) begin
            if ( m_axi4s_tx.tready ) begin
                m_axi4s_tx.tvalid <= 1'b0;
            end

            if ( !m_axi4s_tx.tvalid || m_axi4s_tx.tready ) begin
                case ( tx_state )
                TX_IDLE:
                    begin
                        if ( m_axi4l.bvalid ) begin
                            tx_state <= TX_IDLE;
                            m_axi4s_tx.tdata        <= '0              ;
                            m_axi4s_tx.tdata[7:0]   <= 8'h02           ;   // opcode
                            m_axi4s_tx.tdata[9:8]   <= m_axi4l.bresp   ;   // operand
                            m_axi4s_tx.tdata[31:16] <= 16'd0           ;   // len
                            m_axi4s_tx.tvalid       <= 1'b1            ;
                        end
                        if ( m_axi4l.rvalid ) begin
                            tx_state <= TX_RDATA;
                            m_axi4s_tx.tdata        <= '0              ;
                            m_axi4s_tx.tdata[7:0]   <= 8'h03           ;   // opcode
                            m_axi4s_tx.tdata[9:8]   <= m_axi4l.rresp   ;   // operand
                            m_axi4s_tx.tdata[31:16] <= 16'd4           ;   // len
                            m_axi4s_tx.tvalid       <= 1'b1            ;
                        end
                    end
                
                TX_RDATA:
                    begin
                        tx_state   <= TX_IDLE;
                        m_axi4s_tx.tdata  <= 32'(m_axi4l.rdata);
                        m_axi4s_tx.tvalid <= 1'b1              ;
                    end
                
                default: tx_state <= TX_IDLE;
                endcase
            end
        end
    end

    assign m_axi4l.bready = (tx_state == TX_IDLE);
    assign m_axi4l.rready = (tx_state == TX_RDATA);

 endmodule


`default_nettype wire

