`include "csr.vh"
module csr(
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
    input  wire [31:0] wb_vaddr,
    output wire [31:0] ex_entry,
    output wire [31:0] ex_epc,
    output wire        has_int
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

//timer
reg [31:0] timer_cnt;
wire [31:0] tcfg_next_value;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;
wire [31:0] csr_ticlr_rvalue;

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
                        32'b0;
assign ex_entry = csr_eentry_rvalue;
assign ex_epc = csr_era_rvalue;
assign has_int = (csr_estat_is[12:0] & csr_ecfg_lie[12:0])!= 13'b0 && csr_crmd_ie;


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
end

//PRMD 的 PPLV 域以及 PIE 域
always @(posedge clk) begin
    if(wb_ex)begin
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
    
    if(timer_cnt == 32'b0) begin
        csr_estat_is[11] <= 1'b1;
    end
    else if(csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) begin
        csr_estat_is[11] <= 1'b0;
    end

    csr_estat_is[12] <= 1'b0;
end

//ESTAT 的 ECODE 域以及 ESUBCODE 域
always @(posedge clk) begin
    if(wb_ex)begin
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
    if(wb_ex && (wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE))begin
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc :
                           wb_vaddr;
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

endmodule