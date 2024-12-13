`define CACHE_WAY               2
`define CACHE_SET	            8
module cache(
    input         clk,
    input         resetn,

    input         valid,//请求有效
    input         op,//1：write 0 : read
    input         mat, //存储访问类型(1：cacheable 0: uncacheable)
    input [19:0]  tag, // addr[31:12]
    input [ 7:0]  index, //addr[11:4]
    input [ 3:0]  offset, //addr[3:0]
    input [ 3:0]  wstrb,
    input [31:0]  wdata,
    output        addr_ok,
    output        data_ok,
    output[31:0]  rdata,
    //read
    output        rd_req,
    output[ 2:0]  rd_type,
    output[31:0]  rd_addr,
    input         rd_rdy,
    input         ret_valid,
    input         ret_last,
    input [31:0]  ret_data,
    //write
    output        wr_req,
    output[ 2:0]  wr_type,
    output[31:0]  wr_addr,
    output[ 3:0]  wr_wstrb,
    output[127:0] wr_data,
    input         wr_rdy,

    input       inst_CACOP,
    input       [4:0]      code,
    input       [31:0]     CACOP_VPPN
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

//主状态机
    parameter IDLE = 5'b10000;
    parameter LOOKUP = 5'b01000;
    parameter MISS = 5'b00100;
    parameter REPLACE = 5'b00010;
    parameter REFILL = 5'b00001;    

    reg [4:0] state, next_state;


//wirte buffer 状态机

    parameter WB_IDLE = 3'b10;
    parameter WB_WRITE = 3'b01;
    parameter WB_TAGV = 3'b100;
    reg [2:0] wb_state, wb_next_state;



//buffer
    // request buffer
    reg         op_reg;
    reg         mat_reg;
    reg  [ 7:0] index_reg;
    reg  [19:0] tag_reg;
    reg  [ 3:0] offset_reg;
    reg  [ 3:0] wstrb_reg;
    reg  [31:0] wdata_reg;
    reg         inst_CACOP_reg;
    reg  [4:0]  code_reg;
    reg  [31:0] CACOP_VPPN_reg;

    // write buffer
    reg         wrbuf_way;
    reg  [ 7:0] wrbuf_index;
    reg  [ 3:0] wrbuf_offset;
    reg  [ 3:0] wrbuf_wstrb;
    reg  [31:0] wrbuf_wdata;

// tag
    wire                    hit_write;
    wire                    hit_write_conflict;
    wire                    cache_hit;
    wire [1:0] hit_way;
    wire [            31:0] hit_result;



    wire         tagv_we          [1:0];
    wire [ 7:0]  tagv_addr;
    wire [20:0]  tagv_wdata       [1:0];
    wire [20:0]  tagv_rdata       [1:0];
    wire [ 3:0]  data_bank_we    [1:0][3:0];
    wire [ 7:0]  data_bank_addr  [3:0];
    wire [31:0]  data_bank_wdata [3:0];
    wire [31:0]  data_bank_rdata [1:0][3:0];
    reg  [255:0] dirty_arr       [1:0];
    reg  [255:0] replace_way;
    reg  [ 1:0] ret_cnt;




//主状态机
   always @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: 
                if(valid & ~hit_write_conflict)
                    next_state = LOOKUP;
                else
                    next_state = IDLE;

            LOOKUP:
                if(inst_CACOP_reg)begin
                if((code_reg[4:3]==2&&(hit_way[0]&&dirty_arr[0][index_reg]||hit_way[1]&&dirty_arr[1][index_reg])||
                code_reg[4:3]==1&&(dirty_arr[0][index_reg]||dirty_arr[1][index_reg]))&&code_reg[2:0]==1)
                    next_state = MISS;
                else 
                    next_state = IDLE;
                end
                else if(!mat_reg) begin
                    if(op_reg)
                        next_state = MISS;
                    else
                        next_state = REPLACE;
                end
                else if(cache_hit && (!valid || hit_write_conflict))
                    next_state = IDLE;
                else if(cache_hit && valid && !hit_write_conflict)
                    next_state = LOOKUP;
                else if (!dirty_arr[replace_way[index_reg]][index_reg]
                 || !tagv_rdata[replace_way[index_reg]][0])
                    next_state = REPLACE;
                else
                    next_state = MISS;

            MISS:
                if(inst_CACOP_reg)
                    next_state = IDLE;
                else if(~wr_rdy)
                    next_state = MISS;
                else begin
                    if(!mat_reg)
                        next_state = IDLE;
                    else
                        next_state = REPLACE;
                end

            REPLACE:
                if(~rd_rdy)
                    next_state = REPLACE;
                else begin
                    if(!mat_reg)
                        next_state = IDLE;
                    else
                        next_state = REFILL;
                end

            REFILL:
                if(ret_valid && ret_last)
                    next_state = IDLE;
                else
                    next_state = REFILL;

            default: 
                next_state = IDLE;
        endcase
    end


//write buffer 状态机

    always @(posedge clk) begin
        if(reset) begin
            wb_state <= WB_IDLE;
        end
        else begin
            wb_state <= wb_next_state;
        end
    end

    always @(*) begin
        case (wb_state)
            WB_IDLE: 
                if((inst_CACOP_reg&&code_reg[4:3]==0)||(inst_CACOP_reg&&code_reg[4:3]==1)||(inst_CACOP_reg&&code_reg[4:3]==2&&(hit_way[0]||hit_way[1])))
                    wb_next_state = WB_TAGV;
                else if(hit_write)
                    wb_next_state = WB_WRITE;
                else
                    wb_next_state = WB_IDLE;

            WB_WRITE:
                if(hit_write)
                    wb_next_state = WB_WRITE;
                else
                    wb_next_state = WB_IDLE;
            WB_TAGV:
                wb_next_state = WB_IDLE;
            default: 
                wb_next_state = WB_IDLE;
        endcase
    end
// request buffer
always @(posedge clk) begin
        if(reset)
            {op_reg, mat_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg, inst_CACOP_reg, code_reg, CACOP_VPPN_reg}<= 108'b0;
        else if(valid & addr_ok)
            {op_reg, mat_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg , inst_CACOP_reg, code_reg, CACOP_VPPN_reg}
                                 <= {op, mat, index, tag, offset, wstrb, wdata , inst_CACOP, code, CACOP_VPPN};
        else if(wb_state == WB_TAGV)
            {op_reg, mat_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg, inst_CACOP_reg, code_reg, CACOP_VPPN_reg}
                                 <= {op, mat, index, tag, offset, wstrb, wdata , inst_CACOP, code, CACOP_VPPN};
    end

// write buffer
always @(posedge clk) begin
        if(reset)
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} <= 49'b0;
        else if(hit_write)
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata}
            <= {hit_way[1], index_reg, offset_reg, wstrb_reg, wdata_reg};
    end
    
