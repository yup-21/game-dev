# 原创水墨武学 UI 素材（v1）

本目录为《长风浮生录》HD-2D 战斗界面原创素材；配色沿用青玉、墨绿、宣纸、古金，参考现代卡牌游戏的信息层级与交互规律，**不包含任何其他游戏的截图、标志或裁切素材**。

## 资源清单

| 文件 | 规格 | 功能 |
| --- | --- | --- |
| `technique_art_atlas_v1.png` | 1536×1024，4 列×2 行 | 8 幅原创武学卡面，单格 384×512 |
| `jade_panel_frame.svg` | 256×128，九宫可缩放 | 顶栏、队伍、交锋、手牌面板 |
| `jade_card_filagree.svg` | 176×208，透明边饰 | 手牌古金边框、角花、双层细线 |
| `jade_seal.svg` | 72×72，透明 | 江湖徽章、卡牌印鉴 |

插画顺序：从左到右、从上到下分别是探锋穿雨、断岳重斩、游身踏雪、化劲护体、变锋回旋、追风连携、凝气护元、交锋截势。每幅都生成于本次原创 AI 美术任务；实际技能名称、费用和效果由 `BattleModel` 的可见快照及合法行动决定，不写入图片或 UI 代码。

- 卡面通过 `hd2d_card_ui.gd` 的 `AtlasTexture` 按 4×2 裁切并渲染。没有硬编码绘制到控制按钮里，也无需 Photoshop 分拆原图。
- 新卡用法仅在 `legal_actions()` 返回对应 `PLAY_CARD` 时可见；隐藏的敌方手牌始终不渲染。
- 卡面可点击区域是原生 `Button`；插画、边饰和标签使用 `MOUSE_FILTER_IGNORE`，不抢事件。
- 面板使用 `StyleBoxTexture` 九宫缩放以避免四角纹饰被扯开；气血条和 CTB 文本从权威模型读取。
- 仅调整 UI 和素材，没有新增招式、修改 CTB 或对 `BattleModel`、`CombatResolver` 做任何改动。

## 验证

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_wuxia_ui.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```

人工检查 1600×1000 与 1440×900 窗口、手牌过多时的滚动、不同合法用法的卡面选择高亮，以及六人剧情战斗的 CTB/气血更新。此环境无法克隆工作树做 Godot 实机测试，需依赖 PR 的 CI 与实际窗口截图进一步验收。

### 原创生成说明

插画使用图像生成工具依据「八格原创武侠招式、非商业 IP、无字、青墨/古金/宣纸画法」的提示词生成；边框和徽章是本轮独立绘制的 SVG 矢量路径。保留源 PNG 全图便于继续分割、质检与美术精修。插画采用单张汇总 atlas，后续优化单个分格时须保持 4×2 格顺序或同步更新映射。
