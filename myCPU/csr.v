`include "csr.vh"
`define TLBNUM 16
`define PALEN 32
module csr
#(
    parameter TLBNUM = `TLBNUM,
    parameter PALEN = `PALEN
)
(
    input  wire        clk,
    input  wire        reset,

    input  wire        csr_we,
    input  wire        csr_re,
    input  wire [13:0] csr_num,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,
    output wire [31:0] csr_rvalue,

    input  wire        wb_ex,
    input  wire        ertn_flush,
    input  wire [ 5:0] wb_ecode,
    input  wire [ 8:0] wb_esubcode,
    input  wire [31:0] wb_pc,
    input  wire        wb_badv,
    input  wire [31:0] wb_vaddr,
    input  wire        wb_tlbr,

    output wire [31:0] ex_entry,
    output wire [31:0] ex_epc,
    output wire        has_int,
    output wire [31:0] counter_id,

    output wire [31:0] csr_tlbelo0_rvalue,
    output wire [31:0] csr_tlbelo1_rvalue,
    output wire [31:0] csr_tlbidx_rvalue,
    output wire [31:0] csr_estat_rvalue,
    output wire [31:0] csr_tlbrentry_rvalue,
    output wire [18:0] tlbehi_vppn,
    output wire [ 9:0] asid,
    output wire [ 1:0] plv,
    output wire        da,
    output wire        pg,

    input  wire [ 2:0] addr_vseg0,
    input  wire [ 2:0] addr_vseg1,
    output wire        dmw_hit0,
    output wire        dmw_hit1,
    output wire [ 2:0] addr_pseg0,
    output wire [ 2:0] addr_pseg1,

    input  wire        inst_TLBSRCH_valid,
    input  wire        inst_TLBRD_valid,
    input  wire        inst_TLBWR_valid,
    input  wire        inst_TLBFILL_valid,

    input wire s1_found,
    input wire [$clog2(TLBNUM) - 1:0] s1_index,
    input  wire            r_e,
    input  wire [ 18:0]    r_vppn,
    input  wire [  5:0]    r_ps,
    input  wire [  9:0]    r_asid,
    input  wire            r_g,
    input  wire [ 19:0]    r_ppn0,
    input  wire [  1:0]    r_plv0,
    input  wire [  1:0]    r_mat0,
    input  wire            r_d0,
    input  wire            r_v0,
    input  wire [ 19:0]    r_ppn1,
    input  wire [  1:0]    r_plv1,
    input  wire [  1:0]    r_mat1,
    input  wire            r_d1,
    input  wire            r_v1
);

//CSR寄存器
//CRMD
reg [ 1:0] csr_crmd_plv;
reg        csr_crmd_ie;
reg        csr_crmd_da;
reg        csr_crmd_pg;
reg [ 1:0] csr_crmd_datf;
reg [ 1:0] csr_crmd_datm;
//PRMD
reg [ 1:0] csr_prmd_pplv;
reg        csr_prmd_pie;
//ECFG
reg [12:0] csr_ecfg_lie;
//ESTAT
reg [12:0] csr_estat_is;
reg [ 5:0] csr_estat_ecode;
reg [ 8:0] csr_estat_esubcode;
//ERA
reg [31:0] csr_era_pc;
//BADV
reg [31:0] csr_badv_vaddr;
//EENTRY
reg [25:0] csr_eentry_va;
//SAVE0~3
reg [31:0] csr_save0;
reg [31:0] csr_save1;
reg [31:0] csr_save2;
reg [31:0] csr_save3;
//TID
reg [31:0] csr_tid_tid;
//TCFG
reg        csr_tcfg_en;
reg        csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
//TVAL
wire [31:0] csr_tval_timeval;
//TICLR
wire       csr_ticlr_clr;
//DMW0
reg csr_dmw0_plv0;
reg csr_dmw0_plv3;
reg [1:0]csr_dmw0_mat;
reg [2:0]csr_dmw0_pseg;
reg [2:0]csr_dmw0_vseg;
//DMW1
reg csr_dmw1_plv0;
reg csr_dmw1_plv3;
reg [1:0]csr_dmw1_mat;
reg [2:0]csr_dmw1_pseg;
reg [2:0]csr_dmw1_vseg;
//ASID
reg [9:0]csr_asid_asid;
reg [7:0]csr_asid_asidbits;
//TLBEHI
reg [18:0]csr_tlbehi_vppn;
//TLBELO0、TLBELO1 
reg csr_tlbelo0_v;
reg csr_tlbelo0_d;
reg [1:0]csr_tlbelo0_plv;
reg [1:0]csr_tlbelo0_mat;
reg csr_tlbelo0_g;
reg [PALEN-13:0]csr_tlbelo0_ppn;

reg csr_tlbelo1_v;
reg csr_tlbelo1_d;
reg [1:0]csr_tlbelo1_plv;
reg [1:0]csr_tlbelo1_mat;
reg csr_tlbelo1_g;
reg [PALEN-13:0]csr_tlbelo1_ppn;
//TLBIDX
reg [$clog2(TLBNUM) - 1:0]csr_tlbidx_index;
reg [5:0]csr_tlbidx_ps;
reg csr_tlbidx_ne;
//TLBRENTRY
reg [25:0]csr_tlbrentry_pa;

//timer
reg [31:0] timer_cnt;
wire [31:0] tcfg_next_value;

wire dmw_allow0;
wire dmw_allow1;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
// wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;
wire [31:0] csr_ticlr_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbehi_rvalue;
// wire [31:0] csr_tlbelo0_rvalue;
// wire [31:0] csr_tlbelo1_rvalue;
// wire [31:0] csr_tlbidx_rvalue;


assign csr_crmd_rvalue = {23'b0,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
assign csr_ecfg_rvalue = {19'b0,csr_ecfg_lie};
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is[12:11],1'b0,csr_estat_is[9:0]};
assign csr_era_rvalue = csr_era_pc;
assign csr_badv_rvalue = csr_badv_vaddr;
assign csr_eentry_rvalue = {csr_eentry_va,6'b0};
assign csr_tid_rvalue = csr_tid_tid;
assign csr_tcfg_rvalue = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};
assign csr_tval_rvalue = csr_tval_timeval;
assign csr_ticlr_rvalue = {31'b0,csr_ticlr_clr};
assign csr_tlbehi_rvalue = {csr_tlbehi_vppn,13'b0};
assign csr_tlbelo0_rvalue = {4'b0,csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};
assign csr_tlbelo1_rvalue = {4'b0,csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};
assign csr_tlbidx_rvalue = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,8'b0,12'b0,csr_tlbidx_index};
assign csr_asid_rvalue = {8'b0,csr_asid_asidbits,6'b0,csr_asid_asid};
assign csr_dmw0_rvalue = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};
assign csr_dmw1_rvalue = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};
assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa,6'b0};

assign tlbehi_vppn = csr_tlbehi_vppn;
assign asid = csr_asid_asid;
assign plv = csr_crmd_plv;
assign da = csr_crmd_da;
assign pg = csr_crmd_pg;

//DMW hit control
assign dmw_allow0 = (csr_crmd_plv == 0) && csr_dmw0_plv0 || (csr_crmd_plv == 3) && csr_dmw0_plv3;
assign dmw_allow1 = (csr_crmd_plv == 0) && csr_dmw1_plv0 || (csr_crmd_plv == 3) && csr_dmw1_plv3;
assign dmw_hit0 = dmw_allow0 && (addr_vseg0 == csr_dmw0_vseg) || dmw_allow1 && (addr_vseg0 == csr_dmw1_vseg);
assign dmw_hit1 = dmw_allow0 && (addr_vseg1 == csr_dmw0_vseg) || dmw_allow1 && (addr_vseg1 == csr_dmw1_vseg);
assign addr_pseg0 = (addr_vseg0 == csr_dmw0_vseg) ? csr_dmw0_pseg :
                    (addr_vseg0 == csr_dmw1_vseg) ? csr_dmw1_pseg : 3'b000;
assign addr_pseg1 = (addr_vseg1 == csr_dmw0_vseg) ? csr_dmw0_pseg :
                    (addr_vseg1 == csr_dmw1_vseg) ? csr_dmw1_pseg : 3'b000;

assign csr_rvalue =     csr_num == `CSR_CRMD   ? csr_crmd_rvalue :
                        csr_num == `CSR_PRMD   ? csr_prmd_rvalue :
                        csr_num == `CSR_ECFG   ? csr_ecfg_rvalue :
                        csr_num == `CSR_ESTAT  ? csr_estat_rvalue :
                        csr_num == `CSR_ERA    ? csr_era_rvalue :
                        csr_num == `CSR_BADV   ? csr_badv_rvalue :
                        csr_num == `CSR_EENTRY ? csr_eentry_rvalue :
                        csr_num == `CSR_SAVE0  ? csr_save0 :
                        csr_num == `CSR_SAVE1  ? csr_save1 :
                        csr_num == `CSR_SAVE2  ? csr_save2 :
                        csr_num == `CSR_SAVE3  ? csr_save3 : 
                        csr_num == `CSR_TID    ? csr_tid_rvalue :
                        csr_num == `CSR_TCFG   ? csr_tcfg_rvalue :
                        csr_num == `CSR_TVAL   ? csr_tval_rvalue :
                        csr_num == `CSR_TICLR  ? csr_ticlr_rvalue :
                        csr_num == `CSR_TLBEHI ? csr_tlbehi_rvalue :
                        csr_num == `CSR_TLBELO0? csr_tlbelo0_rvalue :
                        csr_num == `CSR_TLBELO1? csr_tlbelo1_rvalue :
                        csr_num == `CSR_TLBIDX ? csr_tlbidx_rvalue :
                        csr_num == `CSR_ASID   ? csr_asid_rvalue :
                        csr_num == `CSR_DMW0   ? csr_dmw0_rvalue :
                        csr_num == `CSR_DMW1   ? csr_dmw1_rvalue :
                        csr_num == `CSR_TLBRENTRY? csr_tlbrentry_rvalue :
                        32'b0;
