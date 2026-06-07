
`default_nettype none

module rtcl_tp25k_usb3_fifo_sample
        (
            input   var logic           in_clk50        ,

            output  var logic           ft601_reset_n   ,
            inout   tri logic           ft601_wakeup_n  ,
            input   var logic           ft601_clk       ,
            input   var logic           ft601_rxf_n     ,
            input   var logic           ft601_txe_n     ,
            output  var logic           ft601_siwu_n    ,
            output  var logic           ft601_wr_n      ,
            output  var logic           ft601_rd_n      ,
            output  var logic           ft601_oe_n      ,
            inout   tri logic   [3:0]   ft601_be        ,   
            inout   tri logic   [31:0]  ft601_data      ,
            inout   tri logic   [1:0]   ft601_gpio      ,

            input   var logic   [1:0]   push_sw         ,
            input   var logic   [1:0]   dip_sw          ,
            output  var logic   [3:0]   led             ,
            output  var logic   [7:0]   pmod            
        );
    
    logic in_reset;
    assign in_reset = push_sw[0];

    logic           reset = 1'b1;
    logic   [7:0]   reset_count = '0;
    always_ff @(posedge in_clk50 or posedge in_reset) begin
        if ( in_reset ) begin
            reset       <= 1'b1;
            reset_count <= '1;
        end
        else begin
            if ( reset_count > 0 ) begin
                reset_count <= reset_count - 1'b1;
            end
            reset <= reset_count != 0;
        end
    end

    logic ft601_rx_clk       ;
    logic ft601_tx_clk      ;
    logic ft601_pll_locked  ;

    ft601_pll
        u_ft601_pll
            (
                .reset      (reset              ),
                .mdclk      (in_clk50           ),
                .clkin      (ft601_clk          ),
                .pllpwd     (1'b0               ),
                .clkout0    (ft601_rx_clk       ),
                .clkout1    (ft601_tx_clk       ),
                .lock       (ft601_pll_locked   )
            );

//    assign ft601_rx_clk = ft601_clk;
//    assign ft601_tx_clk = ~ft601_clk;


    logic   [24:0]  clk_counter;
    always_ff @(posedge in_clk50) begin
        clk_counter <= clk_counter + 1'b1;
    end

    logic   [26:0]  usb_counter;
    always_ff @(posedge ft601_rx_clk) begin
        usb_counter <= usb_counter + 1'b1;
    end

    logic   [26:0]  usb_counter90;
    always_ff @(posedge ft601_tx_clk) begin
        usb_counter90 <= usb_counter90 + 1'b1;
    end


    assign led[0] = clk_counter[24];
    assign led[1] = usb_counter[26];
    assign led[2] = ft601_wakeup_n;
    assign led[3] = usb_counter90[26];




    assign ft601_reset_n  = ~reset  ;
    assign ft601_wakeup_n = 1'bz    ;
    assign ft601_gpio     = 2'b00   ;
    assign ft601_siwu_n   = 1'b1   ;
 
    logic   [3:0]   ft601_be_i          ;
    logic   [3:0]   reg_ft601_be_o = '0 ;
    logic   [3:0]   reg_ft601_be_t = '1 ;
    for (genvar i = 0; i < 4; i++) begin : iob_be
        IOBUF
            u_iobuf_be
                (
                    .O  (ft601_be_i    [i]),
                    .IO (ft601_be      [i]),
                    .I  (reg_ft601_be_o[i]),
                    .OEN(reg_ft601_be_t[i])
                );
    end

    logic   [31:0]  ft601_data_i            ;
    logic   [31:0]  reg_ft601_data_o  = '0  ;
    logic   [31:0]  reg_ft601_data_t  = '1  ;
    for (genvar i = 0; i < 32; i++) begin : iob_data
        IOBUF
            u_iobuf_data
                (
                    .O  (ft601_data_i    [i]),
                    .IO (ft601_data      [i]),
                    .I  (reg_ft601_data_o[i]),
                    .OEN(reg_ft601_data_t[i])
                );
    end

    logic           reg_ft601_rxf_n  = 1'b1 ;
    logic           reg_ft601_txe_n  = 1'b1 ;
    logic   [3:0]   reg_ft601_be_i   ;
    logic   [31:0]  reg_ft601_data_i ;
    always_ff @( posedge ft601_rx_clk or posedge reset) begin
        if ( reset ) begin
            reg_ft601_rxf_n  <= 1'b1  ;
            reg_ft601_txe_n  <= 1'b1  ;
        end
        else begin
            reg_ft601_rxf_n  <= ft601_rxf_n  ;
            reg_ft601_txe_n  <= ft601_txe_n  ;
        end
    end
    always_ff @( posedge ft601_rx_clk ) begin
        reg_ft601_be_i   <= ft601_be_i   ;
        reg_ft601_data_i <= ft601_data_i ;
    end

    typedef enum logic [2:0] {
        IDLE        ,
        READ_SETUP  ,
        READ_DATA   ,
        READ_END    ,
        WRITE       
    } state_t;


    state_t         state = IDLE;
    logic  [7:0]    write_count;


    logic   reg_ft601_wr_n = 1'b1   ;
    logic   reg_ft601_rd_n = 1'b1   ;
    logic   reg_ft601_oe_n = 1'b1   ;
    always_ff @( posedge ft601_tx_clk or posedge reset) begin
        if ( reset ) begin
            state <= IDLE;
            reg_ft601_wr_n   <= 1'b1;
            reg_ft601_rd_n   <= 1'b1;
            reg_ft601_oe_n   <= 1'b1;
            reg_ft601_be_o   <= '0  ;
            reg_ft601_be_t   <= '1  ;
            reg_ft601_data_o <= '0  ;
            reg_ft601_data_t <= '1  ;
        end
        else begin
            case ( state )
                IDLE:
                    begin
                        reg_ft601_wr_n   <= 1'b1;
                        reg_ft601_rd_n   <= 1'b1;
                        reg_ft601_oe_n   <= 1'b1;
                        reg_ft601_be_o   <= '0  ;
                        reg_ft601_be_t   <= '1  ;
                        reg_ft601_data_o <= '0  ;
                        reg_ft601_data_t <= '1  ;
                        if ( ~reg_ft601_rxf_n ) begin
                            state      <= READ_SETUP;
                            reg_ft601_oe_n <= 1'b0;
                        end
                    end

                READ_SETUP:
                    begin
                        state          <= READ_DATA;
                        reg_ft601_rd_n <= 1'b0;
                        reg_ft601_oe_n <= 1'b0;
                    end

                READ_DATA:
                    begin
                        if ( reg_ft601_rxf_n ) begin
                            state      <= READ_END;
                            reg_ft601_rd_n <= 1'b1;
                            reg_ft601_oe_n <= 1'b1;
                        end
                    end
                
                READ_END:
                    begin
//                      state <= IDLE;

                        state        <= WRITE;
                        write_count  <= 0;
                        reg_ft601_wr_n   <= 1'b0;
                        reg_ft601_be_t   <= '0;
                        reg_ft601_be_o   <= '1;
                        reg_ft601_data_t <= '0;
                        reg_ft601_data_o <= '1;
                    end

                WRITE:
                    begin
                        if ( ~reg_ft601_txe_n ) begin
                            write_count  <= write_count + 1'b1;
                            reg_ft601_data_o <= {4{write_count}};
                            if ( write_count == 8'hff ) begin
                                state <= IDLE;
                                reg_ft601_wr_n <= 1'b1;
                                reg_ft601_be_t   <= '1;
                                reg_ft601_be_o   <= '0;
                                reg_ft601_data_t <= '1;
                                reg_ft601_data_o <= '0;
                            end
                        end
                    end
            endcase
        end
    end

    assign ft601_wr_n = reg_ft601_wr_n   ;
    assign ft601_rd_n = reg_ft601_rd_n   ;
    assign ft601_oe_n = reg_ft601_oe_n   ;


    assign pmod[0] = ft601_rxf_n    ;
    assign pmod[1] = ft601_txe_n    ;
    assign pmod[2] = ft601_oe_n     ;
    assign pmod[3] = ft601_rd_n     ;
    assign pmod[4] = ft601_wr_n     ;
    assign pmod[5] = reg_ft601_rxf_n  ;
    assign pmod[6] = state == IDLE ;
    assign pmod[7] = reset   ;


//  assign pmod[7:5] = '0;//t601_data_i[15:12];

endmodule


`default_nettype wire
