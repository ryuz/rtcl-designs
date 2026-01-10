

`timescale 1ns / 1ps
`default_nettype none

module video_tbl_modulator
        #(
            parameter   int     TUSER_BITS     = 1                      ,
            parameter   type    user_t         = logic [TUSER_BITS-1:0] ,
            parameter   int     TDATA_BITS     = 24                     ,
            parameter   type    data_t         = logic [TDATA_BITS-1:0] ,
            parameter   int     REGADR_BITS    = 8                      ,
            parameter   type    regadr_t       = logic [REGADR_BITS-1:0],
            
            parameter   int     ADDR_BITS      = 6                      ,
            parameter   int     MEM_DEPTH      = 2 ** ADDR_BITS         ,
            parameter           RAM_TYPE       = "distributed"          ,
            parameter   int     FILLMEM_DATA   = 127                    ,
            
            parameter   bit     M_SLAVE_REG    = 1                      ,
            parameter   bit     M_MASTER_REG   = 1                      ,
            
            parameter   bit     INIT_PARAM_END = 0                      ,
            parameter   bit     INIT_PARAM_INV = 0                      
        )
        (
            jelly3_axi4l_if.s           s_axi4l         ,

            input   var logic           aresetn         ,
            input   var logic           aclk            ,
            input   var logic           aclken          ,
            
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
    
    localparam type axi4l_data_t = logic [s_axi4l.DATA_BITS-1:0];
    localparam type table_addr_t = logic [ADDR_BITS-1:0]        ;
    
    // register
    localparam  regadr_t    REGADR_CORE_ID      = regadr_t'('h00);
    localparam  regadr_t    REGADR_PARAM_END    = regadr_t'('h04);
    localparam  regadr_t    REGADR_PARAM_INV    = regadr_t'('h05);
    
    localparam  regadr_t    REGADR_TBL_START    = regadr_t'(1 << ADDR_BITS);
    localparam  regadr_t    REGADR_TBL_END      = REGADR_TBL_START + regadr_t'(MEM_DEPTH - 1);
    
    table_addr_t    reg_param_end;
    logic   [0:0]   reg_param_inv;

    function [s_axi4l.DATA_BITS-1:0] write_mask(
                                        input [s_axi4l.DATA_BITS-1:0] org,
                                        input [s_axi4l.DATA_BITS-1:0] data,
                                        input [s_axi4l.STRB_BITS-1:0] strb
                                    );
        for ( int i = 0; i < s_axi4l.DATA_BITS; i++ ) begin
            write_mask[i] = strb[i/8] ? data[i] : org[i];
        end
    endfunction

    regadr_t  regadr_write;
    regadr_t  regadr_read;
    assign regadr_write = regadr_t'(s_axi4l.awaddr / s_axi4l.ADDR_BITS'(s_axi4l.STRB_BITS));
    assign regadr_read  = regadr_t'(s_axi4l.araddr / s_axi4l.ADDR_BITS'(s_axi4l.STRB_BITS));

    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_param_end <= INIT_PARAM_END;
            reg_param_inv <= INIT_PARAM_INV;
        end
        else begin
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_PARAM_END:   reg_param_end <= table_addr_t'(write_mask(axi4l_data_t'(reg_param_end  ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_PARAM_INV:   reg_param_inv <=            1'(write_mask(axi4l_data_t'(reg_param_inv  ), s_axi4l.wdata, s_axi4l.wstrb));
                default: ;
                endcase
            end
        end
    end

    always_ff @(posedge s_axi4l.aclk ) begin
        if ( ~s_axi4l.aresetn ) begin
            s_axi4l.bvalid <= 0;
        end
        else begin
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready ) begin
                s_axi4l.bvalid <= 1'b1;
            end
        end
    end

    assign s_axi4l.awready = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.wvalid  ;
    assign s_axi4l.wready  = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.awvalid ;
    assign s_axi4l.bresp   = '0;


    // read
    always_ff @(posedge s_axi4l.aclk ) begin
        if ( s_axi4l.arvalid && s_axi4l.arready ) begin
            case ( regadr_read )
            REGADR_CORE_ID  :   s_axi4l.rdata <= axi4l_data_t'('h33221234       );
            REGADR_PARAM_END:   s_axi4l.rdata <= axi4l_data_t'(reg_param_end    );
            REGADR_PARAM_INV:   s_axi4l.rdata <= axi4l_data_t'(reg_param_inv    );
            default:            s_axi4l.rdata <= '0;
            endcase
        end
    end

    logic           axi4l_rvalid;
    always_ff @(posedge s_axi4l.aclk ) begin
        if ( ~s_axi4l.aresetn ) begin
            s_axi4l.rvalid <= 1'b0;
        end
        else begin
            if ( s_axi4l.rready ) begin
                s_axi4l.rvalid <= 1'b0;
            end
            if ( s_axi4l.arvalid && s_axi4l.arready ) begin
                s_axi4l.rvalid <= 1'b1;
            end
        end
    end

    assign s_axi4l.arready = ~s_axi4l.rvalid || s_axi4l.rready;
    assign s_axi4l.rresp   = '0;
    

    logic           wr_en   ;
    table_addr_t    wr_addr ;
    data_t          wr_din  ;
    assign wr_en   = s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready && (regadr_write >= REGADR_TBL_START && regadr_write <= REGADR_TBL_END);
    assign wr_addr = table_addr_t'(regadr_write)   ;
    assign wr_din  =       data_t'(s_axi4l.wdata)  ;
    
    video_tbl_modulator_core
            #(
                .TUSER_BITS         (TUSER_BITS     ),
                .TDATA_BITS         (TDATA_BITS     ),
                .ADDR_BITS          (ADDR_BITS      ),
                .MEM_DEPTH          (MEM_DEPTH      ),
                .RAM_TYPE           (RAM_TYPE       ),
                .FILLMEM_DATA       (FILLMEM_DATA   ),
                .M_SLAVE_REG        (M_SLAVE_REG    ),
                .M_MASTER_REG       (M_MASTER_REG   )
            )
        u_video_tbl_modulator_core
            (
                .aresetn            (aresetn        ),
                .aclk               (aclk           ),
                .aclken             (aclken         ),
                
                .param_end          (reg_param_end  ),
                .param_inv          (reg_param_inv  ),
                
                .wr_clk             (s_axi4l.aclk   ),
                .wr_en              (wr_en          ),
                .wr_addr            (wr_addr        ),
                .wr_din             (wr_din         ),
                
                .s_axi4s_tuser      (s_axi4s_tuser  ),
                .s_axi4s_tlast      (s_axi4s_tlast  ),
                .s_axi4s_tdata      (s_axi4s_tdata  ),
                .s_axi4s_tvalid     (s_axi4s_tvalid ),
                .s_axi4s_tready     (s_axi4s_tready ),
                
                .m_axi4s_tuser      (m_axi4s_tuser  ),
                .m_axi4s_tlast      (m_axi4s_tlast  ),
                .m_axi4s_tdata      (m_axi4s_tdata  ),
                .m_axi4s_tbinary    (m_axi4s_tbinary),
                .m_axi4s_tvalid     (m_axi4s_tvalid ),
                .m_axi4s_tready     (m_axi4s_tready )
            );
    
endmodule

`default_nettype wire

// end of file
