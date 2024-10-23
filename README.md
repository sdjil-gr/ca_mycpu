## 介绍
本仓库为国科大2024秋季学期计算机组成原理（研讨课）的小组任务仓库，小组箱号18。

## 记录
所有单人项目exp6、7、8、9均已完成，目前为具有基本阻塞与前递功能的流水线cpu。

### 添加更多用户态指令
#### exp10
- [x]  算术逻辑运算类指令 `slti`， `sltui`， `andi`， `ori`， `xori`， `sll`， `srl`， `sra`， `pcaddu12i`;
- [x]  乘除运算类指令`mul.w`, `mulh.w`, `mulh.wu`, `div.w`, `mod.w`, `div.wu`, `mod.wu`;
- [x]  debug;

FINISH exp10 AT 2024/9/28

#### exp11
- [x]  转移指令`blt`， `bge`， `bltu`， `bgeu`;
- [x]  访存指令`ld.b`， `ld.h`， `ld.bu`， `ld.hu`， `st.b`， `st.h`;
- [x]  debug;

FINISH exp11 AT 2024/10/4

### 支持异常与中断
#### exp12
- [x]  为 CPU 增加`csrrd`、`csrwr`、`csrxchg` 和 `ertn` 指令;
- [x]  为 CPU 增加控制状态寄存器`CRMD`、`PRMD`、`ESTAT`、`ERA`、`EENTRY`、`SAVE0~3`;
- [x]  为 CPU 增加`syscall` 指令，实现系统调用异常支持;

FINISH exp12 AT 2024/10/12

#### exp13
- [x]  为 CPU 增加取指地址错`ADEF`、地址非对齐`ALE`、断点`BRK`和指令不存在`INE`异常的支持;
- [x]  为 CPU 增加中断的支持，包括2个软件中断、8个硬件中断和定时器中断;
- [x]  为 CPU 增加控制状态寄存器`ECFG`、`BADV`、`TID`、`TCFG`、`TVAL`、`TICLR`;
- [x]  为 CPU 增加`rdcntvl.w`、`rdcntvh.w` 和 `rdcntid` 指令;

FINISH exp13 AT 2024/10/13

### AXI总线接口设计
#### exp14
- [x]  将 CPU 对外接口修改为类 SRAM 总线接口;

FINISH exp12 AT 2024/10/18


## 任务

#### exp15
- [ ]  将 CPU 顶层接口修改为 AXI 总线接口。

#### exp16
- [ ]   完善 AXI 总线接口设计使其在采用 AXI 总线的 SoC 验证环境里完成 exp16 对应 func 的
随机延迟功能验证，要求成功通过仿真和上板验证。


## 其他
完成组内个人任务时请务必开一个新分支，完成后申请merge到work分支，防止某些指令影响其他指令运行。
目前，master分支用于每周的最终结果；work分支用于将大家的修改进行合并，debug也于work分支进行，最后该周任务完全没有问题后，debug的人负责将work分支合并到master，最终提交版本以更新后的master分支为主。

仓库ignore了项目文件夹，请clone后利用tcl脚本创建！
