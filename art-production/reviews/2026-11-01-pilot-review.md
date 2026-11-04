# 2026-11-01 首批角色、敌人、分层场景技术验收记录

- 试点：`shen_changfeng`、`pursuer_captain`、`rainy_bridge`
- 技术操作者：ChatGPT 图像生成与 Pillow 内存处理
- 审核状态：**pending owner review**；`approved=false`
- 版本与溯源：`candidates/records/pilot/MANIFEST.json`
- 现有正式资源：**未覆盖、未移动、未重新绑定**

## 自动项目

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 身份设定稿、两份全身立绘 | 已生成 | 1536×1024 设定板；1024×1536 立绘，PNG RGBA |
| 两套九动作 Atlas | 技术装配完成 | 每份 24 帧、6×4、256×256 单格；九组索引均合法 |
| 初稿动作画面 | 未通过最终视觉验收 | V1/V2 检测多格武器与衣缘越界，源码保留 |
| 标准化 Atlas 安全区 | 通过像素阈值检测 | 24/24 格未触 8 px 边界，脚点 y=227–228 |
| 分层场景尺寸/Alpha | 通过离线生成与检查 | background/ground/foreground/weather 同为 1600×1000 RGBA |
| 单母版对位与合成 | 通过算法内存重组 | 多边形掩膜拆层；干层合成像素等于缩放后的母版 |
| 离线可复现脚本 | 源码提供 | `art-production/tools/prepare_pilot_assets.py`；本次依等价逻辑在内存执行 |
| Godot P1/P2 插件正式导入 | **未执行** | 当前环境无可写 Godot 工作树和 GUI；仅制作导入参数与原生 Profile 模板 |
| Godot 编辑器动作 / 站位 / 遮挡 | **未执行** | 需要实际编辑器逐动作、六人站位验收 |
| 两档 GUI 截图与录像 | **未执行** | 待 1600×1000、1440×900 真实应用测试 |
| 作者身份与商用授权审批 | **未通过** | 需负责人确认身份锁与版权风险 |

## 已知缺陷与后续修订

1. AI V2 原稿在剑尖/刀锋及长衣缘存在部分越格，规范化修订可以消除图集邻帧污染，但**不能补回原图已缺失笔画**；需逐帧修图。
2. `idle`、`move` 有多姿势帧，非循环动作有起手/有效/收招，但转身与四方向尚不完整，实机时序未验证。
3. 雨夜断桥合成画面与旧 `rainy_bridge` 地形图没有做逐点映射；不能修改地图碰撞来迁就画面。
4. 透视/前景遮挡采用粗分区遮罩，需美术分层细修边界；背景有轻微烘焙雨丝，无法完全通过 weather 层禁用。
5. 未得实际 Godot Editor GUI、截图、性能和版权审核证据，不得将本批登记为 `approved`、`in_use` 或正式运行资源。

## 批准区（由项目负责人填写）

- Reviewer:
- Identity/style:
- Motion/facing/feet:
- Scene alignment/occlusion:
- Rights/commercial:
- Godot 1600×1000:
- Godot 1440×900:
- Approved SHA / date:
- 结论：**pending**

## 自动化复核追加（2026-11-01）

在同一 PR 中新增两项**只读**验证，不改变正式游戏角色、地图、Content Manifest 或原有图片：

1. `checks/test_art_pilot_candidates.gd` 读取真实候选：两份 1024×1536 透明立绘、两份 1536×1024 透明 Atlas，以及四张 1600×1000 RGBA 场景图层。对两名角色分别执行 9 类动作的 `WuxiaActorAnimationProfile` / `AnimationPlayer` 首帧检查，并检查场景 `WuxiaSceneArtProfile` 与原生导入器 `plan()`。
2. `prepare_pilot_assets.py` 加入 Modular CI，重新计算归一化图集与同源场景拆层，对比仓库中已存文件，确保可重复生成且不存在静默漂移。

此外，`checks/capture_art_pilot_candidates.gd` 在虚拟图形显示器中按真实尺寸渲染场景四层和两类角色检查姿势，输出 `captures/art-pilot/pilot-1600x1000.png` 与 `pilot-1440x900.png`。它使用六个**检查站位**，并非六名游戏实体的正式地图/碰撞播放。截图随 HUD CI 以 `unified-wuxia-hud-visual-evidence` 上传，可在 [PR #82 Actions](https://github.com/yup-21/game-dev/pull/82/checks) 查看与下载。

- [x] 离线候选重建比对通过（GitHub CI）
- [x] Godot 候选角色和场景只读导入预检通过（GitHub CI）
- [x] 两档候选画面截图已成功生成（图形化 CI；**仅作为待人工审图证据**）
- [ ] 实际 `battle_hd2d.tscn` 的候选临时绑定、完整战斗动作/特效与地形匹配人工验收
- [ ] 武器笔画补绘、帧间过渡、前后方向、分层边缘与静态雨丝的美术修订
- [ ] 项目负责人对身份、商用权属、两档画面签字批准

这些技术结果不变更本批 `candidate / owner_review_required` 身份，亦不构成 `approved` 或 `in_use`。