assign ex_entry = csr_eentry_rvalue;
assign ex_epc = csr_era_rvalue;
assign has_int = (csr_estat_is[12:0] & csr_ecfg_lie[12:0])!= 13'b0 && csr_crmd_ie;
assign counter_id = csr_tid_tid;

//CRMD 的 PLV 域以及 IE 域
always @(posedge clk) begin
    if (reset) begin
        csr_crmd_plv <= 2'b00;
        csr_crmd_ie  <= 1'b0;
    end
    else if(wb_ex)begin
        csr_crmd_plv <= 2'b00;
        csr_crmd_ie <= 1'b0;
    end
    else if(ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if(csr_we && csr_num == `CSR_CRMD)  begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                    |  ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                    |  ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end
end

//CRMD 的DA、PG、DATF、DATM 域
always @(posedge clk) begin
    if (reset) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
        csr_crmd_datf <= 2'b00;
        csr_crmd_datm <= 2'b00;
    end
    else if(wb_tlbr) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_flush && csr_estat_ecode == `ECODE_TLBR) begin
        csr_crmd_da <= 1'b0;
        csr_crmd_pg <= 1'b1;
    end
    else if(csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                    |  ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                    |  ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                    |  ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                    |  ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
    end
end

//PRMD 的 PPLV 域以及 PIE 域
always @(posedge clk) begin
    if(reset)begin
        csr_prmd_pplv <= 2'b00;
        csr_prmd_pie <= 1'b0;
    end
    else if(wb_ex)begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if(csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                    |   ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                    |   ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

//ECFG 的 LIE 域
always @(posedge clk) begin
    if(reset)begin
        csr_ecfg_lie <= 13'b0;
    end
    else if(csr_we && csr_num==`CSR_ECFG)begin
         csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                    |   ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end
end

//ESTAT 的 IS 域
always @(posedge clk) begin
    if(reset)begin
        csr_estat_is[1:0] <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_ESTAT) begin
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                        |   ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    end
    csr_estat_is[9:2] <= 8'b0;
    csr_estat_is[10] <= 1'b0;
    
    if(reset) begin
        csr_estat_is[11] <= 1'b0;
    end
    else if(timer_cnt == 32'b0) begin
        csr_estat_is[11] <= 1'b1;
    end
    else if(csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) begin
        csr_estat_is[11] <= 1'b0;
    end

    csr_estat_is[12] <= 1'b0;
end

//ESTAT 的 ECODE 域以及 ESUBCODE 域
always @(posedge clk) begin
    if(reset) begin
        csr_estat_ecode <= 6'b0;
        csr_estat_esubcode <= 8'b0;
    end
    else if(wb_ex)begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

//ERA 的 PC 域
always @(posedge clk) begin
    if(wb_ex)begin
        csr_era_pc <= wb_pc;
    end
    else if(csr_we && csr_num==`CSR_ERA) begin
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                  |  ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end
end

//BADV 的 VADDR 域

always @(posedge clk) begin
    if(wb_badv || wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE) begin
        csr_badv_vaddr <= wb_vaddr;
    end
end

//EENTRY 的 VA 域
always @(posedge clk) begin
    if(csr_we && csr_num==`CSR_EENTRY) begin
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                    |   ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
end

//SAVE0~3 的数据域
always @(posedge clk) begin
    if(csr_we && csr_num==`CSR_SAVE0) begin
        csr_save0 <= csr_wmask[`CSR_SAVE0_DATA] & csr_wvalue[`CSR_SAVE0_DATA]
                  |  ~csr_wmask[`CSR_SAVE0_DATA] & csr_save0;
    end
    else if(csr_we && csr_num==`CSR_SAVE1) begin
        csr_save1 <= csr_wmask[`CSR_SAVE1_DATA] & csr_wvalue[`CSR_SAVE1_DATA]
                  |  ~csr_wmask[`CSR_SAVE1_DATA] & csr_save1;
    end
    else if(csr_we && csr_num==`CSR_SAVE2) begin
        csr_save2 <= csr_wmask[`CSR_SAVE2_DATA] & csr_wvalue[`CSR_SAVE2_DATA]
                  |  ~csr_wmask[`CSR_SAVE2_DATA] & csr_save2;
    end
    else if(csr_we && csr_num==`CSR_SAVE3) begin
        csr_save3 <= csr_wmask[`CSR_SAVE3_DATA] & csr_wvalue[`CSR_SAVE3_DATA]
                  |  ~csr_wmask[`CSR_SAVE3_DATA] & csr_save3;
    end
end

//TID 的数据域
always @(posedge clk) begin
    if(reset) begin
        csr_tid_tid <= 32'b0;
    end
    else if(csr_we && csr_num==`CSR_TID) begin
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                |    ~ csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end
end

//TCFG 的 EN、PERIODIC、INITVAL 域
always @(posedge clk) begin
    if(reset) begin
        csr_tcfg_en <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                |    ~ csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    end

    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC]
                        |   ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]
                        |  ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
    end
end

//TVAL 的 TIMEVAL 域
assign csr_tval_timeval = timer_cnt[31:0];

//定时器
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0] 
                    |   ~csr_wmask[31:0] & csr_tcfg_rvalue;
