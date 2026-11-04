# PJ-03 临河水市主大街 — 美术候选工作单

- asset_id: `pingjiang_riverside_market`
- asset_type: `environment`
- status: `candidate`；**未导入运行时，未绑定为 in_use**
- target_usage: 主城街区 / 连续横向卷屏
- 项目规划：`docs/game-design/pingjiang-prefecture-map-plan.md`，PJ-03，4800×1000
- 运行目标：`res://assets/imported/scenes/pingjiang_riverside_market/background.*`、`ground.*`、可选 `foreground.*`；原生 `WuxiaSceneArtProfile` → 对应 `WuxiaChapterSceneDefinition.scene_art`
- 候选 Godot Resource：`res://data/art_candidates/scenes/pingjiang_riverside_market/*.tres`
- 参考：PJ-02 `environment_pingjiang_crossroads_master_v02.webp`（本轮从先前工作区获得，仅用于相机/材质和入口对位；v02 尚未在 PR #123 中）
- 镜头：固定轻度斜俯视 2.5D，弱消失点，视口 1600×1000，3×1600 宽长街，角色 200px 视觉高度
- 色板：青灰石路、粉白墙、黛瓦、墨绿柳树、少量暮秋金叶/橙色灯火
- 输入：上述 PJ-02 v02；东段生成后参考东段制作中段，再参考中段及 PJ-02 v02 制作西段
- 生产方式：内置 imagegen，三张原始 RGB PNG 均为 1586×992；以全幅轻微同比例校准到 1600×1000 WebP 后按西、中、东顺序并排成 **4800×1000 WebP**。重采样只是原始采样画布→目标逻辑尺寸，不再对运行时地图缩放
- 原始提示词：见 [PROMPTS.md](PROMPTS.md)
- 来源/版权：AI 生成原创候选；无外部直接拷贝素材；仍需人工近似性与商用审核；未知 seed 不编造

## 本次交付

- `panel_west_v01.webp` — 1600×1000，河埠/水闸
- `panel_middle_v01.webp` — 1600×1000，淬锋堂/百草堂
- `panel_east_v01.webp` — 1600×1000，河边茶棚与十字路连接
- `environment_pingjiang_riverside_market_master_v01.webp` — 4800×1000 候选概念母版；**非真正分层地图**

## 检查与限制

- [x] 世界尺度工具通过：`scene_scale_guide.py --check`
- [x] 3×1600×1000 段图与 4800×1000 合并图尺寸校正
- [x] Godot 4.6.3 headless `test_art_candidates.gd`：78 张候选源/像素尺寸校验通过（尚非 GUI 验收）
- [x] 无人物、网格、UI、标题文字；左右贯通石板地面
- [x] 中段两个商铺与西段水闸、东段茶棚具有可识别的视觉位置
- [ ] 拼接交界（X=1600 / X=3200）仍有重复立面、色差和纹理不连续；需局部重绘后逐像素验收
- [ ] PJ-02 west ↔ PJ-03 east 拼接石路高度与建筑门槛仍待精确配对
- [ ] 200px 人物、门洞净高 256–304px、四个 Y 区段脚点实景比例尚未测试
- [ ] 同原点独立 background、ground（必需）及 foreground（必要）尚未完成
- [ ] 地面多边形、商铺入口、水闸入口、阻挡与前景遮挡未写入正式资源
- [ ] Godot 1600×1000/1440×900 真实 GUI 卷屏与往返入口未验证
- [ ] 人工视觉/权属审核

**结论：** 本轮是统一视角与世界尺寸的第一版候选母版，不应替换既有在用地图。
