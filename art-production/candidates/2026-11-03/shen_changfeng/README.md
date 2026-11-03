# 沈长风 v05：单手剑、支点锁定与可变帧数动作候选

**状态：candidate。此分支的正式 in_use 绑定不变。** 本文与 `art-production/tools/rebuild_shen_v05.py` 固化生成方法。

## 为什么原图不合格

- 自动图集会在相邻帧之间混画、断剑和遮挡；脚底最低 Alpha 像素既可能是衣摆，也可能是剑尖，不能作为鞋底坐标。
- 即使底边数值一致，如果每帧身体横向重新居中，角色也会抖动。攻击收招和世界坐标前移应由 BattleActionTimeline / 角色节点协调，不能用图像突然反向平移模拟。
- 沈长风身份固定为青蓝外袍、米白内衣、束发、右手 **一柄**直剑，左手不持第二武器；像素风动作支点图不是最终美术风格。

## 技术合同

本次本地修图试验生成 8×10、每格 768×320 的 RGBA Atlas（6144×3200）。
源图来自用户对话中的 10 张手绘关键帧母图，**并未假定 AI 生成的网格尺寸和安全边距天然正确**。

| action | 索引 | 帧数 | 建议播放 |
| --- | --- | ---: | --- |
| idle | 0–7 | 8 | loop 12 FPS |
| move | 8–15 | 8 | loop 14 FPS |
| attack | 16–23 | 8 | action timeline |
| guard | 24–31 | 8 | action timeline |
| hit | 32–35 | 4 | action timeline |
| evade | 36–41 | 6 | action timeline |
| skill | 42–49 | 8 | action timeline |
| combo | 50–59 | 10 | action timeline |
| ultimate | 60–71 | 12 | **仅候选** |
| defeat | 72–77 | 6 | action timeline |

最后 78、79 为未引用透明格。Godot 当前正式 `WuxiaActorAnimationProfile.REQUIRED_ACTIONS` 只有九种动作，**ultimate 不得擅自塞入正式 Profile**，后续单独按技能/绝招动作扩展设计接口；不得改变 BattleModel、HP、CTB 或战斗距离。

## 标准化流水线

1. 固定角色身份、单手武器、朝右侧身/三分之二侧身视角，按动作复杂度而非统一 8 帧制作关键帧和间帧。
2. 首选逐帧 RGBA PNG，兼容历史 AI 多格母图需按真实列行拆开；触到源格边的剑光/衣袂必须返回原图补绘。
3. 用 Alpha 和色域检测去除明显红黄残影，保留正常钢剑及蓝白效果；结果仍需人工边缘审查。
4. 从暗色鞋底低区估算承重接地点，输出 `foot_annotations.csv`；**估算非人工确认**，逐帧调整 x/y 并将 `reviewed` 设为 1 后再重跑。
5. 支点运动分阶段：idle 后脚贴地；guard 架剑承重脚贴地；move 交替支撑；attack 蹬地、前移、收招；defeat 倒地后切换至躯干地面接触点。
6. 单格 768×320，四周至少 24px 透明留白，必要时等比缩小完整形体，不拉伸，不裁断武器；产出每动作分图和大图、索引 JSON、脚点标注 CSV。
7. 技术校验后在 Godot 1600×1000 与 1440×900 预览，审查脚滑、剑势回弹、颜色、轮廓、武器数量、连续性、世界尺寸，合格后才允许由单一原生 .tres 插槽切换为 in_use。

## 本轮实测与仍待修复

- 内容 10 组、**78 帧**；图集 8×10；所有输出格子的透明留白 **至少 24px**。
- 根据自动推测支点完成几何对齐，目标点位置数值偏移 0px。**这只能证明对齐程序工作，不能证明鞋底点选正确，也不能证明全片无脚滑**。
- **9 帧源母图接触格边**：重新装配解决了输出跨格，但原稿可能已经损坏的剑尖/剑气尚未重画。不得把这些帧列为视觉通过。
- Godot GUI 本轮未运行；候选 Profile 与 png/webp 原件在对话所附完整 ZIP 中，需要人工审阅后才能接入项目。
- 不替换现有正式资源、不增加第二套运行时 JSON、不把批准状态伪造为已完成。

## 操作方法

**推荐可视化标注**：下载并打开 [`sprite-anchor-editor.html`](../../../tools/sprite-anchor-editor.html)，依次导入十组源母图；逐帧点击真实承重接点、检查红色源格贴边警告，然后设置边距并导出无逐帧缩放的 PNG Atlas 和 `foot_annotations.csv`。详见[工具指南](../../../tools/SPRITE_ANCHOR_EDITOR.md)。原有 Python 重排脚本仍会独立进行逐帧缩放；需要保证全动作人物比例一致时，应直接检查编辑器导出的 Atlas，而不是误以为 CSV 回灌后会自动保持原像素大小。

```sh
python3 -m pip install pillow numpy opencv-python
python3 art-production/tools/rebuild_shen_v05.py \
  --inputs path/to/10_source_pngs --output path/to/candidate
# Review and fix each foot coordinate; set reviewed=1 for verified entries
python3 art-production/tools/rebuild_shen_v05.py \
  --inputs path/to/10_source_pngs --annotations path/to/candidate/foot_annotations.csv \
  --output path/to/candidate
```

完整二进制候选包与脚点动态预览在当前 ChatGPT 回答中交付；**本 PR 的文本提交不代表这些新二进制图集已经上传仓库**。若后续上传二进制，放入 art-production/candidates/2026-11-03/shen_changfeng/ 与项目 assets/imported/candidates 对应路径，并保持现有 in_use 不变。