// burst data counter
always @(posedge clk) begin
        if(reset)
            ret_cnt <= 2'b0;
        else if(ret_valid) begin
            if(!ret_last)
                ret_cnt <= ret_cnt + 1'b1;
            else
                ret_cnt <= 2'b0;
        end
    end
//tag match

    genvar i, way;
    generate
        for(way = 0; way < `CACHE_WAY   ; way = way + 1) begin: tag_value
            assign hit_way[way] = tagv_rdata[way][0] && (tagv_rdata[way][20:1] == tag_reg);
            assign tagv_we[way] = (mat_reg && ret_valid && ret_last && (replace_way[index_reg] == way)) ||
                                  (wb_state == WB_TAGV&&((inst_CACOP_reg&&code_reg[4:3]==0)||(inst_CACOP_reg&&code_reg[4:3]==1)||(inst_CACOP_reg&&code_reg[4:3]==2&&hit_way[way])));
        end
    endgenerate
    assign cache_hit = |hit_way && mat_reg;

    assign tagv_addr  =(wb_state == WB_TAGV&&inst_CACOP_reg)?index_reg: (state == IDLE || state == LOOKUP) && (valid && addr_ok)? index : index_reg;
    assign tagv_wdata[0] = (inst_CACOP_reg&&code_reg[4:3]==0&&wb_state==WB_TAGV)?{20'b0, tagv_rdata[0][0]}:
                       (inst_CACOP_reg&&(code_reg[4:3]==1||code_reg[4:3]==2)&&wb_state==WB_TAGV)?{tagv_rdata[0][20:1], 1'b0}:
                       {tag_reg, 1'b1};
    assign tagv_wdata[1] = (inst_CACOP_reg&&code_reg[4:3]==0&&wb_state==WB_TAGV)?{20'b0, tagv_rdata[1][0]}:
                       (inst_CACOP_reg&&(code_reg[4:3]==1||code_reg[4:3]==2)&&wb_state==WB_TAGV)?{tagv_rdata[1][20:1], 1'b0}:
                       {tag_reg, 1'b1};

    assign hit_write = (state == LOOKUP) && cache_hit && op_reg;// - 拉高addr_ok会导致传给data_bank的地址被立刻更新，从而错误
    assign hit_write_conflict = (hit_write || wb_state == WB_WRITE) && valid && ~op;
    assign hit_result = {32{hit_way[0]}} & data_bank_rdata[0][offset_reg[3:2]] |
                        {32{hit_way[1]}} & data_bank_rdata[1][offset_reg[3:2]];
    
// 伪随机替换算法
	always @ (posedge clk) begin
		if (reset) begin
				replace_way <= 256'b0;
			end
		else if ((state == LOOKUP) || (state == IDLE))begin
			if (hit_way[0] && valid)
			    replace_way[index_reg] <= 1'b1;		    
			else if (hit_way[1] && valid)
			    replace_way[index_reg] <= 1'b0;
		end
		else if ((state == REFILL) && (next_state == IDLE)) begin
           replace_way[index_reg] <= ~replace_way[index_reg];  
        end
       
	end

// dirty array
    always @(posedge clk) begin
        if(reset)
            {dirty_arr[1], dirty_arr[0]} <= {256'b0, 256'b0};
        else if(wb_state == WB_WRITE)
            dirty_arr[wrbuf_way][wrbuf_index] <= 1'b1;
        else if(mat_reg && ret_valid && ret_last)
            dirty_arr[wrbuf_way][wrbuf_index] <= op_reg;
    end

// RAM port
    generate
        for (i=0; i<4; i=i+1) begin: data_bank
            for (way = 0; way < `CACHE_WAY; way = way + 1) begin: data_bank_we_value
                assign data_bank_we[way][i] = ({4{wb_state == WB_WRITE && (wrbuf_offset[3:2] == i) && (wrbuf_way == way)}} & wrbuf_wstrb) |
                                              ({4{ret_valid && (ret_cnt == i) && replace_way[index_reg] == way}} & {4{mat_reg}});
            end
            
            assign data_bank_addr[i]  = (state == IDLE || state == LOOKUP) && (valid && addr_ok)? index : index_reg;
            assign data_bank_wdata[i] = (wb_state == WB_WRITE)? wrbuf_wdata :
                                          (offset_reg[3:2] != i || ~op_reg)? ret_data :
                                          {wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                                           wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                                           wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                                           wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]};  
        end
    endgenerate

