# PJ-04 沈家旧宅 — 场景美术候选工作单

- `asset_id`: `pingjiang_shen_house`
- `asset_type`: `environment`
- `status`: `candidate`；不标记 `in_use`
- `target_usage`: 江南道主城 / 沈长风旧宅、练功、存档、身世线索
- 规划合同：`docs/game-design/pingjiang-prefecture-map-plan.md`（PJ-04，1600×1000）
- 目标运行资源：`res://data/native/scene_art/pingjiang_shen_house.tres`，**尚未创建或绑定**
- 计划导入：`res://assets/imported/scenes/pingjiang_shen_house/background.*`、`ground.*`、可选 `foreground.*`
- 候选 Godot Resource：`res://data/art_candidates/scenes/pingjiang_shen_house/*.tres`
- 完整提示词：[`PROMPTS.md`](PROMPTS.md)

## 镜头与美术合同

- 世界画布 1600×1000；单屏，`horizontal`，北门是唯一跨区连接。
- 与 PJ-02 v02 统一弱透视、斜俯视 2.5D、房舍/石板比例、暮秋粉墙黛瓦和青灰/墨绿/暖金色调；没有将先前 PNG 作为像素拼贴或模型输入。
- 比例：`combat_scale.gd` 的 80 世界像素/u、200px 角色、24px 地面占位；人物不随 Y 缩放。
- 地标：旧屋木门、剑匣案台、木人桩/兵器架、右墙石龛暗格、井、院墙北门。
- 预计可走面在下半幅宽庭院，北门至院内另有接入路径；地标前保留交互脚点。真实可走多边形待视觉与引擎验证。
- 参考图只用于本轮人工理解已做的 PJ-02/PJ-03 风格；内置生图输入为纯文字，第 2 次编辑的输入是第 1 次本轮生成图。

## 实际交付

| 文件 | 像素 | 用途 |
| --- | --- | --- |
| `environment_pingjiang_shen_house_master_v01.webp` | 1600×1000，RGB | 第一版庭院母版；北侧通道收窄较明显 |
| `environment_pingjiang_shen_house_master_v02.webp` | 1600×1000，RGB | 北门与巷道局部修订，**首选评审候选** |
| `layout_pingjiang_shen_house_v01.svg` | 1600×1000 坐标图 | 设计锚点/走位草案，非正式贴图 |

- 生成方式：内置 imagegen，v01 原生 1586×992 RGB PNG，v02 编辑原生 1585×992 RGB PNG；通过 `magick -resize 1600x1000! -quality 93` 仅对全幅尺寸轻微归一，并保存为 WebP。随机 seed 未提供，不编造。
- 版权来源：本轮 AI 生成原创候选；仍需负责人的商业近似性与授权审查。
- 不包含 source PNG、真实透明分层、碰撞和已经测试的可玩 `Map Resource`。

## 审核结论

- [x] 候选母版、尺寸、独立候选 Resource 和提示词已登记。
- [x] 地标与主要活动区域可用于下一轮场景设计。
- [ ] 门洞与人物比例实机核验。
- [ ] 分层透明、遮挡、碰撞与出口双向联调。
- [ ] Godot GUI 1600×1000、1440×900 验收。
- [ ] 美术与权属负责人批准。

**状态：** `candidate`，视觉首选 v02；未加入正式 Content Manifest，不覆盖旧素材。
