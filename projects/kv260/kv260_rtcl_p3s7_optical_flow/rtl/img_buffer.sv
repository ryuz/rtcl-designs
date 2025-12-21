

`timescale 1ns / 1ps
`default_nettype none


module img_buffer
        #(
            parameter   int     BUF_SIZE     = 320 * 320    ,
            parameter           RAM_TYPE     = "ultra"      
        )
        (
            jelly3_mat_if.s     s_mat,
            jelly3_mat_if.m     m_mat
        );

    localparam  int     TAPS        = s_mat.TAPS                ;
    localparam  int     CH_BITS     = s_mat.CH_BITS             ;
    localparam  int     CH_DEPTH    = s_mat.CH_DEPTH            ;
    localparam  int     DE_BITS     = s_mat.DE_BITS             ;
    localparam  int     USER_BITS   = s_mat.USER_BITS           ;
    localparam  int     ROWS_BITS   = s_mat.ROWS_BITS           ;
    localparam  int     COLS_BITS   = s_mat.COLS_BITS           ;
    localparam  type    ch_t        = logic [CH_BITS-1:0]       ;
    localparam  type    data_t      = ch_t  [CH_DEPTH-1:0]      ;
    localparam  type    de_t        = logic [DE_BITS-1:0]       ;
    localparam  type    user_t      = logic [USER_BITS-1:0]     ;
    localparam  type    rows_t      = logic [ROWS_BITS-1:0]     ;
    localparam  type    cols_t      = logic [COLS_BITS-1:0]     ;

    localparam  int     M_CH_BITS   = m_mat.CH_BITS             ;
    localparam  int     M_CH_DEPTH  = m_mat.CH_DEPTH            ;
    localparam  int     M_DE_BITS   = m_mat.DE_BITS             ;
    localparam  int     M_USER_BITS = m_mat.USER_BITS           ;
    localparam  int     M_ROWS_BITS = m_mat.ROWS_BITS           ;
    localparam  int     M_COLS_BITS = m_mat.COLS_BITS           ;
    localparam  type    m_ch_t      = logic [M_CH_BITS-1:0]     ;
    localparam  type    m_data_t    = m_ch_t[M_CH_DEPTH-1:0]    ;
    localparam  type    m_de_t      = logic [M_DE_BITS-1:0]     ;
    localparam  type    m_user_t    = logic [M_USER_BITS-1:0]   ;
    localparam  type    m_rows_t    = logic [M_ROWS_BITS-1:0]   ;
    localparam  type    m_cols_t    = logic [M_COLS_BITS-1:0]   ;

    localparam  int     WORD_BITS  = 72 / $bits(data_t)
    localparam  int     ADDRL_BITS = 72 / 8;
    localparam  int     ADDRH_BITS = $clog2(BUF_SIZE)        ;
    localparam  type    addr_t    = logic   [ADDR_BITS-1:0] ;

    addr_t      st0_addr;

    // Simple Dualport-RAM
    jelly3_ram_simple_dualport
        #(
            parameter   int     ADDR_BITS    = 6                            ,
            parameter   int     WE_BITS      = 1                            ,
            parameter   type    we_t         = logic    [WE_BITS-1:0]       ,
            parameter   int     DATA_BITS    = 8                            ,
            parameter   type    data_t       = logic    [DATA_BITS-1:0]     ,
            parameter   int     WORD_BITS    = $bits(data_t) / $bits(we_t)  ,
            parameter   type    word_t       = logic    [WORD_BITS-1:0]     ,
            parameter   int     MEM_DEPTH    = 2 ** $bits(addr_t)           ,
            parameter           RAM_TYPE     = "distributed"                ,
            parameter   bit     DOUT_REG     = 1'b0                         ,
            parameter   bit     FILLMEM      = 1'b0                         ,
            parameter   data_t  FILLMEM_DATA = '0                           ,
            parameter   bit     READMEMB     = 1'b0                         ,
            parameter   bit     READMEMH     = 1'b0                         ,
            parameter           READMEM_FILE = ""                           ,
            parameter           DEVICE       = "RTL"                        ,
            parameter           SIMULATION   = "false"                      ,
            parameter           DEBUG        = "false"                      
        )
        (
            // write port
            input   var logic       wr_clk      ,
            input   var we_t        wr_en       ,
            input   var addr_t      wr_addr     ,
            input   var data_t      wr_din      ,
            
            // read port
            input   var logic       rd_clk      ,
            input   var logic       rd_en       ,
            input   var logic       rd_regcke   ,
            input   var addr_t      rd_addr     ,
            output  var data_t      rd_dout     
        );

    
endmodule

`default_nettype wire

// end of file
