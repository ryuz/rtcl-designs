

`timescale 1ns / 1ps
`default_nettype none


module video_lpf_ram
        #(
            parameter   int     NUM              = 11 + 3                   ,
            parameter   int     DATA_BITS        = 8                        ,
            parameter   type    data_t           = logic [DATA_BITS-1:0]    ,
            parameter   int     ADDR_BITS        = 17                       ,
            parameter   type    addr_t           = logic [ADDR_BITS-1:0]    ,
            parameter   int     MEM_SIZE         = (1 << ADDR_BITS)         ,
            parameter           RAM_TYPE         = "block"                  ,
            parameter   int     TUSER_BITS       = 1                        ,
            parameter   type    tuser_t          = logic [TUSER_BITS-1:0]   ,
            parameter   int     TDATA_BITS       = NUM * DATA_BITS          ,
            parameter   type    tdata_t          = logic [TDATA_BITS-1:0]   ,
            parameter   int     REGADR_BITS      = 8                        ,
            parameter   type    regadr_t         = logic [REGADR_BITS-1:0]  ,
            parameter   data_t  INIT_PARAM_ALPHA = '0                       
        )
        (
            jelly3_axi4l_if.s       s_axi4l         ,

            input   var logic       aresetn         ,
            input   var logic       aclk            ,

            input   var tuser_t     s_axi4s_tuser   ,
            input   var logic       s_axi4s_tlast   ,
            input   var tdata_t     s_axi4s_tdata   ,
            input   var logic       s_axi4s_tvalid  ,
            output  var logic       s_axi4s_tready  ,
            
            output  var tuser_t     m_axi4s_tuser   ,
            output  var logic       m_axi4s_tlast   ,
            output  var tdata_t     m_axi4s_tdata   ,
            output  var logic       m_axi4s_tvalid  ,
            input   var logic       m_axi4s_tready
        );


    // -------------------------------------
    //  registers domain
    // -------------------------------------

    localparam  type    axi4l_data_t = logic [s_axi4l.DATA_BITS-1:0];

    // register
    localparam  regadr_t    REGADR_CORE_ID      = regadr_t'('h00);
    localparam  regadr_t    REGADR_PARAM_ALPHA  = regadr_t'('h08);
    
    // registers
    data_t      reg_param_alpha;

    
    // shadow registers(core domain)
    data_t      core_param_alpha;

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
            reg_param_alpha   <= INIT_PARAM_ALPHA;
        end
        else begin
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_PARAM_ALPHA: reg_param_alpha <= data_t'(write_mask(axi4l_data_t'(reg_param_alpha  ), s_axi4l.wdata, s_axi4l.wstrb));
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
            REGADR_CORE_ID      :   s_axi4l.rdata <= axi4l_data_t'('h54561111       );
            REGADR_PARAM_ALPHA  :   s_axi4l.rdata <= axi4l_data_t'(reg_param_alpha  );
            default             :   s_axi4l.rdata <= '0;
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



    // -------------------------------------
    //  core domain
    // -------------------------------------

    always_ff @(posedge aclk) begin
        if ( !aresetn ) begin
            core_param_alpha <= INIT_PARAM_ALPHA;
        end
        else begin
            core_param_alpha <= reg_param_alpha;
        end
    end

    video_lpf_ram_core
            #(
                .NUM            (NUM            ),
                .DATA_BITS      (DATA_BITS      ),
                .ADDR_BITS      (ADDR_BITS      ),
                .MEM_SIZE       (MEM_SIZE       ),
                .RAM_TYPE       (RAM_TYPE       ),
                .TUSER_BITS     (TUSER_BITS     ),
                .TDATA_BITS     (TDATA_BITS     )
            )
        u_video_lpf_ram_core
            (
                .aresetn,
                .aclk,

                .param_alpha    (core_param_alpha),

                .s_axi4s_tuser,
                .s_axi4s_tlast,
                .s_axi4s_tdata,
                .s_axi4s_tvalid,
                .s_axi4s_tready,

                .m_axi4s_tuser,
                .m_axi4s_tlast,
                .m_axi4s_tdata,
                .m_axi4s_tvalid,
                .m_axi4s_tready
            );

endmodule



`default_nettype wire



// end of file
