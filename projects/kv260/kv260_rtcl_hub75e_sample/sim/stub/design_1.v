`timescale 1 ps / 1 ps

module design_1
   (fan_en,
    m_axi4_aclk,
    m_axi4_araddr,
    m_axi4_arburst,
    m_axi4_arcache,
    m_axi4_aresetn,
    m_axi4_arid,
    m_axi4_arlen,
    m_axi4_arlock,
    m_axi4_arprot,
    m_axi4_arqos,
    m_axi4_arready,
    m_axi4_arsize,
    m_axi4_aruser,
    m_axi4_arvalid,
    m_axi4_awaddr,
    m_axi4_awburst,
    m_axi4_awcache,
    m_axi4_awid,
    m_axi4_awlen,
    m_axi4_awlock,
    m_axi4_awprot,
    m_axi4_awqos,
    m_axi4_awready,
    m_axi4_awsize,
    m_axi4_awuser,
    m_axi4_awvalid,
    m_axi4_bid,
    m_axi4_bready,
    m_axi4_bresp,
    m_axi4_bvalid,
    m_axi4_rdata,
    m_axi4_rid,
    m_axi4_rlast,
    m_axi4_rready,
    m_axi4_rresp,
    m_axi4_rvalid,
    m_axi4_wdata,
    m_axi4_wlast,
    m_axi4_wready,
    m_axi4_wstrb,
    m_axi4_wvalid,
    m_axi4l_aclk,
    m_axi4l_araddr,
    m_axi4l_aresetn,
    m_axi4l_arprot,
    m_axi4l_arready,
    m_axi4l_arvalid,
    m_axi4l_awaddr,
    m_axi4l_awprot,
    m_axi4l_awready,
    m_axi4l_awvalid,
    m_axi4l_bready,
    m_axi4l_bresp,
    m_axi4l_bvalid,
    m_axi4l_rdata,
    m_axi4l_rready,
    m_axi4l_rresp,
    m_axi4l_rvalid,
    m_axi4l_wdata,
    m_axi4l_wready,
    m_axi4l_wstrb,
    m_axi4l_wvalid,
    out_clk100,
    out_clk200,
    out_clk50,
    out_reset);
  output [0:0]fan_en;
  output m_axi4_aclk;
  output [39:0]m_axi4_araddr;
  output [1:0]m_axi4_arburst;
  output [3:0]m_axi4_arcache;
  output [0:0]m_axi4_aresetn;
  output [15:0]m_axi4_arid;
  output [7:0]m_axi4_arlen;
  output m_axi4_arlock;
  output [2:0]m_axi4_arprot;
  output [3:0]m_axi4_arqos;
  input m_axi4_arready;
  output [2:0]m_axi4_arsize;
  output [15:0]m_axi4_aruser;
  output m_axi4_arvalid;
  output [39:0]m_axi4_awaddr;
  output [1:0]m_axi4_awburst;
  output [3:0]m_axi4_awcache;
  output [15:0]m_axi4_awid;
  output [7:0]m_axi4_awlen;
  output m_axi4_awlock;
  output [2:0]m_axi4_awprot;
  output [3:0]m_axi4_awqos;
  input m_axi4_awready;
  output [2:0]m_axi4_awsize;
  output [15:0]m_axi4_awuser;
  output m_axi4_awvalid;
  input [15:0]m_axi4_bid;
  output m_axi4_bready;
  input [1:0]m_axi4_bresp;
  input m_axi4_bvalid;
  input [31:0]m_axi4_rdata;
  input [15:0]m_axi4_rid;
  input m_axi4_rlast;
  output m_axi4_rready;
  input [1:0]m_axi4_rresp;
  input m_axi4_rvalid;
  output [31:0]m_axi4_wdata;
  output m_axi4_wlast;
  input m_axi4_wready;
  output [3:0]m_axi4_wstrb;
  output m_axi4_wvalid;
  output m_axi4l_aclk;
  output [39:0]m_axi4l_araddr;
  output [0:0]m_axi4l_aresetn;
  output [2:0]m_axi4l_arprot;
  input m_axi4l_arready;
  output m_axi4l_arvalid;
  output [39:0]m_axi4l_awaddr;
  output [2:0]m_axi4l_awprot;
  input m_axi4l_awready;
  output m_axi4l_awvalid;
  output m_axi4l_bready;
  input [1:0]m_axi4l_bresp;
  input m_axi4l_bvalid;
  input [63:0]m_axi4l_rdata;
  output m_axi4l_rready;
  input [1:0]m_axi4l_rresp;
  input m_axi4l_rvalid;
  output [63:0]m_axi4l_wdata;
  input m_axi4l_wready;
  output [7:0]m_axi4l_wstrb;
  output m_axi4l_wvalid;
  output out_clk100;
  output out_clk200;
  output out_clk50;
  output [0:0]out_reset;


endmodule
