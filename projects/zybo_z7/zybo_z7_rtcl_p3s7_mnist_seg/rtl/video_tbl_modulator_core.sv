

`timescale 1ns / 1ps
`default_nettype none


module video_tbl_modulator_core
        #(
            parameter   int     TUSER_BITS     = 1                      ,
            parameter   type    user_t         = logic [TUSER_BITS-1:0] ,
            parameter   int     TDATA_BITS     = 24                     ,
            parameter   type    data_t         = logic [TDATA_BITS-1:0] ,
            parameter   int     ADDR_BITS      = 6                      ,
            parameter   int     MEM_DEPTH      = 2 ** ADDR_BITS         ,
            parameter           RAM_TYPE       = "distributed"          ,
            parameter   int     FILLMEM_DATA   = 127                    ,
            parameter   type    addr_t         = logic [ADDR_BITS-1:0]  ,
            parameter   bit     M_SLAVE_REG    = 1                      ,
            parameter   bit     M_MASTER_REG   = 1                      
        )
        (
            input   var logic           aresetn         ,
            input   var logic           aclk            ,
            input   var logic           aclken          ,
            
            input   var addr_t          param_end       ,
            input   var logic           param_inv       ,
            
            input   var logic           wr_clk          ,
            input   var logic           wr_en           ,
            input   var addr_t          wr_addr         ,
            input   var data_t          wr_din          ,
            
            input   var user_t          s_axi4s_tuser   ,
            input   var logic           s_axi4s_tlast   ,
            input   var data_t          s_axi4s_tdata   ,
            input   var logic           s_axi4s_tvalid  ,
            output  var logic           s_axi4s_tready  ,
            
            output  var user_t          m_axi4s_tuser   ,
            output  var logic           m_axi4s_tlast   ,
            output  var data_t          m_axi4s_tdata   ,
            output  var logic   [0:0]   m_axi4s_tbinary ,
            output  var logic           m_axi4s_tvalid  ,
            input   var logic           m_axi4s_tready  
        );
    
    
    logic                           cke;
    
    // table
    addr_t      rd_addr;
    data_t      rd_dout;
    jelly3_ram_simple_dualport
            #(
                .ADDR_BITS      ($bits(addr_t)  ),
                .DATA_BITS      ($bits(data_t)  ),
                .MEM_DEPTH      (MEM_DEPTH      ),
                .RAM_TYPE       (RAM_TYPE       ),
                .DOUT_REG       (1              ),
                .FILLMEM        (1              ),
                .FILLMEM_DATA   (FILLMEM_DATA   )
            )
        u_ram_simple_dualport
            (
                .wr_clk         (wr_clk         ),
                .wr_en          (wr_en          ),
                .wr_addr        (wr_addr        ),
                .wr_din         (wr_din         ),
                
                .rd_clk         (aclk           ),
                .rd_en          (cke            ),
                .rd_regcke      (cke            ),
                .rd_addr        (rd_addr        ),
                .rd_dout        (rd_dout        )
            );
    
    
    // control
    user_t          st0_tuser   ;
    logic           st0_tlast   ;
    data_t          st0_tdata   ;
    logic           st0_tvalid  ;
    
    addr_t          st1_addr    ;
    user_t          st1_tuser   ;
    logic           st1_tlast   ;
    data_t          st1_tdata   ;
    logic           st1_tvalid  ;
    
    user_t          st2_tuser   ;
    logic           st2_tlast   ;
    data_t          st2_tdata   ;
    logic           st2_tvalid  ;
    
    data_t          st3_th      ;
    user_t          st3_tuser   ;
    logic           st3_tlast   ;
    data_t          st3_tdata   ;
    logic           st3_tvalid  ;
    
    user_t          st4_tuser   ;
    logic           st4_tlast   ;
    logic   [0:0]   st4_tbinary ;
    data_t          st4_tdata   ;
    logic           st4_tvalid  ;
    
    always @(posedge aclk) begin
        if ( ~aresetn ) begin
            st0_tuser   <= 'x   ;
            st0_tlast   <= 1'bx ;
            st0_tdata   <= 'x   ;
            st0_tvalid  <= 1'b0 ;
            
            st1_addr    <= 'x   ;
            st1_tuser   <= 'x   ;
            st1_tlast   <= 1'bx ;
            st1_tdata   <= 'x   ;
            st1_tvalid  <= 1'b0 ;
            
            st2_tuser   <= 'x   ;
            st2_tlast   <= 1'bx ;
            st2_tdata   <= 'x   ;
            st2_tvalid  <= 1'b0 ;
            
            st3_tuser   <= 'x   ;
            st3_tlast   <= 1'bx ;
            st3_tdata   <= 'x   ;
            st3_tvalid  <= 1'b0 ;
            
            st4_tuser   <= 'x   ;
            st4_tlast   <= 1'bx ;
            st4_tdata   <='x    ;
            st4_tbinary <= 1'bx ;
            st4_tvalid  <= 1'b0 ;
        end
        else if ( cke ) begin
            // stage 0
            st0_tuser   <= s_axi4s_tuser;
            st0_tlast   <= s_axi4s_tlast;
            st0_tdata   <= s_axi4s_tdata;
            st0_tvalid  <= s_axi4s_tvalid;
            
            // stage 1
            if ( st0_tvalid && st0_tuser[0] ) begin
                if ( st1_addr != param_end ) begin
                    st1_addr <= st1_addr + 1'b1;
                end
                else begin
                    st1_addr <= '0;
                end
            end
            st1_tuser  <= st0_tuser;
            st1_tlast  <= st0_tlast;
            st1_tdata  <= st0_tdata;
            st1_tvalid <= st0_tvalid;
            
            // stage 2
            st2_tuser  <= st1_tuser;
            st2_tlast  <= st1_tlast;
            st2_tdata  <= st1_tdata;
            st2_tvalid <= st1_tvalid;
            
            // stage 3
            st3_tuser  <= st2_tuser;
            st3_tlast  <= st2_tlast;
            st3_tdata  <= st2_tdata;
            st3_tvalid <= st2_tvalid;
            
            // stage 4
            st4_tuser  <= st3_tuser;
            st4_tlast  <= st3_tlast;
            st4_tdata  <= st3_tdata;
            st4_tvalid <= st3_tvalid;
            if ( st3_tdata > st3_th ) begin
                st4_tbinary <= 1'b1 ^ param_inv;
            end
            else begin
                st4_tbinary <= 1'b0 ^ param_inv;
            end
        end
    end
    
    assign rd_addr = st1_addr;
    assign st3_th  = rd_dout;
    
    
    // output
    jelly3_stream_ff
            #(
                .DATA_BITS  ($bits(user_t)+1+1+$bits(data_t)),
                .S_REG      (M_SLAVE_REG    ),
                .M_REG      (M_MASTER_REG   )
            )
        u_stream_ff
            (
                .reset      (~aresetn       ),
                .clk        (aclk           ),
                .cke        (aclken         ),
                
                .s_data     ({
                                st4_tuser   ,
                                st4_tlast   ,
                                st4_tbinary ,
                                st4_tdata   
                            }),
                .s_valid    (st4_tvalid     ),
                .s_ready    (s_axi4s_tready ),
                
                .m_data     ({
                                m_axi4s_tuser   ,
                                m_axi4s_tlast   ,
                                m_axi4s_tbinary ,
                                m_axi4s_tdata
                            }),
                .m_valid    (m_axi4s_tvalid ),
                .m_ready    (m_axi4s_tready )
            );
    
    assign cke = s_axi4s_tready && aclken;
    
endmodule


`default_nettype wire


// end of file
