module mnist_seg
        #(
            parameter   TUSER_WIDTH    = 1,
            parameter   IMG_X_WIDTH    = 10,
            parameter   IMG_Y_WIDTH    = 9,
            parameter   IMG_Y_NUM      = 480,
            parameter   MAX_X_NUM      = 1024,
            parameter   BLANK_Y_WIDTH  = 8,
            parameter   INIT_Y_NUM     = IMG_Y_NUM,
            parameter   FIFO_PTR_WIDTH = 9,
            parameter   FIFO_RAM_TYPE  = "block",
            parameter   RAM_TYPE       = "block",
            parameter   IMG_CKE_BUFG   = 0,
            parameter   DEVICE         = "rtl",
            parameter   S_TDATA_WIDTH  = 1,
            parameter   M_TDATA_WIDTH  = 11
        )
        (
            input   wire                                reset,
            input   wire                                clk,
            
            input   wire    [BLANK_Y_WIDTH-1:0]         param_blank_num,
            
            input   wire    [TUSER_WIDTH-1:0]           s_axi4s_tuser,
            input   wire                                s_axi4s_tlast,
            input   wire    [S_TDATA_WIDTH-1:0]         s_axi4s_tdata,
            input   wire                                s_axi4s_tvalid,
            output  wire                                s_axi4s_tready,
            
            output  wire    [TUSER_WIDTH-1:0]           m_axi4s_tuser,
            output  wire                                m_axi4s_tlast,
            output  wire    [M_TDATA_WIDTH-1:0]         m_axi4s_tdata,
            output  wire                                m_axi4s_tvalid,
            input   wire                                m_axi4s_tready
        );

    assign m_axi4s_tuser  = s_axi4s_tuser   ;
    assign m_axi4s_tlast  = s_axi4s_tlast   ;
    assign m_axi4s_tdata  = M_TDATA_WIDTH'(s_axi4s_tdata);
    assign m_axi4s_tvalid = s_axi4s_tvalid  ;
    assign s_axi4s_tready = m_axi4s_tready  ;

endmodule
