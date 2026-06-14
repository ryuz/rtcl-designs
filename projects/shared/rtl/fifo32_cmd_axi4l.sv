// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`default_nettype none

module fifo32_cmd_axi4l
        (
            input   var logic           reset           ,
            input   var logic           clk             ,
            input   var logic           cke             ,

            input   var logic   [31:0]  s_rx_data       ,
            input   var logic           s_rx_valid      ,
            output  var logic           s_rx_ready      ,

            output  var logic   [31:0]  m_tx_data       ,
            output  var logic           m_tx_valid      ,
            input   var logic           m_tx_ready      ,

            jelly3_axi4l_if.m           m_axi4l         
        );


    parameter  type  addr_t = logic [m_axi4l.DATA_BITS-1:0];
    parameter  type  data_t = logic [m_axi4l.DATA_BITS-1:0];
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
                    m_axi4l.wdata   <= 'x   ;
                    m_axi4l.wstrb   <= 'x   ;
                    m_axi4l.wvalid  <= 1'b0 ;
                    m_axi4l.araddr  <= 'x   ;
                    m_axi4l.arprot  <= 'x   ;
                    m_axi4l.arvalid <= 1'b0 ;
                    if ( s_rx_valid && s_rx_ready ) begin
                        if ( s_rx_data[7:0] == 8'h02 && s_rx_data[31:16] == 16'd8 ) begin
                            rx_state <= RX_WADDR;
                            m_axi4l.awprot <= s_rx_data[10:8];
                            m_axi4l.wstrb  <= s_rx_data[15:12];
                        end
                        if ( s_rx_data[7:0] == 8'h03 && s_rx_data[31:16] == 16'd4 ) begin
                            rx_state <= RX_RADDR;
                            m_axi4l.arprot <= s_rx_data[10:8];
                        end
                    end
                end
            
            RX_WADDR:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        rx_state <= RX_WDATA;
                        m_axi4l.awaddr <= s_rx_data[31:0];
                    end
                end

            RX_WDATA:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        rx_state <= RX_IDLE;
                        m_axi4l.awvalid <= 1'b1;
                        m_axi4l.wdata   <= s_rx_data[31:0];
                        m_axi4l.wvalid  <= 1'b1;
                    end
                end

            RX_RADDR:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        rx_state <= RX_IDLE;
                        m_axi4l.araddr  <= s_rx_data[31:0];
                        m_axi4l.arvalid <= 1'b1;
                    end
                end
            
            default:     rx_state <= RX_IDLE;
            endcase
        end
    end

    assign s_rx_ready = (!m_axi4l.awvalid || m_axi4l.awready)
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
            m_tx_data  <= 'x    ;
            m_tx_valid <= 1'b0  ;
        end
        else if ( cke ) begin
            if ( m_tx_ready ) begin
                m_tx_valid <= 1'b0;
            end

            if ( !m_tx_valid || m_tx_ready ) begin
                case ( tx_state )
                TX_IDLE:
                    begin
                        if ( m_axi4l.bvalid && m_axi4l.bready ) begin
                            tx_state <= TX_IDLE;
                            m_tx_data        <= '0              ;
                            m_tx_data[7:0]   <= 8'h02           ;   // id
                            m_tx_data[9:8]   <= m_axi4l.bresp   ;   // op
                            m_tx_data[31:16] <= 16'd0           ;   // len
                            m_tx_valid       <= 1'b1            ;
                        end
                        if ( m_axi4l.rvalid && m_axi4l.rready ) begin
                            tx_state <= TX_RDATA;
                            m_tx_data        <= '0              ;
                            m_tx_data[7:0]   <= 8'h03           ;   // id
                            m_tx_data[9:8]   <= m_axi4l.rresp   ;   // op
                            m_tx_data[31:16] <= 16'd4           ;   // len
                            m_tx_valid       <= 1'b1            ;
                        end
                    end
                
                TX_RDATA:
                    begin
                        tx_state   <= TX_IDLE;
                        m_tx_data  <= 32'(m_axi4l.rdata);
                        m_tx_valid <= 1'b1              ;
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

