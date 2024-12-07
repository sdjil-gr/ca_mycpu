
module axi_2x1_bridge(
    input  wire         clk,
    input  wire         resetn, 

    /* icache */
    //read
    input  wire         rd_req0,
    input  wire [  2:0] rd_type0,
    input  wire [ 31:0] rd_addr0,
    output wire         rd_rdy0,
    output wire         ret_valid0,
    output wire         ret_last0,
    output wire [ 31:0] ret_data0,

    /* dcache */
    //read
    input  wire         rd_req1,
    input  wire [  2:0] rd_type1,
    input  wire [ 31:0] rd_addr1,
    output wire         rd_rdy1,
    output wire         ret_valid1,
    output wire         ret_last1,
    output wire [ 31:0] ret_data1,
    //write
    input  wire         wr_req1,
    input  wire [  2:0] wr_type1,
    input  wire [ 31:0] wr_addr1,
    input  wire [  3:0] wr_wstrb1,
    input  wire [127:0] wr_data1,
    output wire         wr_rdy1,

    /* axi */
    //ar
    output wire [ 3:0] arid,// 0 for inst; 1 for data
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,// always 0
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,// always 2'b01
    output wire [ 1:0] arlock,// always 2'b0
    output wire [ 3:0] arcache,// always 4'b0
    output wire [ 2:0] arprot,// always 3'b0
    output wire        arvalid,
    input  wire        arready,
    //r
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,//ignore
    input  wire        rlast,//ignore
    input  wire        rvalid,
    output wire        rready,
    //aw
    output wire [ 3:0] awid,// always 4'b1
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,// always 0
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,// always 2'b01
    output wire [ 1:0] awlock,// always 2'b0
    output wire [ 3:0] awcache,// always 4'b0
    output wire [ 2:0] awprot,// always 3'b0
    output wire        awvalid,
    input  wire        awready,
    //w
    output wire [ 3:0] wid,// always 4'b1
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,// always 1
    output wire        wvalid,
    input  wire        wready,
    //b
    input  wire [ 3:0] bid,// ignore
    input  wire [ 1:0] bresp,// ignore
    input  wire        bvalid,
    output wire        bready
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire axi_rd_rps;
wire axi_wr_rps;

//read request
reg rd_req;
reg rd_req_id;
always @(posedge clk) begin
    if (reset) begin
        rd_req <= 0;
    end
    else if((rd_req0 || rd_req1) && !rd_req) begin
        rd_req <= 1;
    end
    else if(axi_rd_rps) begin
        rd_req <= 0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        rd_req_id <= 0;
    end
    else if(!rd_req) begin
        rd_req_id <= rd_req1;
    end
end


//write request
reg wr_req;
always @(posedge clk) begin
    if (reset) begin
        wr_req <= 0;
    end
    else if((wr_req1) && !wr_req) begin
        wr_req <= 1;
    end
    else if(axi_wr_rps) begin
        wr_req <= 0;
    end
end

//write data
reg [127:0] wr_data;
reg [7:0]   wr_len;
reg [31:0]  wr_addr;
reg [3:0]   wr_wstrb;
reg         wr_burst;
always @(posedge clk) begin
    if (reset) begin
        wr_data <= 128'b0;
        wr_len <= 8'b0;
        wr_addr <= 32'hdeadbeef;
        wr_wstrb <= 4'hf;
        wr_burst <= 1'b0;
    end
    else if(wr_req1 && wr_rdy1) begin
        wr_data <= wr_data1;
        wr_len <= wr_type1[2] ? 8'h3 : 8'h0;
        wr_addr <= wr_addr1;
        wr_wstrb <= wr_wstrb1;
        wr_burst <= wr_type1[2];
    end
    else if(wvalid && wready) begin
        wr_data <= (wr_data >> 32);
        wr_len <= wr_len - 8'h1;
    end
end

// wr_len为剩余发射次数，其值为 0 时表示最后一个数据包
wire wr_last = wvalid && (wr_len == 8'h0);

// receive address and data

reg rd_addr_rcv;
reg wr_addr_rcv;
reg wr_data_rcv;

always @(posedge clk) begin
    if(reset) begin
        rd_addr_rcv <= 1'b0;
    end
    else if(arready && arvalid) begin
        rd_addr_rcv <= 1'b1;
    end
    else if(axi_rd_rps) begin
        rd_addr_rcv <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        wr_addr_rcv <= 1'b0;
    end
    else if(awready && awvalid) begin
        wr_addr_rcv <= 1'b1;
    end
    else if(axi_wr_rps) begin
        wr_addr_rcv <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        wr_data_rcv <= 1'b0;
    end
    else if(wready && wvalid && wlast) begin
        wr_data_rcv <= 1'b1;
    end
    else if(axi_wr_rps) begin
        wr_data_rcv <= 1'b0;
    end
end

// axi_rd_rps and axi_wr_rps are used to check if the axi transaction is complete
assign axi_rd_rps = rd_addr_rcv && (rvalid && rready && rlast);
assign axi_wr_rps = wr_addr_rcv && wr_data_rcv && (bvalid && bready);

/* ！！！！！！！！！ */
// 下面读端口与前任转接桥不同的是，前任转接桥采用转发策略（存下请求并转发），而新转接桥在选择性建立传输连接后双方信号直接对接（以最大效率处理突发请求）。

// 老桥： 
//       | req0 |  ->  |----------|
//                     |  bridge  |  (存储并筛选) -> | axi |
//       | req1 |  ->  |----------|

// 新桥：
//       | req0 |  ---------|
//                          |     
//                   bridge | -----------> | axi |
//                               
//       | req1 |  ------>（X）
//
//                or
//
//       | req0 |  ------>（X）
//                               
//                   bridge | -----------> | axi |
//                          |     
//       | req1 |  ---------|


//icache interface
assign rd_rdy0 = !rd_req && !rd_req1;
assign ret_valid0 = !rd_req_id && rd_addr_rcv && rvalid;
assign ret_last0 = !rd_req_id && rd_addr_rcv && rlast;
assign ret_data0 = rdata;

//dcache interface
assign rd_rdy1 = !rd_req;
assign ret_valid1 = rd_req_id && rd_addr_rcv && rvalid;
assign ret_last1 = rd_req_id && rd_addr_rcv && rlast;
assign ret_data1 = rdata;

assign wr_rdy1 = !wr_req;

//axi interface
assign arid = {3'b0, rd_req_id}; // 0 for inst; 1 for data
assign araddr = rd_req_id ? rd_addr1 : rd_addr0;
assign arlen = rd_req_id ? (rd_type1[2] ? 8'h3 : 8'h0) : (rd_type0[2] ? 8'h3 : 8'h0);
assign arsize = 3'b010;
assign arburst = 2'b01;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arvalid = rd_req && !rd_addr_rcv;

assign rready = 1'b1;

assign awid = 4'b1;
assign awaddr = wr_addr;
assign awlen = wr_len;
assign awsize = 3'b010;
assign awburst = 2'b01;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign awvalid = wr_req && !wr_addr_rcv;

assign wid = 4'b1;
assign wdata = wr_data[31:0];
assign wstrb = wr_burst ? 4'hf : wr_wstrb;
assign wlast = wr_last;
assign wvalid = wr_req && !wr_data_rcv;

assign bready = 1'b1;
endmodule