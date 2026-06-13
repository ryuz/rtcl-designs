// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`default_nettype none

module rtcl_fifo32_axi4l
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

    addr_t      awaddr      ;
    prot_t      awprot      ;
    logic       awvalid     ;
    logic       awready     ;
    data_t      wdata       ;
    strb_t      wstrb       ;
    logic       wvalid      ;
    logic       wready      ;
    resp_t      bresp       ;
    logic       bvalid      ;
    logic       bready      ;
    addr_t      araddr      ;
    prot_t      arprot      ;
    logic       arvalid     ;
    logic       arready     ;
    data_t      rdata       ;
    resp_t      rresp       ;
    logic       rvalid      ;
    logic       rready      ;

    typedef enum {
        IDLE,
        WADDR,
        WDATA,
        WRITE,
        RADDR,
        READ
    } state_t;

    state_t     state;

    always_ff @(posedge clk) begin
        if ( reset ) begin
            state <= IDLE;

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
            if ( m_axi4l.wready )  m_axi4l.wvalid  <= 1'b0;
            if ( m_axi4l.arready ) m_axi4l.arvalid <= 1'b0;
            case ( state )
            IDLE:
                begin
                    m_axi4l.awaddr  <= 'x   ;
                    m_axi4l.awprot  <= 'x   ;
                    m_axi4l.awvalid <= 1'b0 ;
                    m_axi4l.wdata   <= 'x   ;
                    m_axi4l.wstrb   <= 'x   ;
                    m_axi4l.wvalid  <= 1'b0 ;
                    m_axi4l.araddr  <= 'x   ;
                    m_axi4l.arprot  <= 'x   ;
                    m_axi4l.arvalid <= 1'b0 ;
                    if ( s_rx_valid && s_rx_ready ) begin
                        if ( s_rx_data[7:0] == 8'h02 && s_rx_data[31:16] == 16'd7 ) begin
                            state <= WADDR;
                            m_axi4l.awprot <= s_rx_data[10:8];
                            m_axi4l.wstrb  <= s_rx_data[15:12];
                        end
                        if ( s_rx_data[7:0] == 8'h03 && s_rx_data[31:16] == 16'd3 ) begin
                            state <= RADDR;
                            m_axi4l.arprot <= s_rx_data[10:8];
                        end
                    end
                end
            
            WADDR:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        state <= WDATA;
                        m_axi4l.awaddr <= s_rx_data[31:0];
                    end
                end

            WDATA:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        state <= IDLE;
                        m_axi4l.awvalid <= 1'b1;
                        m_axi4l.wdata   <= s_rx_data[31:0];
                        m_axi4l.wvalid  <= 1'b1;
                    end
                end

            RADDR:
                begin
                    if ( s_rx_valid && s_rx_ready ) begin
                        state <= IDLE;
                        m_axi4l.araddr  <= s_rx_data[31:0];
                        m_axi4l.arvalid <= 1'b1;
                    end
                end
            endcase
        end
    end

    assign s_rx_ready = (!m_axi4l.awvalid || m_axi4l.awready)
                     && (!m_axi4l.wvalid  || m_axi4l.wready )
                     && (!m_axi4l.arvalid || m_axi4l.arready);



 endmodule


`default_nettype wire
