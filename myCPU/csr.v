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
    output wire [31:0] ex_entry,
    output wire [31:0] ex_epc
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
//ESTAT
reg [12:0] csr_estat_is;
reg [ 5:0] csr_estat_ecode;
reg [ 8:0] csr_estat_esubcode;
//ERA
reg [31:0] csr_era_pc;
//EENTRY
reg [25:0] csr_eentry_va;
//SAVE0~3
reg [31:0] csr_save0;
reg [31:0] csr_save1;
reg [31:0] csr_save2;
reg [31:0] csr_save3;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_eentry_rvalue;

assign csr_crmd_rvalue = {23'b0,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is[12:11],1'b0,csr_estat_is[9:0]};
assign csr_era_rvalue = csr_era_pc;
assign csr_eentry_rvalue = {csr_eentry_va,6'b0};

assign csr_rvalue =     csr_num == `CSR_CRMD   ? csr_crmd_rvalue :
                        csr_num == `CSR_PRMD   ? csr_prmd_rvalue :
                        csr_num == `CSR_ESTAT  ? csr_estat_rvalue :
                        csr_num == `CSR_ERA    ? csr_era_rvalue :
                        csr_num == `CSR_EENTRY ? csr_eentry_rvalue :
                        csr_num == `CSR_SAVE0  ? csr_save0 :
                        csr_num == `CSR_SAVE1  ? csr_save1 :
                        csr_num == `CSR_SAVE2  ? csr_save2 :
                        csr_num == `CSR_SAVE3  ? csr_save3 : 
                        32'b0;
assign ex_entry = csr_eentry_rvalue;
assign ex_epc = csr_era_rvalue;


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

//ESTAT 的 IS 域
always @(posedge clk) begin
    if(wb_ex)begin
        csr_estat_is[1:0] <= 2'b00;
    end
    else if(csr_we && csr_num==`CSR_ESTAT) begin
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                        |   ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    end
    csr_estat_is[9:2] <= 8'b0;
    csr_estat_is[10] <= 1'b0;
    csr_estat_is[12:11] <= 2'b0;
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

endmodule