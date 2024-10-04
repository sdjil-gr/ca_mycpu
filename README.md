## 介绍
本仓库为国科大2024秋季学期计算机组成原理（研讨课）的小组任务仓库，小组箱号18。

## 记录
所有单人项目exp6、7、8、9均已完成，目前为具有基本阻塞与前递功能的流水线cpu。

### 添加更多用户态指令
#### exp10
- [x]  算术逻辑运算类指令 `slti`， `sltui`， `andi`， `ori`， `xori`， `sll`， `srl`， `sra`， `pcaddu12i`；
- [x]  乘除运算类指令`mul.w`, `mulh.w`, `mulh.wu`, `div.w`, `mod.w`, `div.wu`, `mod.wu`;
- [x]  debug;
FINISH exp10 AT 2024/9/28

#### exp11   - (10-08)
- [x]  转移指令`blt`， `bge`， `bltu`， `bgeu`;
- [x]  访存指令`ld.b`， `ld.h`， `ld.bu`， `ld.hu`， `st.b`， `st.h`；
- [x]  debug
FINISH exp11 AT 2024/10/4

## 任务


## 其他
完成组内个人任务时请务必开一个新分支，完成后申请merge到work分支，防止某些指令影响其他指令运行。
目前，master分支用于每周的最终结果；work分支用于将大家的修改进行合并，debug也于work分支进行，最后该周任务完全没有问题后，debug的人负责将work分支合并到master，最终提交版本以更新后的master分支为主。

仓库ignore了项目文件夹，请clone后利用tcl脚本创建！
