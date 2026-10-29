# 《长风浮生录》十套武学适配原型 V3

> 原包参考说明副本。下面的独立工程路径、测试状态与入口属于源包；当前项目的实际接入和验收见 [V3移植结果](../wuxue-v3-integration.md) 与 [目录适配说明](INTEGRATION.md)。

这是《听风五式》V2 的**增量扩展独立 Godot 4.3+ 测试工程**，不是对用户正式项目的直接修改。

- 旧五式可继续作为默认测试流派。
- 十套旧武学压缩为 **20 个核心式、41 个派生用法**，含 7 条专属连携；两边可选择同门或异门对练。
- 保留 CTB 集气/全局时间回气分离、自由 ACTION、4 层有限 LIFO 连锁、迎击/闪避/变招、看破/藏招被动和明牌。
- 新增按全局时间计算的凝势、封气、灼痕，远程直线射程、牵引/击退、条件伤害、抽牌。

## 快速启动

1. Godot 4.3+ 打开 `project.godot` 并运行主场景。
2. 选择「我方流派」「敌方流派」，可调整双方观势、藏锋等级，然后点击重新开战。
3. 在右侧展开卡牌名称，再选择一种使用方式。每张实体卡只能选择一种派生用法。

## 测试

```bash
python3 tests/validate_content.py
python3 tests/validate_schools.py
godot --headless --path . --script res://tests/test_engine.gd
godot --headless --path . --script res://tests/test_schools.gd
```

具体技能对照、旧 ID 迁移、Hook 接口与已知取舍见 [`武学适配与迁移_V3.md`](武学适配与迁移_V3.md)。

**测试状态**：当前环境只完成静态数据、引用与源码括号检查；未安装 Godot，尚未实际运行 GDScript 编译及游戏战斗。运行后若报解析错误，请提供具体 Godot 控制台错误和行号，以便修正。
