# 沈长风 12 组动作 GIF · v01 候选（2026-11-07）

此包为 **candidate**。以当前沈长风身份设定板为参考，生成三张透明 5×5 混合动作母图，拆成 **12 张独立 GIF／75 帧**，并建立 15 个候选 `WuxiaArtCandidateDefinition.tres`（12 个动作 GIF、3 张 AI 源图）。**没有改变正式角色动画、SpriteFrames、Content Manifest 或现有 in_use 资产。**

## 动作与序列

| 动作 | 中文 | 真实帧数 | 循环 |
|---|---|---:|---|
| `idle` | 待机呼吸 | 4 | 是 |
| `walk` | 步行循环 | 8 | 是 |
| `run` | 跑步循环 | 8 | 是 |
| `attack1` | 直刺 | 7 | 否 |
| `attack2` | 上举下劈 | 7 | 否 |
| `attack3` | 横斩 | 7 | 否 |
| `attack4` | 蓄力重斩 | 8 | 否 |
| `skill` | 凝神出剑 | 7 | 否 |
| `evade` | 后撤腾挪 | 5 | 否 |
| `guard` | 架剑格挡 | 5 | 否 |
| `hit` | 受击后恢复 | 4 | 否 |
| `defeat` | 失衡倒地 | 5 | 否，末帧保持 |

每一帧都是 **328×256 RGBA 来源经 GIF 索引透明色导出的画布**，各组带独立毫秒级时长；`idle/walk/run` 有循环扩展，其他动作不循环。GIF 颜色有调色板量化，原 AI 源图仍以 PNG 保存。

逐格映射以 `MANIFEST.json` 中 75 个 `batch/cell_index/action_id/action_frame_index` 为准，下面的格号按 **1–25** 阅读：

| 批次 | 1–25 格位映射（连续） | AI 原图尺寸 |
|---|---|---|
| 1 | `idle` 1–4；`walk` 1–8；`run` 1–8；`attack1` 1–5 | 1233×1276 |
| 2 | `attack1` 6–7；`attack2` 1–7；`attack3` 1–7；`attack4` 1–8；`skill` 1 | 1277×1232 |
| 3 | `skill` 2–7；`evade` 1–5；`guard` 1–5；`hit` 1–4；`defeat` 1–5 | 1232×1277 |

自然站立可见高度在 `idle` 首帧测得约 178 源像素；1.78m 为本候选制作推定值，**尚非剧情设定中获批准的身高**。原始模型没有精确像素参数，生成后按每批统一等比比例 0.90 和固定批次偏移放入 328×256 单格，不进行逐帧紧裁、居中、缩放或 AI 猜动作编号。原图 PNG 保存在 `source/`，所有生成提示词见 `PROMPTS.md`。

## 当前 QA 结论

- [x] 12/12 GIF 可解码；全部 75 帧，独立 328×256 画布，透明通道与播放时长已检查。
- [x] 帧序映射完整连续；标准化后每格四边 ≥8px Alpha 留白（自动几何检查）。
- [ ] **AI 原图仍有 14/75 格触及 8px 源格安全区**，主要是第二批下边缘及第三批个别倒地格；统一缩放不能证明被遮挡/裁缺的剑尖和肢体已恢复。详见 `quality_report.json`。
- [ ] 跨批尺寸、脚点承重、刀剑握法／同一件武器、姿态自然度、循环接缝仍须逐帧人工审查；严格侧视并未验证通过。
- [ ] 未在 Godot Editor 内执行 GIF→SpriteFrames 正式导入或 1600×1000 / 1440×900 实速 GUI 验收。
- [ ] 角色设计板原本仍待负责人冻结；美术与商用权属最终批准待办。

**因此 GIF 只是可审阅可播放的候选，不符合正式替换门槛。** 待问题帧重画、脚点审阅与负责人确认后，再按 `demos/changfeng-battle/docs/NATIVE_ANIMATION_IMPORT.md` 在 Native GIF Dock 中检查并显式导入。不要将本包直接替换已编辑的 `SpriteFrames.tres`。

## 复现

```bash
python3 art-production/tools/build_shen_gif_v01.py
```

该脚本只重建候选 GIF、映射、QA 与缺失的候选描述；不会修改运行时 Resource。
