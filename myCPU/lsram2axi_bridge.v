module lsram2axi_bridge(
    input  wire        clk,
    input  wire        resetn, 

    //inst sram-like 
    input  wire        inst_req,
    input  wire        inst_wr,
    input  wire [ 1:0] inst_size,
    input  wire [31:0] inst_addr,
    input  wire [31:0] inst_wdata,
    output wire [31:0] inst_rdata,
    output wire        inst_addr_ok,
    output wire        inst_data_ok,
    
    //data sram-like 
    input  wire        data_req,
    input  wire        data_wr,
    input  wire [ 1:0] data_size,
    input  wire [31:0] data_addr,
    input  wire [31:0] data_wdata,
    output wire [31:0] data_rdata,
    output wire        data_addr_ok,
    output wire        data_data_ok,

    //axi
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

// reg         valid;
// always @(posedge clk) begin
//     if (reset)
//         valid <= 1'b0;
//     else
//         valid <= 1'b1;
// end

reg sram_req;
reg sram_req_id;
reg sram_wr;
reg [1:0] sram_size;
reg [31:0] sram_addr;
reg [31:0] sram_wdata;

wire axi_rd_rps;
wire axi_wr_rps;
wire axi_response;

always @(posedge clk) begin
    if(reset) begin
        sram_req <= 1'b0;
    end
    else if((inst_req || data_req) && !sram_req) begin
        sram_req <= 1'b1;
    end
    else if(axi_response) begin
        sram_req <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        sram_req_id <= 1'b0;
    end
    else if(!sram_req) begin
        sram_req_id <= data_req;
    end
end

always @(posedge clk) begin
    if(data_req && data_addr_ok)begin
        sram_wr <= data_wr;
        sram_size <= data_size;
        sram_addr <= data_addr;
        sram_wdata <= data_wdata;
    end
    else if(inst_req && inst_addr_ok)begin
        sram_wr <= inst_wr;
        sram_size <= inst_size;
        sram_addr <= inst_addr;
        sram_wdata <= inst_wdata;
    end
end

reg [31:0] rdata_r;
always @(posedge clk) begin
    if(reset) begin
        rdata_r <= 32'b0;
    end
    else if(sram_req && axi_rd_rps) begin
        rdata_r <= rdata;
    end
end

reg inst_data_readygo;
always @(posedge clk) begin
    if(reset) begin
        inst_data_readygo <= 1'b0;
    end
    else if(sram_req && !sram_req_id && axi_response && !inst_data_readygo) begin
        inst_data_readygo <= 1'b1;
    end
    else if(inst_data_readygo) begin
        inst_data_readygo <= 1'b0;
    end
end
reg data_data_readygo;
always @(posedge clk) begin
    if(reset) begin
        data_data_readygo <= 1'b0;
    end
    else if(sram_req && sram_req_id && axi_response && !data_data_readygo) begin
        data_data_readygo <= 1'b1;
    end
    else if(data_data_readygo) begin
        data_data_readygo <= 1'b0;
    end
end

//sram-like
assign inst_addr_ok = !sram_req && !data_req;
assign inst_data_ok = inst_data_readygo;
assign inst_rdata = rdata_r;
assign data_addr_ok = !sram_req;
assign data_data_ok = data_data_readygo;
assign data_rdata = rdata_r;


reg addr_rcv;
reg wdata_rcv;
always @(posedge clk) begin
    if(reset) begin
        addr_rcv <= 1'b0;
    end
    else if(arready && arvalid || awvalid && awready) begin
        addr_rcv <= 1'b1;
    end
    else if(axi_response) begin
        addr_rcv <= 1'b0;
    end
end
always @(posedge clk) begin
    if(reset) begin
        wdata_rcv <= 1'b0;
    end
    else if(wready && wvalid) begin
        wdata_rcv <= 1'b1;
    end
    else if(axi_response) begin
        wdata_rcv <= 1'b0;
    end
end

assign axi_rd_rps = addr_rcv && (rvalid && rready);
assign axi_wr_rps = addr_rcv && wdata_rcv && (bvalid && bready);
assign axi_response = axi_rd_rps || axi_wr_rps;

//axi
assign arid = {3'b0, sram_req_id};// 0 for inst; 1 for data
assign araddr = sram_addr;
assign arlen = 8'b0; //always 0
assign arsize = sram_size;
assign arburst = 2'b01;// always 2'b01
assign arlock = 2'b0;// always 2'b0
assign arcache = 4'b0;// always 4'b0
assign arprot = 3'b0;// always 3'b0
assign arvalid = sram_req && !sram_wr && !addr_rcv;

assign rready = 1'b1;

assign awid = 4'b1;
assign awaddr = sram_addr;
assign awlen = 8'b0; //always 0
assign awsize = sram_size;
assign awburst = 2'b01;// always 2'b01
assign awlock = 2'b0;// always 2'b0
assign awcache = 4'b0;// always 4'b0
assign awprot = 3'b0;// always 3'b0
assign awvalid = sram_req && sram_wr && !addr_rcv;

assign wid = 4'b1;
assign wdata = sram_wdata;
assign wstrb = {sram_size[1], sram_size[1], (sram_size != 0), 1'b1} << sram_addr[1:0];
assign wlast = 1'b1; //always 1
assign wvalid = sram_req && sram_wr && !wdata_rcv;

assign bready = 1'b1;

endmodule