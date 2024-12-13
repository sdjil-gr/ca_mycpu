//*************************************************************************
//   > File Name   : mycpu_top.v
//   > Description : included cpu_core, 1 x 2 axi_bridge,
//                   icache, dcache.
// 
//           -------------------------------
//           |           cpu_core          |
//           -------------------------------
//               | inst               | data
//               |                    | 
//         --------------       --------------
//         |   icache   |       |   dcache   |
//         --------------       --------------
//               |                    |           
//               |                    |           
//         -----------------------------------
//         |          axi_2x1_bridge         |
//         -----------------------------------
//                          |
//                          | axi interface
//                          |
//
//   > Author      : Sun Guangrun (group18)
//   > Date        : 2024-12-5
//*************************************************************************

module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    //ar
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,
    //r
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    //aw
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,
    //w
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    //b
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,
    
    //debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

// cpu interface
wire        inst_valid;
wire        inst_op;
wire [19:0] inst_tag;
wire [ 7:0] inst_index;
wire [ 3:0] inst_offset;
wire        inst_mat;
wire        inst_CACOP;
wire  [4:0] code;
wire  [31:0]CACOP_VPPN;
wire [ 3:0] inst_wstrb = 4'b1111;
wire [31:0] inst_wdata = 32'h0;
wire        inst_addr_ok;
wire        inst_data_ok;
wire [31:0] inst_rdata;

wire        data_valid;
wire        data_op;
wire [19:0] data_tag;
wire [ 7:0] data_index;
wire [ 3:0] data_offset;
wire        data_mat;
wire [ 3:0] data_wstrb;
wire [31:0] data_wdata;
wire        data_addr_ok;
wire        data_data_ok;
wire [31:0] data_rdata;

cpu_core u_cpu_core (
    .clk(aclk),
    .resetn(aresetn),

    .inst_valid(inst_valid),
    .inst_op(inst_op),
    .inst_tag(inst_tag),
    .inst_index(inst_index),
    .inst_offset(inst_offset),
    .inst_mat(inst_mat),
    .inst_CACOP(inst_CACOP),
    .code(code),
    .CACOP_VPPN(CACOP_VPPN),
    // .inst_wsttb(inst_wsttb),
    // .inst_wdata(inst_wdata),
    .inst_addr_ok(inst_addr_ok),
    .inst_data_ok(inst_data_ok),
    .inst_rdata(inst_rdata),

    .data_valid(data_valid),
    .data_op(data_op),
    .data_tag(data_tag),
    .data_index(data_index),
    .data_offset(data_offset),
    .data_mat(data_mat),
    .data_wstrb(data_wstrb),
    .data_wdata(data_wdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),
    .data_rdata(data_rdata),

    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// icache interface
wire        inst_rd_req;
wire [ 2:0] inst_rd_type;
wire [31:0] inst_rd_addr;
wire        inst_rd_rdy;
wire        inst_ret_valid;
wire        inst_ret_last;
wire [31:0] inst_ret_data;

wire        inst_wr_req;
wire [ 2:0] inst_wr_type;
wire [31:0] inst_wr_addr;
wire [ 3:0] inst_wr_wstrb;
wire [127:0] inst_wr_data;
wire        inst_wr_rdy = 1'b1;
wire        inst_CACOP1;
wire        inst_CACOP2;
assign inst_CACOP1 = inst_CACOP&&code[2:0]==0;
assign inst_CACOP2 = inst_CACOP&&code[2:0]==1;
cache u_icache (
    .clk(aclk),
    .resetn(aresetn),

    .valid(inst_valid),
    .op(inst_op),
    .mat(inst_mat),
    .tag(inst_tag),
    .index(inst_index),
    .offset(inst_offset),
    .wstrb(inst_wstrb),
    .wdata(inst_wdata),
    .addr_ok(inst_addr_ok),
    .data_ok(inst_data_ok),
    .rdata(inst_rdata),

    .rd_req(inst_rd_req),
    .rd_type(inst_rd_type),
    .rd_addr(inst_rd_addr),
    .rd_rdy(inst_rd_rdy),
    .ret_valid(inst_ret_valid),
    .ret_last(inst_ret_last),
    .ret_data(inst_ret_data),

    .wr_req(inst_wr_req),
    .wr_type(inst_wr_type),
    .wr_addr(inst_wr_addr),
    .wr_wstrb(inst_wr_wstrb),
    .wr_data(inst_wr_data),
    .wr_rdy(inst_wr_rdy),

    .inst_CACOP(inst_CACOP1),
    .code(code),
    .CACOP_VPPN(CACOP_VPPN)
);

// dcache interface
wire        data_rd_req;
wire [ 2:0] data_rd_type;
wire [31:0] data_rd_addr;
wire        data_rd_rdy;
wire        data_ret_valid;
wire        data_ret_last;
wire [31:0] data_ret_data;

wire        data_wr_req;
wire [ 2:0] data_wr_type;
wire [31:0] data_wr_addr;
wire [ 3:0] data_wr_wstrb;
wire [127:0] data_wr_data;
wire        data_wr_rdy;

cache u_dcache (
    .clk(aclk),
    .resetn(aresetn),

    .valid(data_valid),
    .op(data_op),
    .mat(data_mat),
    .tag(data_tag),
    .index(data_index),
    .offset(data_offset),
    .wstrb(data_wstrb),
    .wdata(data_wdata),
    .addr_ok(data_addr_ok),
    .data_ok(data_data_ok),
    .rdata(data_rdata),

    .rd_req(data_rd_req),
    .rd_type(data_rd_type),
    .rd_addr(data_rd_addr),
    .rd_rdy(data_rd_rdy),
    .ret_valid(data_ret_valid),
    .ret_last(data_ret_last),
    .ret_data(data_ret_data),

    .wr_req(data_wr_req),
    .wr_type(data_wr_type),
    .wr_addr(data_wr_addr),
    .wr_wstrb(data_wr_wstrb),
    .wr_data(data_wr_data),
    .wr_rdy(data_wr_rdy),

    .inst_CACOP(inst_CACOP2),
    .code(code),
    .CACOP_VPPN(CACOP_VPPN)
);



axi_2x1_bridge u_axi_2x1_bridge (
    .clk(aclk),
    .resetn(aresetn),

    .rd_req0(inst_rd_req),
    .rd_type0(inst_rd_type),
    .rd_addr0(inst_rd_addr),
    .rd_rdy0(inst_rd_rdy),
    .ret_valid0(inst_ret_valid),
    .ret_last0(inst_ret_last),
    .ret_data0(inst_ret_data),

    // .wr_req0(inst_wr_req),
    // .wr_type0(inst_wr_type),
    // .wr_addr0(inst_wr_addr),
    // .wr_wstrb0(inst_wr_wstrb),
    // .wr_data0(inst_wr_data),
    // .wr_rdy0(inst_wr_rdy),

    .rd_req1(data_rd_req),
    .rd_type1(data_rd_type),
    .rd_addr1(data_rd_addr),
    .rd_rdy1(data_rd_rdy),
    .ret_valid1(data_ret_valid),
    .ret_last1(data_ret_last),
    .ret_data1(data_ret_data),

    .wr_req1(data_wr_req),
    .wr_type1(data_wr_type),
    .wr_addr1(data_wr_addr),
    .wr_wstrb1(data_wr_wstrb),
    .wr_data1(data_wr_data),
    .wr_rdy1(data_wr_rdy),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

endmodule