// RAM instance 
    generate
        for (way = 0; way < `CACHE_WAY; way = way + 1) begin: ram_generate
            TAG_RAM tagv_ram (
                .clka (clk),
                .wea  (tagv_we[way]),
                .addra(tagv_addr),
                .dina (tagv_wdata[way]),
                .douta(tagv_rdata[way]),
                .ena  (1'b1)
            );
            for(i = 0; i < 4; i = i + 1) begin: bank_ram_generate
                DATA_Bank_RAM data_bank_ram(
                    .clka (clk),
                    .wea  (data_bank_we[way][i]),
                    .addra(data_bank_addr[i]),
                    .dina (data_bank_wdata[i]),
                    .douta(data_bank_rdata[way][i]),
                    .ena  (1'b1)
                );
            end
        end
    endgenerate

//CPU
    assign addr_ok = ((state == IDLE) || ((state == LOOKUP) && valid && cache_hit)) && !hit_write_conflict;

    assign data_ok = (!mat_reg && (op_reg ? wr_req : ret_valid)) || ((state == LOOKUP) && (cache_hit || op_reg)) || 
                     ((state == REFILL) && !op_reg && ret_valid && (ret_cnt == offset_reg[3:2]));

    assign rdata = (ret_valid)? ret_data : hit_result;
    
//AXI 
    // read port
    assign rd_type = mat_reg ? 3'b100 : 3'b010;
    assign rd_addr = mat_reg ? {tag_reg, index_reg, 4'b0} : {tag_reg, index_reg, offset_reg};
    assign rd_req = (state == REPLACE);

    // write port
    assign wr_req   = (state == MISS) && wr_rdy;
    assign wr_type  = (inst_CACOP_reg )?3'b100:mat_reg ? 3'b100 : 3'b010;
    assign wr_addr  =((inst_CACOP_reg &&dirty_arr[1][index_reg]&&code_reg[4:3]==2 && hit_way[1])||(inst_CACOP_reg &&dirty_arr[1][index_reg]&&code_reg[4:3]==1))?{tagv_rdata[1][20:1], index_reg, 4'b0} :
                      ((inst_CACOP_reg &&dirty_arr[0][index_reg]&&code_reg[4:3]==2 && hit_way[0]||(inst_CACOP_reg &&dirty_arr[0][index_reg]&&code_reg[4:3]==1)))?{tagv_rdata[0][20:1], index_reg, 4'b0} :
                      mat_reg ? {tagv_rdata[replace_way[index_reg]][20:1], index_reg, 4'b0} : {tag_reg, index_reg, offset_reg};
    assign wr_wstrb = (inst_CACOP_reg )? 4'hf : mat_reg ? 4'hf : wstrb_reg;
    assign wr_data  = ((inst_CACOP_reg &&dirty_arr[1][index_reg]&&code_reg[4:3]==2 && hit_way[1])||(inst_CACOP_reg &&dirty_arr[1][index_reg]&&code_reg[4:3]==1))?{data_bank_rdata[1][3], data_bank_rdata[1][2],
                       data_bank_rdata[1][1], data_bank_rdata[1][0]}: 
                       ((inst_CACOP_reg &&dirty_arr[0][index_reg]&&code_reg[4:3]==2 && hit_way[0])||(inst_CACOP_reg &&dirty_arr[0][index_reg]&&code_reg[4:3]==1))?{data_bank_rdata[0][3], data_bank_rdata[0][2],
                       data_bank_rdata[0][1], data_bank_rdata[0][0]}:
                      mat_reg ? {data_bank_rdata[replace_way[index_reg]][3], data_bank_rdata[replace_way[index_reg]][2],
                       data_bank_rdata[replace_way[index_reg]][1], data_bank_rdata[replace_way[index_reg]][0]} : wdata_reg;

endmodule