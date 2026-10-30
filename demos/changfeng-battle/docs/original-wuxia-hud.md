# 原创武侠战斗 HUD · v1

## 集成范围
- **原创视觉文件**：`assets/ui/original/` 的 8 张武学卡面 SVG、青玉剑山纹章。
- **映射**：`scripts/hd2d_card_art.gd` 按卡牌 `definition_id` 选择图稿；对旧牌实例采用名称 fallback，未知卡牌使用探锋图，不读取隐藏信息。
- **画面**：顶部章节、六人阵容 CTB/气血/内息进度、右侧 CLASH 响应栈、底部可横向滚动的武学卡牌和命令按钮。
- **操作**：每个合法 usage 保留单独按钮；点击选择目标／连携响应；原有 Q、G、Space、Esc、右键等不改。
- **模型**：不变更 `BattleModel`、`EnemyAI`、行动合法性、费用、牌堆、CTB、LIFO、连携与动画 ticket。所有数值仅从 snapshot 更新。

## 验收
Godot 4.x 项目路径为 `demos/changfeng-battle`：

```sh
godot --headless --editor --path demos/changfeng-battle --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ui_assets.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_startup.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```

在 1600×1000、1440×900 窗口下需人工检查卡牌文字长短、滚动、头像裁剪、操作热点、CLASH 层次和缩放。SVG 图稿不能代表精细角色动作动画；本轮只重做 UI 视觉素材与对应表现层。

**验证状态**：此执行环境没有 Godot 二进制，尚未执行引擎启动／交互回归；不能将静态审阅视作实机 PASS。

## 高精度 PNG 覆盖路径（可选）
将同主题 384×512 的原创插画 `card_probe.png`、`card_sunder.png` 等放置在：
`assets/ui/original/painted/`。执行 Godot 导入后 `CardArt` 会优先加载 PNG；没有该文件时自动使用当前已入库的 SVG。这样素材升级不需要修改战斗逻辑或按钮代码。
