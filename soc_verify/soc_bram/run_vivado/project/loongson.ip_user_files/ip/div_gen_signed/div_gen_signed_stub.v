// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.1 (win64) Build 3865809 Sun May  7 15:05:29 MDT 2023
// Date        : Sat Sep 28 00:41:43 2024
// Host        : LAPTOP-1 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/VScode/course/ca-lab/prj3/exp10/mycpu_env/soc_verify/soc_bram/rtl/xilinx_ip/div_gen_signed/div_gen_signed_stub.v
// Design      : div_gen_signed
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "div_gen_v5_1_19,Vivado 2023.1" *)
module div_gen_signed(aclk, s_axis_divisor_tvalid, 
  s_axis_divisor_tready, s_axis_divisor_tdata, s_axis_dividend_tvalid, 
  s_axis_dividend_tready, s_axis_dividend_tdata, m_axis_dout_tvalid, m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="s_axis_divisor_tvalid,s_axis_divisor_tready,s_axis_divisor_tdata[31:0],s_axis_dividend_tvalid,s_axis_dividend_tready,s_axis_dividend_tdata[31:0],m_axis_dout_tvalid,m_axis_dout_tdata[63:0]" */
/* synthesis syn_force_seq_prim="aclk" */;
  input aclk /* synthesis syn_isclock = 1 */;
  input s_axis_divisor_tvalid;
  output s_axis_divisor_tready;
  input [31:0]s_axis_divisor_tdata;
  input s_axis_dividend_tvalid;
  output s_axis_dividend_tready;
  input [31:0]s_axis_dividend_tdata;
  output m_axis_dout_tvalid;
  output [63:0]m_axis_dout_tdata;
endmodule