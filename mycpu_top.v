module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid;
reg         valid_r;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
        valid_r <= 1'b0;
    end
    else begin
        valid <= 1'b1;
        valid_r <= valid;
    end
end

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        need_rj;
wire        need_rk;
wire        need_rd;
wire        rj_hit;
wire        rk_hit;
wire        rd_hit;
wire        reg_EX_hit;
wire        reg_MEM_hit;
wire        reg_WB_hit;
wire        hit_wait;
wire [4: 0] dest_EX_ID;
wire [4: 0] dest_MEM_ID;
wire [4: 0] dest_WB_ID;
wire [31:0] rj_pro;
wire [31:0] rk_pro;
wire [31:0] rd_pro;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] final_result;
wire [31:0] mem_result;

wire        data_sram_en_ID;
wire [ 3:0] data_sram_we_ID;
wire [31:0] data_sram_addr_EX;
wire [31:0] data_sram_wdata_ID;

//流水级间的寄存器
reg [31:0] pc_ID, pc_EX, pc_MEM, pc_WB;
reg [31:0] alu_src1_r;
reg [31:0] alu_src2_r;
reg [11:0] alu_op_r;
reg        data_sram_en_EX;
reg        data_sram_en_MEM;
reg [ 3:0] data_sram_we_EX;
reg [ 3:0] data_sram_we_MEM;
reg [31:0] data_sram_addr_MEM;
reg [31:0] data_sram_wdata_EX;
reg [31:0] data_sram_wdata_MEM;
reg        res_from_mem_EX;
reg        res_from_mem_MEM;
reg        res_from_mem_WB;
reg [31:0] alu_result_WB;
reg [ 4:0] dest_EX;
reg [ 4:0] dest_MEM;
reg [ 4:0] dest_WB;
reg        gr_we_EX;
reg        gr_we_MEM;
reg        gr_we_WB;




//添加握手信号
reg IF_valid;
wire IF_allowin;
wire IF_readygo;

reg ID_valid;
wire ID_allowin;
wire ID_readygo;

reg EX_valid;
wire EX_allowin;
wire EX_readygo;

reg MEM_valid;
wire MEM_allowin;
wire MEM_readygo;

reg WB_valid;
wire WB_allowin;
wire WB_readygo;

//考虑冲突
assign IF_readygo = valid_r ? !hit_wait : 1'b1;
assign ID_readygo = 1'b1;
assign EX_readygo = 1'b1;
assign MEM_readygo = 1'b1;
assign WB_readygo = 1'b1;

assign IF_allowin = (!IF_valid  || ID_allowin  && IF_readygo )&&valid;
assign ID_allowin = (!ID_valid  || EX_allowin  && ID_readygo )&&valid;
assign EX_allowin = (!EX_valid  || MEM_allowin && EX_readygo )&&valid;
assign MEM_allowin =(!MEM_valid || WB_allowin  && MEM_readygo)&&valid;
assign WB_allowin = (!WB_valid  ||                WB_readygo )&&valid;

//流水级控制
always @(posedge clk) begin
    if (reset)
		IF_valid <= 1'b0;
    else if (br_taken && IF_allowin)
        IF_valid <= 1'b0;
	else if(IF_allowin)
		IF_valid <= 1'b1;
end
always @(posedge clk) begin
	if (reset)
		ID_valid <= 1'b0;
	else if(ID_allowin)
		ID_valid <= IF_valid && IF_readygo;
end
always @(posedge clk) begin
	if (reset)
		EX_valid <= 1'b0;
	else if(EX_allowin)
		EX_valid <= ID_valid && ID_readygo;
end
always @(posedge clk) begin
	if (reset)
		MEM_valid <= 1'b0;
	else if(MEM_allowin)
		MEM_valid <= EX_valid && EX_readygo;
end
always @(posedge clk) begin
	if (reset)
		WB_valid <= 1'b0;
	else if(WB_allowin)
		WB_valid <= MEM_valid && MEM_readygo;
end

assign seq_pc       = pc + 3'h4;
assign nextpc       = valid_r ? (br_taken ? br_target : seq_pc) : seq_pc;


//依次传递pc值，以便最后对比信号
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(IF_allowin)begin
        pc <= nextpc;
    end
end
always @(posedge clk) begin
    if (reset)
        pc_ID <= 32'h1bfffffc;
    else if(IF_allowin)
        pc_ID <= pc;
end
always @(posedge clk) begin
    if (reset)
        pc_EX <= 32'h1bfffffc;
    else if(ID_allowin && IF_valid && IF_readygo)
        pc_EX <= pc_ID;
end
always @(posedge clk) begin
    if (reset)
        pc_MEM <= 32'h1bfffffc;
    else if(EX_allowin && ID_valid && ID_readygo)
        pc_MEM <= pc_EX;
end
always @(posedge clk) begin
    if (reset)
        pc_WB <= 32'h1bfffffc;
    else if(MEM_allowin && EX_valid && EX_readygo)
        pc_WB <= pc_MEM;
end


assign inst_sram_en    = IF_allowin;
assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = pc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign need_rj    =  ~(inst_b | inst_bl | inst_lu12i_w);
assign need_rk    =  inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or |inst_nor | inst_xor;
assign need_rd    =  inst_beq | inst_bne | inst_st_w;

assign dest_EX_ID = dest_EX & {5{gr_we_EX}} & {5{ID_valid}};
assign dest_MEM_ID = dest_MEM & {5{gr_we_MEM}} & {5{EX_valid}};
assign dest_WB_ID = dest_WB & {5{gr_we_WB}} & {5{MEM_valid}};

