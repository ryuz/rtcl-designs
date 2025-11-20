// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module i2c_to_spi
        (
            input   var logic               reset               ,
            input   var logic               clk                 ,

            input   var logic               i2c_wr_start        ,
            input   var logic               i2c_wr_en           ,
            input   var logic   [7:0]       i2c_wr_data         ,
            input   var logic               i2c_rd_start        ,
            input   var logic               i2c_rd_req          ,
            output  var logic               i2c_rd_en           ,
            output  var logic   [7:0]       i2c_rd_data         ,

            output  var logic   [8:0]       python_spi_addr     ,
            output  var logic               python_spi_we       ,
            output  var logic   [15:0]      python_spi_wdata    ,
            output  var logic               python_spi_valid    ,
            input   var logic               python_spi_ready    ,
            input   var logic   [15:0]      python_spi_rdata    ,
            input   var logic               python_spi_rvalid   ,

            output  var logic   [0:0]       spi_flash_len       ,
            output  var logic               spi_flash_last      ,
            output  var logic   [1:0][7:0]  spi_flash_wdata     ,
            output  var logic               spi_flash_valid     ,
            input   var logic               spi_flash_ready     ,
            input   var logic   [1:0][7:0]  spi_flash_rdata     ,
            input   var logic               spi_flash_rvalid    ,

            jelly3_axi4l_if.m               m_axi4l
        );

    logic   [1:0]    cmd_wcnt   ;
    logic   [31:0]   cmd_data   , next_data ;
    logic   [14:0]   cmd_addr   , next_addr ;
    logic            cmd_wr     , next_wr   ;
    logic   [15:0]   cmd_wdata  , next_wdata;
    logic   [15:0]   cmd_rdata  ;
    assign next_data = {cmd_data[23:0], i2c_wr_data};
    assign {next_addr, next_wr, next_wdata} = next_data;
    assign {cmd_addr,  cmd_wr,  cmd_wdata } = cmd_data;

    always_ff @(posedge clk) begin
        if ( reset ) begin
            cmd_wcnt         <= '0;
            cmd_data         <= 'x;
            cmd_rdata        <= 'x;
            python_spi_valid <= 1'b0;
            spi_flash_valid  <= 1'b0;
            m_axi4l.awvalid  <= 1'b0;
            m_axi4l.wvalid   <= 1'b0;
            m_axi4l.arvalid  <= 1'b0;
        end
        else begin
            // ready
            if ( python_spi_ready ) begin
                python_spi_valid <= 1'b0;
            end
            if ( spi_flash_ready ) begin
                spi_flash_valid <= 1'b0;
            end
            if ( m_axi4l.awready ) begin
                m_axi4l.awvalid <= 1'b0;
            end
            if ( m_axi4l.wready ) begin
                m_axi4l.wvalid  <= 1'b0;
            end
            if ( m_axi4l.arready ) begin
                m_axi4l.arvalid <= 1'b0;
            end
            
            // write
            if ( i2c_wr_start ) begin
                cmd_wcnt <= '0;
            end
            if ( i2c_wr_en ) begin
                cmd_wcnt  <= cmd_wcnt + 1;
                cmd_data  <= next_data;
                if ( cmd_wcnt == 2'd3 ) begin
                    if ( next_addr[14:9] == 6'b100000 ) begin
                        python_spi_valid <= 1'b1;   // PYTHON300 SPI write
                    end
                    else if ( next_addr[14:9] == 6'b101000 ) begin
                        spi_flash_valid <= 1'b1;   // SPI-Flash write
                    end
                    else begin
                        if ( next_wr ) begin
                            m_axi4l.awvalid <= 1'b1;
                            m_axi4l.wvalid  <= 1'b1;
                        end
                        else begin
                            m_axi4l.arvalid <= 1'b1;
                        end
                    end
                end
            end

            // read
            if ( i2c_rd_req ) begin
                cmd_rdata <= (cmd_rdata >> 8);
            end
            if ( python_spi_rvalid ) begin
                cmd_rdata <= python_spi_rdata;
            end
            if ( spi_flash_rvalid ) begin
                cmd_rdata <= spi_flash_rdata;
            end
            if ( m_axi4l.rvalid ) begin
                cmd_rdata <= m_axi4l.rdata;
            end
        end
    end

    assign python_spi_we    = cmd_wr                ;
    assign python_spi_addr  = cmd_addr[8:0]         ;
    assign python_spi_wdata = cmd_wdata             ;

    assign spi_flash_len    = cmd_addr[1]           ;
    assign spi_flash_last   = cmd_addr[0]           ;
    assign spi_flash_wdata  = cmd_wdata             ;

    assign m_axi4l.awaddr   = {cmd_addr[13:0], 1'b0};
    assign m_axi4l.awprot   = '0                    ;
    assign m_axi4l.wdata    = cmd_wdata             ;
    assign m_axi4l.wstrb    = 2'b11                 ;
    assign m_axi4l.bready   = 1'b1                  ;
    assign m_axi4l.araddr   = {cmd_addr[13:0], 1'b0};
    assign m_axi4l.arprot   = '0                    ;
    assign m_axi4l.rready   = 1'b1                  ;

    assign i2c_rd_en   = i2c_rd_req                 ;
    assign i2c_rd_data = cmd_rdata[7:0]             ;

endmodule

`default_nettype wire

// end of file
