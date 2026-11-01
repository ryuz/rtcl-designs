// -----------------------------------------------------------------------------
//  RTC-Lab Designs
//  Real-Time Computing Lab
//
//  Copyright (C) 2025-2026 Ryuji Fuchikami
//  https://rtc-lab.com/
// -----------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module fifo32_cmd_axi4s_checker
        #(
            parameter   int     MIN_PACKET_SIZE = 4     ,
            parameter   int     MAX_PACKET_SIZE = 4096
        )
        (
            jelly3_axi4s_if.mon mon_axi4s   ,

            output  var logic   error       
        );
    
    logic         header;
    logic [15:0]  count ;
    always_ff @(posedge mon_axi4s.aclk) begin
        if ( ~mon_axi4s.aresetn ) begin
            error  <= 1'b0;
            header <= 1'b1;
        end
        else if ( mon_axi4s.aclken ) begin
            if ( mon_axi4s.tvalid && mon_axi4s.tready ) begin
                if ( header ) begin
                    // check opcode
                    if ( mon_axi4s.tdata[7:0] != 8'h10 ) begin
                        $display("opcode error");
                        error <= 1'b1;
                    end
                    // check packet size
                    if ( int'(mon_axi4s.tdata[31:16]) > MAX_PACKET_SIZE ) begin
                        $display("packet size over MAX_PACKET_SIZE %d > %d", mon_axi4s.tdata[31:16], MAX_PACKET_SIZE);
                        error <= 1'b1;
                    end
                    if ( int'(mon_axi4s.tdata[31:16]) < MIN_PACKET_SIZE ) begin
                        $display("packet size under MIN_PACKET_SIZE");
                        error <= 1'b1;
                    end
                    if ( mon_axi4s.tdata[17:16] != 2'b00 ) begin
                        $display("reserved bit error");
                        error <= 1'b1;
                    end

                    if ( mon_axi4s.tdata[31:16] > 0 ) begin
                        count  <= mon_axi4s.tdata[31:16] - 4;
                        header <= 1'b0;
                    end
                end
                else begin
                    if ( count > 0 ) begin
                        count <= count - 4;
                    end
                    else begin
                        header <= 1'b1;
                    end
                end
            end
        end
    end

 endmodule

`default_nettype wire

