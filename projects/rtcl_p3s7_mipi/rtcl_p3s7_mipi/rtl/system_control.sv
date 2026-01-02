// ---------------------------------------------------------------------------
//  Real-time Computing Lab   PYTHON300 + Spartan-7 MIPI Camera
//
//  Copyright (C) 2025 Ryuji Fuchikami. All Rights Reserved.
//  https://rtc-lab.com/
// ---------------------------------------------------------------------------


`timescale 1ns / 1ps
`default_nettype none


module system_control
        #(
            parameter   int             REGADR_BITS              = 8                        ,
            parameter   type            regadr_t                 = logic [REGADR_BITS-1:0]  ,
  
            parameter   bit [15:0]      MODULE_ID                = 16'h5254                 ,
            parameter   bit [15:0]      MODULE_VERSION           = 16'h0100                 ,
            parameter   bit [15:0]      MODULE_CONFIG            = 16'h0000                 ,
            parameter   bit             INIT_SENSOR_ENABLE       = 1'b0                     ,
            parameter   bit             INIT_SENSOR_PGOOD_EN     = 1'b1                     ,
            parameter   bit             INIT_RECEIVER_RESET      = 1'b1                     ,
            parameter   bit [4:0]       INIT_RECEIVER_CLK_DLY    = 5'd8                     ,
            parameter   bit             INIT_ALIGN_RESET         = 1'b1                     ,
            parameter   bit [9:0]       INIT_ALIGN_PATTERN       = 10'h3a6                  ,
            parameter   bit             INIT_CLIP_ENABLE         = 1'b1                     ,
            parameter   bit             INIT_CSI_MODE            = 1'b0                     ,
            parameter   bit [7:0]       INIT_CSI_DT              = 8'h2b                    ,
            parameter   bit [15:0]      INIT_CSI_WC              = 16'(256*5/4)             ,
            parameter   bit             INIT_DPHY_CORE_RESET     = 1'b1                     ,
            parameter   bit             INIT_DPHY_SYS_RESET      = 1'b1                     ,
            parameter   bit [1:0]       INIT_MMCM_CONTROL        = 2'b00                    ,
            parameter   bit [1:0]       INIT_PLL_CONTROL         = 2'b00                    
        )
        (
            jelly3_axi4l_if.s           s_axi4l             ,

            input   var logic           in_ext_reset        ,
            output  var logic           out_sw_reset        ,

            output  var logic           out_sensor_enable   ,
            input   var logic           in_sensor_ready     ,
            input   var logic           in_sensor_pgood     ,
            output  var logic           out_sensor_pgood_en ,
            output  var logic           out_receiver_reset  ,
            output  var logic   [4:0]   out_receiver_clk_dly,
            output  var logic           out_align_reset     ,
            output  var logic   [9:0]   out_align_pattern   ,
            input   var logic           in_align_done       ,
            input   var logic           in_align_error      ,
            output  var logic           out_clip_enable     ,
            output  var logic           out_csi_mode        ,
            output  var logic   [7:0]   out_csi_dt          ,
            output  var logic   [15:0]  out_csi_wc          ,
            output  var logic           out_dphy_core_reset ,
            output  var logic           out_dphy_sys_reset  ,
            input   var logic           in_dphy_init_done   ,
            output  var logic           out_mmcm_rst        ,
            output  var logic           out_mmcm_pwrdwn     ,
            output  var logic           out_pll_rst         ,
            output  var logic           out_pll_pwrdwn      
        );
    
    
    // -------------------------------------
    //  registers domain
    // -------------------------------------

    // type
    localparam type axi4l_addr_t = logic [$bits(s_axi4l.awaddr)-1:0];
    localparam type axi4l_data_t = logic [$bits(s_axi4l.wdata)-1:0];
    localparam type axi4l_strb_t = logic [$bits(s_axi4l.wstrb)-1:0];

    // register address offset
    localparam  regadr_t REGADR_MODULE_ID           = regadr_t'('h00);
    localparam  regadr_t REGADR_MODULE_VERSION      = regadr_t'('h01);
    localparam  regadr_t REGADR_MODULE_CONFIG       = regadr_t'('h02);
    localparam  regadr_t REGADR_SW_RESET            = regadr_t'('h03);
    localparam  regadr_t REGADR_SENSOR_ENABLE       = regadr_t'('h04);
    localparam  regadr_t REGADR_SENSOR_READY        = regadr_t'('h08);
    localparam  regadr_t REGADR_SENSOR_PGOOD        = regadr_t'('h0c);
    localparam  regadr_t REGADR_SENSOR_PGOOD_EN     = regadr_t'('h0d);
    localparam  regadr_t REGADR_RECEIVER_RESET      = regadr_t'('h10);
    localparam  regadr_t REGADR_RECEIVER_CLK_DLY    = regadr_t'('h12);
    localparam  regadr_t REGADR_ALIGN_RESET         = regadr_t'('h20);
    localparam  regadr_t REGADR_ALIGN_PATTERN       = regadr_t'('h22);
    localparam  regadr_t REGADR_ALIGN_STATUS        = regadr_t'('h28);
    localparam  regadr_t REGADR_CLIP_ENABLE         = regadr_t'('h40);
    localparam  regadr_t REGADR_CSI_MODE            = regadr_t'('h50);
    localparam  regadr_t REGADR_CSI_DT              = regadr_t'('h52);
    localparam  regadr_t REGADR_CSI_WC              = regadr_t'('h53);
    localparam  regadr_t REGADR_DPHY_CORE_RESET     = regadr_t'('h80);
    localparam  regadr_t REGADR_DPHY_SYS_RESET      = regadr_t'('h81);
    localparam  regadr_t REGADR_DPHY_INIT_DONE      = regadr_t'('h88);
    localparam  regadr_t REGADR_MMCM_CONTROL        = regadr_t'('ha0);
    localparam  regadr_t REGADR_PLL_CONTROL         = regadr_t'('ha1);

    // registers
    logic           reg_sensor_enable       ;
    logic           reg_sensor_ready        ;
    logic           reg_sensor_pgood        ;
    logic           reg_sensor_pgood_en     ;
    logic           reg_receiver_reset      ;
    logic   [4:0]   reg_receiver_clk_dly    ;
    logic           reg_align_reset         ;
    logic   [9:0]   reg_align_pattern       ;
    logic   [1:0]   reg_align_status        ;
    logic           reg_clip_enable         ;
    logic           reg_csi_mode            ;
    logic   [7:0]   reg_csi_dt              ;
    logic   [15:0]  reg_csi_wc              ;
    logic           reg_dphy_core_reset     ;
    logic           reg_dphy_sys_reset      ;
    logic           reg_dphy_init_done      ;
    logic   [1:0]   reg_mmcm_control        ;
    logic   [1:0]   reg_pll_control         ;

    always_ff @(posedge s_axi4l.aclk) begin
        reg_sensor_ready   <= in_sensor_ready                   ;
        reg_sensor_pgood   <= in_sensor_pgood                   ;
        reg_align_status   <= {in_align_error, in_align_done}   ;
        reg_dphy_init_done <= in_dphy_init_done                 ;
    end

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

    // Software reset
    logic           sw_reset        ;
    logic   [5:0]   sw_reset_count  ;
    always_ff @(posedge s_axi4l.aclk) begin
        if ( in_ext_reset ) begin
            sw_reset_count <= '0;
            sw_reset       <= 1'b1;
        end
        else begin
            if ( sw_reset_count != '1 ) begin
                sw_reset_count <= sw_reset_count + 1;
            end
            else begin
                sw_reset       <= 1'b0;
                if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                    if ( regadr_write == REGADR_SW_RESET && s_axi4l.wdata[0] && s_axi4l.wstrb[0] ) begin
                        sw_reset_count <= '0;
                        sw_reset       <=  1'b1;
                    end
                end
            end
        end
    end

    // write
    always_ff @(posedge s_axi4l.aclk) begin
        if ( ~s_axi4l.aresetn ) begin
            reg_sensor_enable    <= INIT_SENSOR_ENABLE   ;
            reg_sensor_pgood_en  <= INIT_SENSOR_PGOOD_EN ;
            reg_receiver_reset   <= INIT_RECEIVER_RESET  ;
            reg_receiver_clk_dly <= INIT_RECEIVER_CLK_DLY;
            reg_align_reset      <= INIT_ALIGN_RESET     ;
            reg_align_pattern    <= INIT_ALIGN_PATTERN   ;
            reg_clip_enable      <= INIT_CLIP_ENABLE     ;
            reg_csi_mode         <= INIT_CSI_MODE        ;
            reg_csi_dt           <= INIT_CSI_DT          ;
            reg_csi_wc           <= INIT_CSI_WC          ;
            reg_dphy_core_reset  <= INIT_DPHY_CORE_RESET ;
            reg_dphy_sys_reset   <= INIT_DPHY_SYS_RESET  ;
            reg_mmcm_control     <= INIT_MMCM_CONTROL    ;
            reg_pll_control      <= INIT_PLL_CONTROL     ;
        end
        else if ( s_axi4l.aclken ) begin
            if ( s_axi4l.awvalid && s_axi4l.awready && s_axi4l.wvalid && s_axi4l.wready ) begin
                case ( regadr_write )
                REGADR_SENSOR_ENABLE      :   reg_sensor_enable    <=  1'(write_mask(axi4l_data_t'(reg_sensor_enable   ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_SENSOR_PGOOD_EN    :   reg_sensor_pgood_en  <=  1'(write_mask(axi4l_data_t'(reg_sensor_pgood_en ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_RECEIVER_RESET     :   reg_receiver_reset   <=  1'(write_mask(axi4l_data_t'(reg_receiver_reset  ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_RECEIVER_CLK_DLY   :   reg_receiver_clk_dly <=  5'(write_mask(axi4l_data_t'(reg_receiver_clk_dly), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_ALIGN_RESET        :   reg_align_reset      <=  1'(write_mask(axi4l_data_t'(reg_align_reset     ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_ALIGN_PATTERN      :   reg_align_pattern    <= 10'(write_mask(axi4l_data_t'(reg_align_pattern   ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_CLIP_ENABLE        :   reg_clip_enable      <=  1'(write_mask(axi4l_data_t'(reg_clip_enable     ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_CSI_MODE           :   reg_csi_mode         <=  1'(write_mask(axi4l_data_t'(reg_csi_mode        ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_CSI_DT             :   reg_csi_dt           <=  8'(write_mask(axi4l_data_t'(reg_csi_dt          ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_CSI_WC             :   reg_csi_wc           <= 16'(write_mask(axi4l_data_t'(reg_csi_wc          ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_DPHY_CORE_RESET    :   reg_dphy_core_reset  <=  1'(write_mask(axi4l_data_t'(reg_dphy_core_reset ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_DPHY_SYS_RESET     :   reg_dphy_sys_reset   <=  1'(write_mask(axi4l_data_t'(reg_dphy_sys_reset  ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_MMCM_CONTROL       :   reg_mmcm_control     <=  2'(write_mask(axi4l_data_t'(reg_mmcm_control    ), s_axi4l.wdata, s_axi4l.wstrb));
                REGADR_PLL_CONTROL        :   reg_pll_control      <=  2'(write_mask(axi4l_data_t'(reg_pll_control     ), s_axi4l.wdata, s_axi4l.wstrb));
                default: ;
                endcase
            end

            // PGOOD 監視中に PGOODが落ちたら enable も倒す
            if ( reg_sensor_pgood_en && !reg_sensor_pgood ) begin
                reg_sensor_enable <= 1'b0;
            end
        end
    end

    always_ff @(posedge s_axi4l.aclk ) begin
        if ( ~s_axi4l.aresetn ) begin
            s_axi4l.bvalid <= 0;
        end
        else if ( s_axi4l.aclken ) begin
            if ( s_axi4l.bready ) begin
                s_axi4l.bvalid <= 0;
            end
            if ( s_axi4l.awvalid && s_axi4l.awready ) begin
                s_axi4l.bvalid <= 1'b1;
            end
        end
    end

    assign s_axi4l.awready = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.wvalid;
    assign s_axi4l.wready  = (~s_axi4l.bvalid || s_axi4l.bready) && s_axi4l.awvalid;
    assign s_axi4l.bresp   = '0;


    // read
    always_ff @(posedge s_axi4l.aclk ) begin
        if ( s_axi4l.aclken ) begin
            if ( s_axi4l.arvalid && s_axi4l.arready ) begin
                case ( regadr_read )
                REGADR_MODULE_ID        :   s_axi4l.rdata <= axi4l_data_t'(MODULE_ID           );
                REGADR_MODULE_VERSION   :   s_axi4l.rdata <= axi4l_data_t'(MODULE_VERSION      );
                REGADR_MODULE_CONFIG    :   s_axi4l.rdata <= axi4l_data_t'(MODULE_CONFIG       );
                REGADR_SW_RESET         :   s_axi4l.rdata <= axi4l_data_t'(sw_reset            );
                REGADR_SENSOR_ENABLE    :   s_axi4l.rdata <= axi4l_data_t'(reg_sensor_enable   );
                REGADR_SENSOR_READY     :   s_axi4l.rdata <= axi4l_data_t'(reg_sensor_ready    );
                REGADR_SENSOR_PGOOD     :   s_axi4l.rdata <= axi4l_data_t'(reg_sensor_pgood    );
                REGADR_SENSOR_PGOOD_EN  :   s_axi4l.rdata <= axi4l_data_t'(reg_sensor_pgood_en );
                REGADR_RECEIVER_RESET   :   s_axi4l.rdata <= axi4l_data_t'(reg_receiver_reset  );
                REGADR_RECEIVER_CLK_DLY :   s_axi4l.rdata <= axi4l_data_t'(reg_receiver_clk_dly);
                REGADR_ALIGN_RESET      :   s_axi4l.rdata <= axi4l_data_t'(reg_align_reset     );
                REGADR_ALIGN_PATTERN    :   s_axi4l.rdata <= axi4l_data_t'(reg_align_pattern   );
                REGADR_ALIGN_STATUS     :   s_axi4l.rdata <= axi4l_data_t'(reg_align_status    );
                REGADR_CLIP_ENABLE      :   s_axi4l.rdata <= axi4l_data_t'(reg_clip_enable     );
                REGADR_CSI_MODE         :   s_axi4l.rdata <= axi4l_data_t'(reg_csi_mode        );
                REGADR_CSI_DT           :   s_axi4l.rdata <= axi4l_data_t'(reg_csi_dt          );
                REGADR_CSI_WC           :   s_axi4l.rdata <= axi4l_data_t'(reg_csi_wc          );
                REGADR_DPHY_CORE_RESET  :   s_axi4l.rdata <= axi4l_data_t'(reg_dphy_core_reset );
                REGADR_DPHY_SYS_RESET   :   s_axi4l.rdata <= axi4l_data_t'(reg_dphy_sys_reset  );
                REGADR_DPHY_INIT_DONE   :   s_axi4l.rdata <= axi4l_data_t'(reg_dphy_init_done  );
                REGADR_MMCM_CONTROL     :   s_axi4l.rdata <= axi4l_data_t'(reg_mmcm_control    );
                REGADR_PLL_CONTROL      :   s_axi4l.rdata <= axi4l_data_t'(reg_pll_control     );
                default                 :   s_axi4l.rdata <= '0;
                endcase
            end
        end
    end

    logic           axi4l_rvalid;
    always_ff @(posedge s_axi4l.aclk ) begin
        if ( ~s_axi4l.aresetn ) begin
            s_axi4l.rvalid <= 1'b0;
        end
        else if ( s_axi4l.aclken ) begin
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


    // output
    assign  out_sw_reset         = sw_reset              ;
    assign  out_sensor_enable    = reg_sensor_enable     ;
    assign  out_sensor_pgood_en  = reg_sensor_pgood_en   ;
    assign  out_receiver_reset   = reg_receiver_reset    ;
    assign  out_receiver_clk_dly = reg_receiver_clk_dly  ;
    assign  out_align_reset      = reg_align_reset       ;
    assign  out_align_pattern    = reg_align_pattern     ;
    assign  out_clip_enable      = reg_clip_enable       ;
    assign  out_csi_mode         = reg_csi_mode          ;
    assign  out_csi_dt           = reg_csi_dt            ;
    assign  out_csi_wc           = reg_csi_wc            ;
    assign  out_dphy_core_reset  = reg_dphy_core_reset   ;
    assign  out_dphy_sys_reset   = reg_dphy_sys_reset    ;
    assign  out_mmcm_rst         = reg_mmcm_control[0]   ;
    assign  out_mmcm_pwrdwn      = reg_mmcm_control[1]   ;
    assign  out_pll_rst          = reg_pll_control[0]    ;
    assign  out_pll_pwrdwn       = reg_pll_control[1]    ;
    
endmodule


`default_nettype wire


// end of file
