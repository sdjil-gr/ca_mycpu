`define CSR_CRMD 13'h0
`define CSR_PRMD 13'h1
`define CSR_ESTAT 13'h5
`define CSR_ERA 13'h6
`define CSR_EENTRY 13'hc
`define CSR_SAVE0 13'h30
`define CSR_SAVE1 13'h31
`define CSR_SAVE2 13'h32
`define CSR_SAVE3 13'h33

`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE  2
`define CSR_CRMD_DA  3
`define CSR_CRMD_PG  4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE  2

`define CSR_ESTAT_IS10 1:0
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

`define CSR_ERA_PC 31:0

`define CSR_EENTRY_VA 31:6

`define CSR_SAVE0_DATA 31:0
`define CSR_SAVE1_DATA 31:0
`define CSR_SAVE2_DATA 31:0
`define CSR_SAVE3_DATA 31:0