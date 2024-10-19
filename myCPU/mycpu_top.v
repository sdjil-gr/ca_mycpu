`include "csr.vh"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
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
wire        br_taken_ID;
wire        br_taken_EX;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [14:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        dst_is_rj;
wire        gr_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [32:0] rj_sign;
wire [32:0] rd_sign;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        rj_eq_rd;
wire        rj_lt_rd;
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

wire [1:0]  op_25_24;
wire [4:0]  op_14_10;
wire [4:0]  op_9_5;
wire [4:0]  op_4_0;

wire [3:0]   op_25_24_d;
wire [31:0]   op_14_10_d;
wire [31:0]   op_9_5_d;
wire [31:0]   op_4_0_d;

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
//算术逻辑运算
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
//乘除指令
wire        inst_mul_w;
wire        inst_mulh_w;  
wire        inst_mulh_wu; 
wire        inst_div_w;
wire        inst_mod_w;  
wire        inst_div_wu;  
wire        inst_mod_wu; 
//访存指令
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
//分支指令
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
//异常指令
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
//rdcnt指令
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid_w;

//异常触发信号
wire        exc_at_ID;       //在ID阶段发生异常 
wire        exc_at_EX;       //在EX阶段发生异常
wire        exc_adef;        //取指地址异常
wire        exc_ale;         //地址非对齐异常
wire        exc_ine;         //指令不存在异常
wire        exc_break;       //断点异常
wire        exc_syscall;     //系统调用异常

//csr指令接口
wire csr_we;
wire csr_re;
wire [13:0] csr_num;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [31:0] csr_rvalue;
//csr其他接口
wire        wb_ex;
wire [31:0] wb_pc;
wire        ertn_flush;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire [31:0] ex_entry;
wire [31:0] ex_epc;
wire        has_int;
wire [31:0] counter_id;

wire        need_ui5;
wire        need_si12;
wire        need_ui12;
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
wire        need_div;
wire        div_unsigned;
wire        div_signed;
wire        get_div_or_mod;
wire [63:0] sdiv_result;
wire [63:0] udiv_result;
wire [31:0] EX_final_result;
wire [31:0] final_result;
wire [31:0] mem_result;

wire        data_sram_req_ID;
wire        data_sram_wr_ID;
wire [1:0]  data_sram_size_ID;
wire [ 3:0] data_sram_wstrb_ID;
wire [31:0] data_sram_addr_EX;
wire [ 1:0] data_sram_addroffset;
wire [31:0] data_sram_wdata_ID;
wire [ 3:0] data_sram_type_tag;
wire [31:0] data_sram_rdata_off;

//流水级间的寄存器
reg [31:0] pc_ID, pc_EX, pc_MEM, pc_WB;
reg [31:0] alu_src1_r;
reg [31:0] alu_src2_r;
reg [14:0] alu_op_r;
reg        need_div_r;
reg        div_unsigned_r;
reg        div_signed_r;
reg        get_div_or_mod_r;
reg        data_sram_req_EX;
reg        data_sram_req_MEM;
reg        data_sram_wr_EX;
reg        data_sram_wr_MEM;
reg [1:0]  data_sram_size_EX;
reg [1:0]  data_sram_size_MEM;
reg [ 3:0] data_sram_wstrb_EX;
reg [ 3:0] data_sram_wstrb_MEM;
reg [31:0] data_sram_addr_MEM;
reg [31:0] data_sram_wdata_EX;
reg [31:0] data_sram_wdata_MEM;
reg [ 3:0] data_sram_type_tag_EX;
reg [ 3:0] data_sram_type_tag_MEM;
reg [ 3:0] data_sram_type_tag_WB;
reg [ 1:0] data_sram_addroffset_WB;
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
reg        is_csr_EX;
reg [31:0] csr_rvalue_EX;
reg        is_rdcntid_EX;
reg        is_rdcntvl_EX;
reg        is_rdcntvh_EX;

//添加握手信号
wire IF_valid;
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


reg inst_first_woshou;
always @(posedge clk) begin
    if (reset) begin
        inst_first_woshou <= 1'b0;
    end
    else if(IF_readygo) begin
        inst_first_woshou <= 1'b0;
    end
    else if(inst_sram_addr_ok&&inst_sram_req) begin
        inst_first_woshou <= 1'b1;
    end
end
reg data_first_woshou;
always @(posedge clk) begin
    if (reset) begin
        data_first_woshou <= 1'b0;
    end
    else if(MEM_readygo) begin
        data_first_woshou <= 1'b0;
    end
    else if(data_sram_addr_ok&&data_sram_req) begin
        data_first_woshou <= 1'b1;
    end
end
reg br_taken_ID_r;
reg br_taken_EX_r;
reg [31:0]nextpc_r;
always @(posedge clk) begin
    if (reset) begin
        br_taken_ID_r <= 1'b0;
        nextpc_r <= 32'h0;
        br_taken_EX_r <= 1'b0;
    end
    else if(exc_at_EX)begin
        nextpc_r <= br_target;
        br_taken_EX_r <= br_taken_EX;
    end
    else if(has_int||exc_at_ID)begin
        br_taken_ID_r <= br_taken_ID;
        nextpc_r <= br_target;
    end
    else if(IF_readygo)begin
        br_taken_ID_r <= 1'b0;
        nextpc_r <= 32'h0;
        br_taken_EX_r <= 1'b0;
    end
    else if(ID_readygo && !IF_readygo && ID_valid) begin
        br_taken_ID_r <= br_taken_ID;
        nextpc_r <= br_target;
        br_taken_EX_r <= br_taken_EX;
    end
end
//指令寄存器
reg [31:0]inst_ID;
reg is_inst_ID;
always @(posedge clk) begin
    if (reset) begin
        inst_ID <= 32'h0;
        is_inst_ID <= 1'b0;
    end
    else if(ID_readygo && EX_allowin)begin
        inst_ID <= inst_sram_rdata;
        is_inst_ID <= 1'b0;
    end
    else if(IF_readygo && !ID_allowin)begin
        inst_ID <= inst_sram_rdata;
        is_inst_ID <= 1'b1;
    end

end
//握手信号处理
/****************************************************************************/
assign IF_readygo = inst_first_woshou && inst_sram_data_ok;
assign ID_readygo = ((valid_r ? !hit_wait : 1'b1));//访存前递阻塞
assign EX_readygo = !need_div_r;//阻塞除法
assign MEM_readygo = (data_first_woshou &&data_sram_data_ok && data_sram_req_MEM) ||!data_sram_req_MEM;
assign WB_readygo = 1'b1;


assign ID_allowin  = (!ID_valid  || EX_allowin  && ID_readygo )&&valid;
assign EX_allowin  = (!EX_valid  || MEM_allowin && EX_readygo )&&valid;
assign MEM_allowin = (!MEM_valid || WB_allowin  && MEM_readygo)&&valid;
assign WB_allowin  = (!WB_valid  ||                WB_readygo )&&valid;

//流水级控制
assign IF_valid = 1'b1;

always @(posedge clk) begin
    if (reset)
		ID_valid <= 1'b0;
    else if((br_taken_ID_r || br_taken_EX_r) && ID_allowin && IF_readygo && IF_valid)
        ID_valid <= 1'b0;
    else if ((br_taken_ID || br_taken_EX) && ID_allowin)//分支跳转则把预取的错误指令取消
        ID_valid <= 1'b0;
	else if(ID_allowin)
		ID_valid <= IF_valid && IF_readygo;
end
always @(posedge clk) begin
	if (reset)
		EX_valid <= 1'b0;
    else if((br_taken_EX || exc_ine) && EX_allowin )//EX跳转或者无效指令则取消
		EX_valid <= 1'b0;
	else if(EX_allowin)
		EX_valid <= ID_valid && ID_readygo;
end
always @(posedge clk) begin
	if (reset)
		MEM_valid <= 1'b0;
    else if(exc_ale && MEM_allowin)//地址非对齐异常则取消该访存指令
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
/****************************************************************************/


//计时器
/****************************************************************************/
reg  [63:0] stable_counter;
wire [31:0] counter_vl;
wire [31:0] counter_vh;

always @(posedge clk) begin
    if (reset)
        stable_counter <= 64'h0;
    else 
        stable_counter <= stable_counter + 64'h1;
end

assign counter_vl = stable_counter[31:0];
assign counter_vh = stable_counter[63:32];
/****************************************************************************/

//PC值处理
/****************************************************************************/
assign seq_pc       = pc + 3'h4;
assign nextpc       = valid_r ? (br_taken_ID || br_taken_EX ? br_target : seq_pc) : seq_pc;

//依次传递pc值，以便最后对比信号
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1c000000;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(has_int||exc_at_ID||exc_at_EX)begin
        pc <= br_target;
    end
    else if(ID_allowin && IF_readygo)begin
        if(br_taken_ID_r||br_taken_EX_r)
        pc <= nextpc_r;
        else
        pc <= nextpc;
    end
end
always @(posedge clk) begin
    if (reset)
        pc_ID <= 32'h1bfffffc;
    else if(ID_allowin && IF_readygo)
        pc_ID <= pc;
end
always @(posedge clk) begin
    if (reset)
        pc_EX <= 32'h1bfffffc;
    else if(EX_allowin && ID_valid && ID_readygo)
        pc_EX <= pc_ID;
end
always @(posedge clk) begin
    if (reset)
        pc_MEM <= 32'h1bfffffc;
    else if(MEM_allowin && EX_valid && EX_readygo)
        pc_MEM <= pc_EX;
end
always @(posedge clk) begin
    if (reset)
        pc_WB <= 32'h1bfffffc;
    else if(WB_allowin && MEM_valid && MEM_readygo)
        pc_WB <= pc_MEM;
end
/****************************************************************************/


//异常处理及控制状态寄存器
/****************************************************************************/
assign csr_re = (inst_csrrd || inst_csrwr || inst_csrxchg) && ID_valid;
assign csr_we = (inst_csrwr || inst_csrxchg) && ID_valid;
assign csr_wmask = (inst_csrwr)? 32'hffffffff :
                    (inst_csrxchg)? rj_value : 32'h00000000;
assign csr_wvalue = rkd_value;

//异常判断
assign exc_adef = pc[1:0] != 2'b00;
assign exc_ale  = (data_sram_type_tag_EX[2] && data_sram_addr_EX[0] != 1'b0
                || data_sram_type_tag_EX[1] && data_sram_addr_EX[1:0] != 2'b0) && EX_valid;
assign exc_ine = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor 
                 | inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w 
                 | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w 
                 | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddu12i 
                 | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu 
                 | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h 
                 | inst_blt | inst_bge | inst_bltu | inst_bgeu 
                 | inst_csrrd | inst_csrwr | inst_csrxchg 
                 | inst_ertn | inst_syscall | inst_break
                 | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w) && ID_valid;
assign exc_break = inst_break && ID_valid;
assign exc_syscall = inst_syscall && ID_valid;

assign exc_at_ID = exc_break || exc_syscall || exc_adef || exc_ine;
assign exc_at_EX = exc_ale;

assign wb_ex = exc_at_ID || exc_at_EX || has_int;
assign wb_pc = (exc_adef) ? pc :
                (has_int||exc_at_ID)?((ID_valid)?pc_ID:(pc_ID_is_b)?pc_ID:pc):
               ((!br_taken_EX && ID_valid)||br_taken_ID_r) ? ( pc_ID) :
                pc_EX;
assign ertn_flush = inst_ertn && ID_valid;
assign wb_ecode = has_int     ? `ECODE_INT :
                  exc_adef    ? `ECODE_ADE :
                  exc_ale     ? `ECODE_ALE : 
                  exc_syscall ? `ECODE_SYS :
                  exc_break   ? `ECODE_BRK : 
                  exc_ine     ? `ECODE_INE :
                  6'h0;
assign wb_esubcode = 9'h0;
reg pc_ID_is_b;
always @(posedge clk) begin
    if (reset) begin
        pc_ID_is_b <= 1'b0;
    end
    else if(ID_allowin && IF_readygo) begin
        pc_ID_is_b <= is_b;
    end
end
csr u_csr(
    .clk(clk),
    .reset(reset),
    .csr_we(csr_we),
    .csr_re(csr_re),
    .csr_num(csr_num),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    .csr_rvalue(csr_rvalue),
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush),
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .wb_pc(wb_pc),
    .wb_vaddr(data_sram_addr_EX),
    .ex_entry(ex_entry),
    .ex_epc(ex_epc),
    .has_int(has_int),
    .counter_id(counter_id)
);
/****************************************************************************/


//IF流水级
/****************************************************************************/
assign inst_sram_req    = !inst_first_woshou&&ID_allowin && !exc_adef;//取值地址异常时不进行取指
assign inst_sram_wstrb  = 4'b0;
assign inst_sram_wr     = 1'b0;
assign inst_sram_size   = 2'b10;
assign inst_sram_addr   = pc;
assign inst_sram_wdata  = 32'b0;
assign inst = (is_inst_ID)?inst_ID:inst_sram_rdata;
/****************************************************************************/





// IF  --->  ID

// inst      指令
// PC_ID



//ID流水级
/****************************************************************************/
//译码
assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign op_25_24  = inst[25:24];
assign op_14_10  = inst[14:10];
assign op_9_5    = inst[9:5];
assign op_4_0    = inst[4:0];

assign csr_num   = inst[23:10];

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
decoder_2_4  u_dec4(.in(op_25_24 ), .out(op_25_24_d ));
decoder_5_32 u_dec5(.in(op_14_10 ), .out(op_14_10_d ));
decoder_5_32 u_dec6(.in(op_9_5   ), .out(op_9_5_d   ));
decoder_5_32 u_dec7(.in(op_4_0   ), .out(op_4_0_d   ));

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
//新添加算术逻辑运算指令有效信号
assign inst_slti     = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltiu    = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi     = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori      = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori     = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i= op_31_26_d[6'h07] & ~inst[25];
//新添加乘除运算指令有效信号
assign inst_mul_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//新添加访存指令有效信号
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
//新添加分支指令有效信号
assign inst_blt     = op_31_26_d[6'h18];
assign inst_bge     = op_31_26_d[6'h19];
assign inst_bltu    = op_31_26_d[6'h1a];
assign inst_bgeu    = op_31_26_d[6'h1b];
//新添加CSR指令有效信号
assign inst_csrrd   = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h0];
assign inst_csrwr   = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h1];
assign inst_csrxchg = op_31_26_d[6'h01] & op_25_24_d[2'h0] & ~op_9_5_d[5'h0] & ~op_9_5_d[5'h1];
//新添加异常指令有效信号
assign inst_ertn    = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e];
assign inst_syscall = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break   = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
//新添加rdcnt指令有效信号
assign inst_rdcntvl_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & op_14_10_d[5'h18] & op_9_5_d[5'h0];
assign inst_rdcntvh_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & op_14_10_d[5'h19] & op_9_5_d[5'h0];
assign inst_rdcntid_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & op_14_10_d[5'h18] & op_4_0_d[5'h0];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w 
                    | inst_st_b | inst_st_h | inst_st_w | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt|inst_slti;
assign alu_op[ 3] = inst_sltu|inst_sltiu;
assign alu_op[ 4] = inst_and|inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or|inst_ori;
assign alu_op[ 7] = inst_xor|inst_xori;
assign alu_op[ 8] = inst_slli_w|inst_sll_w;
assign alu_op[ 9] = inst_srli_w|inst_srl_w;
assign alu_op[10] = inst_srai_w|inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w 
                     | inst_st_b | inst_st_h | inst_st_w | inst_slti | inst_sltiu;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w|inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


/******** 前递块 ********/
assign need_rj    =  ~(inst_b | inst_bl | inst_lu12i_w);
assign need_rk    =  inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | inst_xor | inst_sll_w | inst_srl_w | inst_sra_w |
                inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu; 
assign need_rd    =  inst_beq | inst_bne | inst_st_b | inst_st_h | inst_st_w | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg;

assign dest_EX_ID = dest_EX & {5{gr_we_EX}} & {5{EX_valid}};
assign dest_MEM_ID = dest_MEM & {5{gr_we_MEM}} & {5{MEM_valid}};
assign dest_WB_ID = dest_WB & {5{gr_we_WB}} & {5{WB_valid}};

assign rj_hit = need_rj && (rj != 5'd0) && ((rj == dest_EX_ID) || (rj == dest_MEM_ID) || (rj == dest_WB_ID));
assign rk_hit = need_rk && (rk != 5'd0) && ((rk == dest_EX_ID) || (rk == dest_MEM_ID) || (rk == dest_WB_ID));
assign rd_hit = need_rd && (rd != 5'd0) && ((rd == dest_EX_ID) || (rd == dest_MEM_ID) || (rd == dest_WB_ID));

assign reg_EX_hit = need_rj && (rj != 5'd0) && (rj == dest_EX_ID) || need_rk && (rk != 5'd0) && (rk == dest_EX_ID) || need_rd && (rd != 5'd0) && (rd == dest_EX_ID);
assign reg_MEM_hit = need_rj && (rj != 5'd0) && (rj == dest_MEM_ID) || need_rk && (rk != 5'd0) && (rk == dest_MEM_ID) || need_rd && (rd != 5'd0) && (rd == dest_MEM_ID);
assign reg_WB_hit = need_rj && (rj != 5'd0) && (rj == dest_WB_ID) || need_rk && (rk != 5'd0) && (rk == dest_WB_ID) || need_rd && (rd != 5'd0) && (rd == dest_WB_ID);

assign rj_pro = (rj == dest_EX_ID) ? EX_final_result :
                (rj == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign rk_pro = (rk == dest_EX_ID) ? EX_final_result :
                (rk == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign rd_pro = (rd == dest_EX_ID) ? EX_final_result :
                (rd == dest_MEM_ID) ? data_sram_addr_MEM :
                final_result ;

assign hit_wait = reg_EX_hit && data_sram_req_EX || reg_MEM_hit && data_sram_req_MEM;
/******** 前递块 ********/


assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {{20{1'b0}}, i12[11:0]} :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;//gaidong

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_b | inst_st_h | inst_st_w | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_ld_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltiu  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i;

assign res_from_mem  = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
assign dst_is_r1     = inst_bl;
assign dst_is_rj     = inst_rdcntid_w;
assign gr_we         = ~inst_st_b & ~inst_st_h & ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_ertn & ~inst_syscall;
assign dest          = dst_is_r1 ? 5'd1 :
                       dst_is_rj ? rj :
                       rd;


/******** 寄存器读取块 ********/
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
/******** 寄存器读取块 ********/


/******** 分支判断块 ********/
assign rj_sign = {{rj_value[31] & ~inst_bltu & ~inst_bgeu}, rj_value};
assign rd_sign = {{rkd_value[31] & ~inst_bltu & ~inst_bgeu}, rkd_value};

assign rj_lt_rd = $signed(rj_sign) < $signed(rd_sign);

assign rj_eq_rd = (rj_value == rkd_value);
// - 将跳转分为在ID的跳转以及在EX的跳转，EX的跳转相比ID的跳转额外取消一条错取指令
wire is_b;
assign is_b = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_jirl | inst_b;
assign br_taken_ID = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  &&  !rj_lt_rd
                   || inst_bltu &&  rj_lt_rd
                   || inst_bgeu &&  !rj_lt_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                   || inst_ertn
                   ) && ID_valid || exc_at_ID || has_int;
assign br_taken_EX = exc_at_EX;
// - 调整了一下br_target的优先级
assign br_target =  (wb_ex) ? ex_entry :
                    (inst_ertn) ? ex_epc :
                    (inst_jirl) ? (rj_value + jirl_offs) :
                    (pc_ID + br_offs);//branch
/******** 分支判断块 ********/


assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;
assign need_div = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu; 
assign div_signed = inst_div_w | inst_mod_w;
assign div_unsigned = inst_div_wu | inst_mod_wu;
assign get_div_or_mod = inst_div_w | inst_div_wu;

assign data_sram_req_ID    = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w | inst_st_b | inst_st_h | inst_st_w;
assign data_sram_wr_ID   = inst_st_b | inst_st_h | inst_st_w;
assign data_sram_size_ID = (inst_ld_b | inst_ld_bu | inst_st_b )?2'b00:(inst_ld_h | inst_ld_hu | inst_st_h)?2'b01:2'b10;
assign data_sram_wstrb_ID    = {4{inst_st_w}} | {2'b00, {2{inst_st_h}}} | {3'b000, inst_st_b};
assign data_sram_wdata_ID = inst_st_b ? {4{rkd_value[ 7:0]}} :
                            inst_st_h ? {2{rkd_value[15:0]}} :
                            rkd_value;
assign data_sram_type_tag = {{inst_ld_b | inst_ld_bu | inst_st_b}, {inst_ld_h | inst_ld_hu | inst_st_h}, {inst_st_w | inst_ld_w}, {inst_ld_bu | inst_ld_hu}};// {byte_en, half_en, unsigned_en}

//将alu及除法器输入保存到EX阶段并使用
always @(posedge clk) begin
    if(reset) begin
        alu_src1_r <= 32'h0;
        alu_src2_r <= 32'h0;
        alu_op_r   <= 15'h0;
        div_signed_r <= 1'b0;
        div_unsigned_r <= 1'b0;
        get_div_or_mod_r <= 1'b0;
    end
    else if(ID_valid && EX_allowin && ID_readygo)begin
        alu_src1_r <= alu_src1;
        alu_src2_r <= alu_src2;
        alu_op_r   <= alu_op;
        div_signed_r <= div_signed;
        div_unsigned_r <= div_unsigned;
        get_div_or_mod_r <= get_div_or_mod;
    end
end
//将一些后续控制信号从ID阶段传递下去
always @(posedge clk) begin //寄存器控制
    if(reset) begin
        is_csr_EX <= 1'b0;
        csr_rvalue_EX <= 32'h0;
        is_rdcntid_EX <= 1'b0;
        is_rdcntvl_EX <= 1'b0;
        is_rdcntvh_EX <= 1'b0;
    end
    else if(EX_allowin && ID_valid && ID_readygo) begin
        is_csr_EX <= csr_re;
        csr_rvalue_EX <= csr_rvalue;
        is_rdcntid_EX <= inst_rdcntid_w;
        is_rdcntvl_EX <= inst_rdcntvl_w;
        is_rdcntvh_EX <= inst_rdcntvh_w;
    end
end
always @(posedge clk) begin //寄存器控制
    if(reset) begin
        res_from_mem_EX <= 1'b0;
        dest_EX <= 5'd0;
        gr_we_EX <= 1'b0;
    end
    else if(EX_allowin && ID_valid && ID_readygo) begin
        res_from_mem_EX <= res_from_mem;
        dest_EX <= dest;
        gr_we_EX <= gr_we;
    end
end
always @(posedge clk) begin //访存控制
    if(reset) begin
        data_sram_req_EX <= 1'b0;
        data_sram_wstrb_EX <= 4'b0;
        data_sram_wdata_EX <= 32'h0;
        data_sram_type_tag_EX <= 4'b0;
        data_sram_sze_EX <= 2'b0;
        data_sram_wr_EX <= 1'b0;
    end
    else if(ID_valid && EX_allowin && ID_readygo) begin
        data_sram_req_EX <= data_sram_req_ID;
        data_sram_wstrb_EX <= data_sram_wstrb_ID;
        data_sram_wdata_EX <= data_sram_wdata_ID;
        data_sram_type_tag_EX <= data_sram_type_tag;
        data_sram_size_EX <= data_sram_size_ID;
        data_sram_wr_EX <= data_sram_wr_ID;
    end
end
/****************************************************************************/


//ID --> EX

// alu_src1_r, alu_src2_r, alu_op_r      alu相关信号
// res_from_mem_EX, dest_EX, gr_we_EX      寄存器相关信号
// data_sram_req_EX, data_sram_wstrb_EX, data_sram_wdata_EX      访存相关信号
// sdiv_sor_valid, sdiv_dend_valid, need_div_r      除法器相关信号
// PC_EX


/********除法器模块********/
reg  sdiv_sor_valid, sdiv_dend_valid;
wire sdiv_sor_ready, sdiv_dend_ready, sdiv_out_valid;
reg  udiv_sor_valid, udiv_dend_valid;
wire udiv_sor_ready, udiv_dend_ready, udiv_out_valid;
always @(posedge clk) begin
    if(reset) begin
        sdiv_sor_valid <= 1'b0;
        sdiv_dend_valid <= 1'b0;
        udiv_sor_valid <= 1'b0;
        udiv_dend_valid <= 1'b0;
    end
    else if(ID_valid && EX_allowin && ID_readygo) begin
        sdiv_sor_valid <= div_signed;
        sdiv_dend_valid <= div_signed;
        udiv_sor_valid <= div_unsigned;
        udiv_dend_valid <= div_unsigned;
    end
    else begin //除法器的bug修复(与prj4无关)
        if (sdiv_sor_ready || sdiv_dend_ready) begin
            sdiv_sor_valid <= !sdiv_sor_ready && sdiv_sor_valid;
            sdiv_dend_valid <= !sdiv_dend_ready && sdiv_dend_valid;
        end
        if (udiv_sor_ready || udiv_dend_ready) begin
            udiv_sor_valid <= !udiv_sor_ready && udiv_sor_valid;
            udiv_dend_valid <= !udiv_dend_ready && udiv_dend_valid;
        end
    end
end
always @(posedge clk) begin
    if(reset) begin
        need_div_r <= 1'b0;
    end
    else if(ID_valid && EX_allowin && ID_readygo) begin
        need_div_r <= need_div;
    end
    else if (sdiv_out_valid || udiv_out_valid)  begin
        need_div_r <= 1'b0;
    end
end
/********除法器模块********/


//EX流水级
/****************************************************************************/
alu u_alu(// alu进行运算
    .alu_op     (alu_op_r    ),
    .alu_src1   (alu_src1_r  ),
    .alu_src2   (alu_src2_r  ),
    .alu_result (alu_result)
    );

div_gen_signed u_div_gen_signed(// 进行符号除法运算
    .aclk                   (clk         ),
    .s_axis_divisor_tdata   (alu_src2_r  ),
    .s_axis_divisor_tvalid  (sdiv_sor_valid),
    .s_axis_divisor_tready  (sdiv_sor_ready),
    .s_axis_dividend_tdata  (alu_src1_r  ),
    .s_axis_dividend_tvalid (sdiv_dend_valid),
    .s_axis_dividend_tready (sdiv_dend_ready),
    .m_axis_dout_tdata      (sdiv_result  ),
    .m_axis_dout_tvalid     (sdiv_out_valid)
    );

div_gen_unsigned u_div_gen_unsigned(// 进行无符号除法运算
    .aclk                   (clk         ),
    .s_axis_divisor_tdata   (alu_src2_r  ),
    .s_axis_divisor_tvalid  (udiv_sor_valid),
    .s_axis_divisor_tready  (udiv_sor_ready),
    .s_axis_dividend_tdata  (alu_src1_r  ),
    .s_axis_dividend_tvalid (udiv_dend_valid),
    .s_axis_dividend_tready (udiv_dend_ready),
    .m_axis_dout_tdata      (udiv_result  ),
    .m_axis_dout_tvalid     (udiv_out_valid)
    );

assign EX_final_result =  div_signed_r ? (get_div_or_mod_r ? sdiv_result[63:32] : sdiv_result[31:0]):
                          div_unsigned_r ? (get_div_or_mod_r ? udiv_result[63:32] : udiv_result[31:0]):
                          (is_csr_EX)?csr_rvalue_EX://csr指令直接从csr中取值
                          (is_rdcntid_EX)?counter_id:
                          (is_rdcntvl_EX)?counter_vl:
                          (is_rdcntvh_EX)?counter_vh:
                          alu_result;
assign data_sram_addr_EX  = EX_final_result;//设计访存地址

//将一些后续控制信号从EX传递下去
always @(posedge clk) begin//访存控制
    if(reset) begin
        data_sram_req_MEM <= 1'b0;
        data_sram_wstrb_MEM <= 4'b0;
        data_sram_addr_MEM <= 32'h0;
        data_sram_wdata_MEM <= 32'h0;
        data_sram_type_tag_MEM <= 4'b0;
        data_sram_size_MEM <= 2'b0;
        data_sram_wr_MEM <= 1'b0;
    end
    else if(MEM_allowin && EX_valid && EX_readygo) begin
        data_sram_req_MEM <= data_sram_req_EX;
        data_sram_wstrb_MEM <= (data_sram_wstrb_EX << alu_result[1:0]);
        data_sram_addr_MEM <= data_sram_addr_EX;
        data_sram_wdata_MEM <= data_sram_wdata_EX;
        data_sram_type_tag_MEM <= data_sram_type_tag_EX;
        data_sram_size_MEM <= data_sram_size_EX;
        data_sram_wr_MEM <= data_sram_wr_EX;
    end
end
always @(posedge clk) begin//寄存器控制
    if(reset) begin
        res_from_mem_MEM <= 1'b0;
        dest_MEM <= 5'd0;
        gr_we_MEM <= 1'b0;
    end
    else if(MEM_allowin && EX_valid && EX_readygo) begin
        res_from_mem_MEM <= res_from_mem_EX;
        dest_MEM <= dest_EX;
        gr_we_MEM <= gr_we_EX;
    end
end
/****************************************************************************/



//EX --> MEM

// data_sram_req_MEM, data_sram_wstrb_MEM, data_sram_addr_MEM, data_sram_wdata_MEM, data_sram_type_tag_MEM      访存相关信号
// res_from_mem_MEM, dest_MEM, gr_we_MEM      寄存器相关信号
// PC_MEM



//MEM流水级
/****************************************************************************/
//设置访存信号
assign data_sram_req = !data_first_woshou &&data_sram_req_MEM && MEM_valid ; // - 小补丁，防止后续埋雷
assign data_sram_wr = data_sram_wr_MEM & MEM_valid ; // - 小补丁，防止后续埋雷
assign data_sram_size = data_sram_size_MEM ;
assign data_sram_wstrb = data_sram_wstrb_MEM;
assign data_sram_addr = data_sram_addr_MEM;
assign data_sram_addroffset = data_sram_addr_MEM[1:0];//访存偏移
assign data_sram_wdata = data_sram_wdata_MEM;

//将一些后续控制信号从MEM传递下去
always @(posedge clk) begin
    if(reset) begin
        alu_result_WB <= 32'h0;
        res_from_mem_WB <= 1'b0;
        dest_WB <= 5'd0;
        gr_we_WB <= 1'b0;
        data_sram_type_tag_WB <= 4'b0;
        data_sram_addroffset_WB <= 2'b0;
    end
    else if(WB_allowin && MEM_valid && MEM_readygo) begin
        alu_result_WB <= data_sram_addr_MEM;
        res_from_mem_WB <= res_from_mem_MEM;
        dest_WB <= dest_MEM;
        gr_we_WB <= gr_we_MEM;
        data_sram_type_tag_WB <= data_sram_type_tag_MEM;
        data_sram_addroffset_WB <= data_sram_addroffset;
    end
end

assign data_sram_rdata_off = data_sram_rdata >> (data_sram_addroffset_WB * 8);
assign mem_result   = data_sram_type_tag_WB[3]? {{24{data_sram_rdata_off[7] & ~data_sram_type_tag_WB[0]}}, data_sram_rdata_off[7:0]} :
                      data_sram_type_tag_WB[2]? {{16{data_sram_rdata_off[15] & ~data_sram_type_tag_WB[0]}}, data_sram_rdata_off[15:0]} :
                      data_sram_rdata_off;
/****************************************************************************/



//MEM --> WB

// res_from_mem_WB, dest_WB, gr_we_WB      寄存器相关信号
// mem_result, alu_result_WB      访存及寄存器结果
// PC_WB


//WB流水级
/****************************************************************************/
assign final_result = res_from_mem_WB ? mem_result : alu_result_WB; // 最终写回数据

assign rf_we    = gr_we_WB && WB_valid && WB_readygo;
assign rf_waddr = dest_WB;
assign rf_wdata = final_result;
/****************************************************************************/


// debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest_WB;
assign debug_wb_rf_wdata = final_result;


endmodule