assign rj_hit = need_rj && (rj != 5'd0) && ((rj == dest_EX_ID) || (rj == dest_MEM_ID) || (rj == dest_WB_ID));
assign rk_hit = need_rk && (rk != 5'd0) && ((rk == dest_EX_ID) || (rk == dest_MEM_ID) || (rk == dest_WB_ID));
assign rd_hit = need_rd && (rd != 5'd0) && ((rd == dest_EX_ID) || (rd == dest_MEM_ID) || (rd == dest_WB_ID));

assign reg_EX_hit = need_rj && (rj != 5'd0) && (rj == dest_EX_ID) || need_rk && (rk != 5'd0) && (rk == dest_EX_ID) || need_rd && (rd != 5'd0) && (rd == dest_EX_ID);
assign reg_MEM_hit = need_rj && (rj != 5'd0) && (rj == dest_MEM_ID) || need_rk && (rk != 5'd0) && (rk == dest_MEM_ID) || need_rd && (rd != 5'd0) && (rd == dest_MEM_ID);
assign reg_WB_hit = need_rj && (rj != 5'd0) && (rj == dest_WB_ID) || need_rk && (rk != 5'd0) && (rk == dest_WB_ID) || need_rd && (rd != 5'd0) && (rd == dest_WB_ID);

assign rj_pro = (rj == dest_EX_ID) ? alu_result :
                (rj == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign rk_pro = (rk == dest_EX_ID) ? alu_result :
                (rk == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign rd_pro = (rd == dest_EX_ID) ? alu_result :
                (rd == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign hit_wait = reg_EX_hit && data_sram_en_EX || reg_MEM_hit && data_sram_en_MEM;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

//将一些后续控制信号从ID阶段传递下去
always @(posedge clk) begin
    if(reset) begin
        res_from_mem_EX <= 1'b0;
        dest_EX <= 5'd0;
        gr_we_EX <= 1'b0;
    end
    else if(ID_allowin && IF_valid && IF_readygo) begin
        res_from_mem_EX <= res_from_mem;
        dest_EX <= dest;
        gr_we_EX <= gr_we;
    end
end
always @(posedge clk) begin
    if(reset) begin
        res_from_mem_MEM <= 1'b0;
        dest_MEM <= 5'd0;
        gr_we_MEM <= 1'b0;
    end
    else if(EX_allowin && ID_valid && ID_readygo) begin
        res_from_mem_MEM <= res_from_mem_EX;
        dest_MEM <= dest_EX;
        gr_we_MEM <= gr_we_EX;
    end
end
always @(posedge clk) begin
    if(reset) begin
        alu_result_WB <= 32'h0;
        res_from_mem_WB <= 1'b0;
        dest_WB <= 5'd0;
        gr_we_WB <= 1'b0;
    end
    else if(MEM_allowin && EX_valid && EX_readygo) begin
        alu_result_WB <= data_sram_addr_MEM;
        res_from_mem_WB <= res_from_mem_MEM;
        dest_WB <= dest_MEM;
        gr_we_WB <= gr_we_MEM;
    end
end



assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rj_hit ? rj_pro : rf_rdata1;
assign rkd_value = src_reg_is_rd && rd_hit ? rd_pro :
                  !src_reg_is_rd && rk_hit ? rk_pro :
                  rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && IF_valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);


assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

//将alu输入保存到EX阶段并使用
always @(posedge clk) begin
    if(reset) begin
        alu_src1_r <= 32'h0;
        alu_src2_r <= 32'h0;
        alu_op_r   <= 12'h0;
    end
    else if(IF_valid && ID_allowin && IF_readygo)begin
        alu_src1_r <= alu_src1;
        alu_src2_r <= alu_src2;
        alu_op_r   <= alu_op;
    end
end

alu u_alu(
    .alu_op     (alu_op_r    ),
    .alu_src1   (alu_src1_r  ),
    .alu_src2   (alu_src2_r  ),
    .alu_result (alu_result)
    );

//传递访存控制信号
assign data_sram_en_ID    = inst_ld_w || inst_st_w;
assign data_sram_we_ID    = {4{mem_we && valid}};
assign data_sram_addr_EX  = alu_result;
assign data_sram_wdata_ID = rkd_value;

always @(posedge clk) begin
    if(reset) begin
        data_sram_en_EX <= 1'b0;
        data_sram_we_EX <= 4'b0;
        data_sram_wdata_EX <= 32'h0;
    end
    else if(IF_valid && ID_allowin && IF_readygo) begin
        data_sram_en_EX <= data_sram_en_ID;
        data_sram_we_EX <= data_sram_we_ID;
        data_sram_wdata_EX <= data_sram_wdata_ID;
    end
end
always @(posedge clk) begin
    if(reset) begin
        data_sram_en_MEM <= 1'b0;
        data_sram_we_MEM <= 4'b0;
        data_sram_addr_MEM <= 32'h0;
        data_sram_wdata_MEM <= 32'h0;
    end
    else if(EX_allowin && ID_valid && ID_readygo) begin
        data_sram_en_MEM <= data_sram_en_EX;
        data_sram_we_MEM <= data_sram_we_EX;
        data_sram_addr_MEM <= data_sram_addr_EX;
        data_sram_wdata_MEM <= data_sram_wdata_EX;
    end
end

//将数据以及控制信号均改为流动到该级的数据与信号
assign data_sram_en = data_sram_en_MEM;
assign data_sram_we = data_sram_we_MEM;
assign data_sram_addr = data_sram_addr_MEM;
assign data_sram_wdata = data_sram_wdata_MEM;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem_WB ? mem_result : alu_result_WB;

assign rf_we    = gr_we_WB && MEM_valid && MEM_readygo;
assign rf_waddr = dest_WB;
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest_WB;
assign debug_wb_rf_wdata = final_result;

endmodule