`define CSR_CRMD 13'h0
`define CSR_PRMD 13'h1
`define CSR_ECFG 13'h4
`define CSR_ESTAT 13'h5
`define CSR_ERA 13'h6
`define CSR_BADV 13'h7
`define CSR_EENTRY 13'hc
`define CSR_SAVE0 13'h30
`define CSR_SAVE1 13'h31
`define CSR_SAVE2 13'h32
`define CSR_SAVE3 13'h33
`define CSR_TID 13'h40
`define CSR_TCFG 13'h41
`define CSR_TVAL 13'h42
`define CSR_TICLR 13'h44

`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE  2
`define CSR_CRMD_DA  3
`define CSR_CRMD_PG  4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE  2

`define CSR_ECFG_LIE 12:0

`define CSR_ESTAT_IS10 1:0
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

`define CSR_ERA_PC 31:0

`define CSR_BADV_VADDR 31:0

`define CSR_EENTRY_VA 31:6

`define CSR_SAVE0_DATA 31:0
`define CSR_SAVE1_DATA 31:0
`define CSR_SAVE2_DATA 31:0
`define CSR_SAVE3_DATA 31:0

`define CSR_TID_TID 31:0

`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIODIC 1
`define CSR_TCFG_INITVAL 31:2

`define CSR_TVAL_TIMEVAL 31:0

`define CSR_TICLR_CLR 0




`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2
`define ECODE_PIF 6'h3
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hb
`define ECODE_BRK 6'hc
`define ECODE_INE 6'hd
`define ECODE_IPE 6'he
`define ECODE_TLBR 6'h3f

`define ESUBCODE_ADEF 9'h0
`define ESUBCODE_ADEM 9'h1