always @(posedge clk) begin
    if(reset) begin
        timer_cnt <= 32'hffffffff;
    end
    else if(csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) begin
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    end
    else if(csr_tcfg_en && timer_cnt != 32'hffffffff) begin
        if(timer_cnt == 32'b0 && csr_tcfg_periodic) begin
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        end
        else begin
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
end

//TICLR 的 CLR 域
assign csr_ticlr_clr = 1'b0;

//ASID 的 ASID   域
always @(posedge clk) begin
    if(reset) begin
        csr_asid_asid <= 4'b0;
    end
    else if(csr_we && csr_num==`CSR_ASID) begin
        csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                    |   ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_asid_asid <= r_asid;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_asid_asid <= 4'b0;
    end

end
//ASID 的 ASIDBITS  域
always @(posedge clk) begin
    if(reset) begin
        csr_asid_asidbits <= 8'h0a;
    end
    // else if(csr_we && csr_num==`CSR_ASID) begin
    //     csr_asid_asidbits <= csr_wmask[`CSR_ASID_ASIDBITS] & csr_wvalue[`CSR_ASID_ASIDBITS]
    //                 |   ~csr_wmask[`CSR_ASID_ASIDBITS] & csr_asid_asidbits;
    // end
end

//TLBIDX 的 Index域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_index <= 15'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                    |   ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
    end
    else if(inst_TLBSRCH_valid && s1_found) begin
        csr_tlbidx_index <= s1_index;
    end
end
//TLBIDX 的 PS域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_ps <= 6'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                    |   ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbidx_ps <= r_ps;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbidx_ps <= 6'b0;
    end
end
//TLBIDX 的 NE域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_ne <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                    |   ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
    end
    else if(inst_TLBSRCH_valid) begin
        if(s1_found) begin
            csr_tlbidx_ne <= 1'b0;
        end
        else begin
            csr_tlbidx_ne <= 1'b1;
        end
    end
    else if(inst_TLBRD_valid) begin
        if(r_e) begin
        csr_tlbidx_ne <= 1'b0;
        end
        else begin
            csr_tlbidx_ne <= 1'b1;
        end
    end
end

//TLBEHI 的 VPPN域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBEHI) begin
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                    |   ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbehi_vppn <= r_vppn;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(wb_badv) begin
        csr_tlbehi_vppn <= wb_vaddr[31:13];
    end
end

//TLBELO0 的 V域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_v <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_v <= csr_wmask[`CSR_TLBELO0_V] & csr_wvalue[`CSR_TLBELO0_V]
                    |   ~csr_wmask[`CSR_TLBELO0_V] & csr_tlbelo0_v;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_v <= r_v0;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_v <= 1'b0;
    end
end

//TLBELO0 的 G域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_g <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_g <= csr_wmask[`CSR_TLBELO0_G] & csr_wvalue[`CSR_TLBELO0_G]
                    |   ~csr_wmask[`CSR_TLBELO0_G] & csr_tlbelo0_g;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_g <= r_g;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_g <= 1'b0;
    end
end

//TLBELO0 的 D域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_d <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_d <= csr_wmask[`CSR_TLBELO0_D] & csr_wvalue[`CSR_TLBELO0_D]
                    |   ~csr_wmask[`CSR_TLBELO0_D] & csr_tlbelo0_d;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_d <= r_d0;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_d <= 1'b0;
    end
end

//TLBELO0 的 PLV域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_plv <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]
                    |   ~csr_wmask[`CSR_TLBELO0_PLV] & csr_tlbelo0_plv;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_plv <= r_plv0;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_plv <= 2'b0;
    end
end
//TLBELO0 的 MAT域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_mat <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO0_MAT] & csr_wvalue[`CSR_TLBELO0_MAT]
                    |   ~csr_wmask[`CSR_TLBELO0_MAT] & csr_tlbelo0_mat;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_mat <= r_mat0;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_mat <= 2'b0;
    end
end

//TLBELO0 的 PPN域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_ppn <= 20'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO0_PPN] & csr_wvalue[`CSR_TLBELO0_PPN]
                    |   ~csr_wmask[`CSR_TLBELO0_PPN] & csr_tlbelo0_ppn;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo0_ppn <= r_ppn0;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo0_ppn <= 20'b0;
    end
end

//TLBELO1 的 V域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_v <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_v <= csr_wmask[`CSR_TLBELO1_V] & csr_wvalue[`CSR_TLBELO1_V]
                    |   ~csr_wmask[`CSR_TLBELO1_V] & csr_tlbelo1_v;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_v <= r_v1;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_v <= 1'b0;
    end
end

//TLBELO1 的 G域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_g <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_g <= csr_wmask[`CSR_TLBELO1_G] & csr_wvalue[`CSR_TLBELO1_G]
                    |   ~csr_wmask[`CSR_TLBELO1_G] & csr_tlbelo1_g;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_g <= r_g;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_g <= 1'b0;
    end
end

//TLBELO1 的 D域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_d <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_d <= csr_wmask[`CSR_TLBELO1_D] & csr_wvalue[`CSR_TLBELO1_D]
                    |   ~csr_wmask[`CSR_TLBELO1_D] & csr_tlbelo1_d;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_d <= r_d1;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_d <= 1'b0;
    end
end

//TLBELO1 的 PLV域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_plv <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]
                    |   ~csr_wmask[`CSR_TLBELO1_PLV] & csr_tlbelo1_plv;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_plv <= r_plv1;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_plv <= 2'b0;
    end
end
//TLBELO1 的 MAT域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_mat <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO1_MAT] & csr_wvalue[`CSR_TLBELO1_MAT]
                    |   ~csr_wmask[`CSR_TLBELO1_MAT] & csr_tlbelo1_mat;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_mat <= r_mat1;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_mat <= 2'b0;
    end
end

//TLBELO1 的 PPN域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_ppn <= 20'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO1_PPN] & csr_wvalue[`CSR_TLBELO1_PPN]
                    |   ~csr_wmask[`CSR_TLBELO1_PPN] & csr_tlbelo1_ppn;
    end
    else if(inst_TLBRD_valid && r_e) begin
        csr_tlbelo1_ppn <= r_ppn1;
    end
    else if(inst_TLBRD_valid && !r_e) begin
        csr_tlbelo1_ppn <= 20'b0;
    end
end

//DMW0 的 PLV0域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_plv0 <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_plv0 <= csr_wmask[`CSR_DMW0_PLV0] & csr_wvalue[`CSR_DMW0_PLV0]
                    |   ~csr_wmask[`CSR_DMW0_PLV0] & csr_dmw0_plv0;
    end
end
//DMW0 的 PLV3域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_plv3 <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_plv3 <= csr_wmask[`CSR_DMW0_PLV3] & csr_wvalue[`CSR_DMW0_PLV3]
                    |   ~csr_wmask[`CSR_DMW0_PLV3] & csr_dmw0_plv3;
    end
end
//DMW0 的 MAT域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_mat <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_mat <= csr_wmask[`CSR_DMW0_MAT] & csr_wvalue[`CSR_DMW0_MAT]
                    |   ~csr_wmask[`CSR_DMW0_MAT] & csr_dmw0_mat;
    end
end

//DMW0 的 PSEG域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_pseg <= 3'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_pseg <= csr_wmask[`CSR_DMW0_PSEG] & csr_wvalue[`CSR_DMW0_PSEG]
                    |   ~csr_wmask[`CSR_DMW0_PSEG] & csr_dmw0_pseg;
    end
end
//DMW0 的 VSEG域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_vseg <= csr_wmask[`CSR_DMW0_VSEG] & csr_wvalue[`CSR_DMW0_VSEG]
                    |   ~csr_wmask[`CSR_DMW0_VSEG] & csr_dmw0_vseg;
    end
end

//DMW1 的 PLV0域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_plv0 <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_plv0 <= csr_wmask[`CSR_DMW1_PLV0] & csr_wvalue[`CSR_DMW1_PLV0]
                    |   ~csr_wmask[`CSR_DMW1_PLV0] & csr_dmw1_plv0;
    end
end
//DMW1 的 PLV3域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_plv3 <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_plv3 <= csr_wmask[`CSR_DMW1_PLV3] & csr_wvalue[`CSR_DMW1_PLV3]
                    |   ~csr_wmask[`CSR_DMW1_PLV3] & csr_dmw1_plv3;
    end
end
//DMW1 的 MAT域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_mat <= 2'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_mat <= csr_wmask[`CSR_DMW1_MAT] & csr_wvalue[`CSR_DMW1_MAT]
                    |   ~csr_wmask[`CSR_DMW1_MAT] & csr_dmw1_mat;
    end
end

//DMW1 的 PSEG域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_pseg <= 3'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_pseg <= csr_wmask[`CSR_DMW1_PSEG] & csr_wvalue[`CSR_DMW1_PSEG]
                    |   ~csr_wmask[`CSR_DMW1_PSEG] & csr_dmw1_pseg;
    end
end
//DMW1 的 VSEG域
always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_vseg <= csr_wmask[`CSR_DMW1_VSEG] & csr_wvalue[`CSR_DMW1_VSEG]
                    |   ~csr_wmask[`CSR_DMW1_VSEG] & csr_dmw1_vseg;
    end
end
//TLBRENTRY 的 pa域
always @(posedge clk) begin
    if(reset) begin
        csr_tlbrentry_pa <= 26'b0;
    end
    else if(csr_we && csr_num==`CSR_TLBRENTRY) begin
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                    |   ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
    end
end




endmodule