# PJ-01 平江瓮城正南门：后续制作单

- `asset_id`: `pingjiang_south_gate`；`asset_type`: `environment`；`status`: `candidate`。
- `target_usage`: `story` / `town exploration`；目标原生 Resource：`res://data/native/scene_art/pingjiang_south_gate.tres`（**尚未创建**）。
- 首选候选 Resource：`res://data/art_candidates/scenes/pingjiang_south_gate/environment_pingjiang_south_gate_master_v03.tres`。
- 正式导入计划：`res://assets/imported/scenes/pingjiang_south_gate/background.webp`、`ground.webp`，按需 `foreground.webp`；不得直接用单张整图冒充已分层素材。
- 风格参考：PJ-02 v02 及 PJ-01 v01；**几何主参考**：`art-production/guides/pingjiang_south_gate_parallel_1600x2000.svg`。
- 画幅／原点：1600×2000、左上 `(0,0)`，世界贴图 1:1，不旋转、不按 Y 缩放；候选 WebP 目前为不透明整图。
- 原始生成及修订提示词见 [PROMPTS.md](PROMPTS.md)；原创 AI 生成场景，权属与商业近似风险仍需人工审查。未知 seed 不作推测。
- 视觉审核：**待复核**；v03 更接近正交，但尚未达到严格道路净宽/前景分层的最终验收。

1. **镜头与比例复核：** 以 v03 和无文字正交几何图为基准，在顶部、门洞、桥面和底部叠加同一尺寸 200px 角色；严格量测通行净宽是否与 `x=620/980` 的 360px 目标一致，局部未达标必须重绘，不能动态缩放角色。
2. **美术分层：** 以批准的母版为严格坐标参考，分别重绘 `background`、`ground`、`foreground` 1600×2000 真正的透明 RGBA 图层。城门楼体、桥栏和城门檐口与角色前后遮挡应清楚分层。
3. **空间配置：** 建立 `pingjiang_south_gate` 的原生 `WuxiaMapDefinition` 与 `WuxiaSceneArtProfile`；画中水体和城墙为障碍，中央桥路及引道为连续可走面；杜绝贴图放缩。
4. **双向衔接：** 为 `north` ↔ PJ-02 `south`、`south` ↔ 城外野道 `north` 录入显式入口与安全出生点，并在场景加载阶段校验目标是否存在。
5. **角色与交互：** 守卫 NPC、盘查区、告示、水闸与水师船埠分别独立放置；静态美术不烘焙 NPC。
6. **游戏内验收：** 1600×1000 视口上下卷屏、移动/闪避前后脚点、两端往返传送、前景遮挡、门洞不被角色裁切；检查 1440×900 缩放视窗。

供下一轮复核使用的**标准比例标尺**（透明参考叠层，绝不可烘焙进场景美术）：

```bash
python art-production/tools/scene_scale_guide.py --orientation vertical \
  --width 1600 --height 2000 --lane-left 620 --lane-right 980 \
  --lane-top 80 --lane-bottom 1920 --foot-x 800 --foot-y 1740 \
  --door-x 1110 --output /tmp/pj01_vertical_scale_overlay.png
```

完成 1–6 后再提交正式运行时接入 PR；当前 PR 只记录候选美术与设计契约。

### 审核清单

- [x] 同城手绘色板与基本地标在 v03 保持一致（初筛）
- [x] 1600×2000 文件尺寸及 Candidate Resource 有效
- [ ] 道路、城门、桥面等宽 360px 全程实测合格
- [ ] 背景、地面和前景真正独立 Alpha 分层且同一原点
- [ ] 200px 主角脚点、遮挡及 NPC 同比例通过 Godot 实机走图
- [ ] 1600×1000、1440×900 游戏 GUI 截图通过
- [ ] 素材权属、商业近似和负责人视觉批准
