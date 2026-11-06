# 视频转精灵图：候选生产工作流

适用所有战斗角色。此工具只生产 candidate，不修改 in-use 图片、角色卡或 Godot .tres。正式资源配置仍以 WuxiaActorAnimationProfile / WuxiaCharacterDefinition 和 Content Manifest 为准。战斗比例沿用 combat_scale.gd：普通角色视觉高度为 200 世界像素，而非固定 200 源图像素。

## 工具和依赖

- Python 3.10+、Pillow：python -m pip install Pillow
- FFmpeg（ffmpeg 位于 PATH）
- 可选 rembg 命令行工具，用于视频帧 AI 抠图
- 人工脚点标注继续使用本目录的 sprite-anchor-editor.html，无需服务器

视频模型输入：同一批准的人设基础图、严格右侧视、固定人物尺度、完整单手剑、静态镜头、纯色背景；每次单独生成一个动作 MP4。原视频作为候选工作单中的来源保留。参见 ../prompts/VIDEO_ACTION_PROMPTS.md。

## 1. 提取视频帧

从仓库根目录执行：

~~~bash
python3 art-production/tools/video_to_sprite.py extract \
  --video /path/to/shen_idle.mp4 --fps 12 --rembg \
  --output art-production/candidates/2026-11-03/shen_changfeng/idle_extract_v01
~~~

- 原始帧：idle_extract_v01/source_frames/
- 选 --rembg 后透明帧：idle_extract_v01/alpha_frames/
- 不选 rembg 时，使用任意工具将视频帧抠成真正 RGBA PNG。纯色背景图片不能直接打包。
- 想人工挑选更细动作时可先提 24 FPS；抽样不会生成新的间帧。

输出目录必须不存在，避免覆盖旧候选；再次生成使用 v02 新目录。

## 2. 标注真实支撑脚与可选根运动

打开 sprite-anchor-editor.html，导入全部透明 PNG，动作名对应 idle、move、attack 等，每帧点击承重鞋底与地面的实际接触点，下载 foot_annotations.csv。frame 索引从 0 开始，reviewed=1 仅表示人工已检查。不能仅把 Alpha 外接框最低点作为真实脚点。

位移动作另制作可选 root_motion.csv，记录**相对首帧的源视频像素位移**（不是 Godot 世界像素），每一帧一行：

~~~csv
action,frame,root_x,root_y,reviewed
attack,0,0,0,1
attack,1,3,0,1
attack,2,8,0,1
attack,3,12,0,1
~~~

上述数值只是格式示例，真实数据必须逐帧审查。若缺少 CSV，工具输出全 0 的待复核候选，不声称角色没有位移。行走交替承重和攻击前冲都不能靠单纯逐帧居中解决。

## 3. 制作单动作 Atlas

~~~bash
python3 art-production/tools/video_to_sprite.py pack \
  --frames art-production/candidates/2026-11-03/shen_changfeng/idle_extract_v01/alpha_frames \
  --action idle --fps 12 --loop --columns 8 --margin 24 \
  --anchors /path/to/foot_annotations.csv \
  --output art-production/candidates/2026-11-03/shen_changfeng/idle_pack_v01
~~~

需要保留人工确认的位移时额外传 --motion /path/to/root_motion.csv。

| 输出 | 用途 |
| --- | --- |
| atlas.png | 均匀网格、完整透明安全边距的单动作图集 |
| aligned/frame_0000.png 等 | 无缩放、无截断的独立已对齐帧 |
| preview.gif | 当前动作预览（用于观察非循环动作，不代表它应该循环） |
| foot_annotations.csv | 脚点坐标、审核状态、来源贴边提示 |
| root_motion.csv | 源像素位移记录，未提供时全部未复核 |
| frame_contract.json | 离线几何与动作索引，不是新的运行时格式 |
| qa_report.json | 待复核、贴边和人工验收项目 |

--loop 只对 idle / move 合法。每动作最多 256 帧，FPS 1–60；--margin 24 是当前试点值。格子的宽高按所有帧相对已标脚点的最大实际轮廓计算，不逐帧拉伸、居中或裁断剑尖。若抠图有噪点，图集尺寸可能异常增大，应先清理源帧。

无标注时自动建议点来自 Alpha 外接框下缘中心，始终显示为未复核，不能作为脚点已锁定的证明。

## 4. 合并动作

分别 pack 生成九动作 idle、move、attack、guard、hit、evade、skill、combo、defeat，再执行：

~~~bash
python3 art-production/tools/video_to_sprite.py assemble \
  --input /path/to/idle_pack_v01 \
  --input /path/to/move_pack_v01 \
  --input /path/to/attack_pack_v01 \
  --input /path/to/guard_pack_v01 \
  --input /path/to/hit_pack_v01 \
  --input /path/to/evade_pack_v01 \
  --input /path/to/skill_pack_v01 \
  --input /path/to/combo_pack_v01 \
  --input /path/to/defeat_pack_v01 \
  --columns 8 --margin 24 --require-complete \
  --output art-production/candidates/2026-11-03/shen_changfeng/combined_v01
~~~

合并产物 atlas.png 与 frame_contract.json；后者的 actions 记录绝对索引、FPS 和循环信息。试点仅少量动作时可省略 --require-complete，但不能替换当前要求九动作齐全的正式 Profile。

## 5. Godot 原生接入、限制和验收

1. 在现有 Art Production Dock 导入 candidate 的合并 atlas.png，按 frame_contract 的列/行配置图集。
2. 在 WuxiaActorAnimationProfile 中为九类 WuxiaActorAnimationClip 填写绝对帧号、FPS 与循环标记。导入器不自动读取离线 JSON；当前运行内容仍是 .tres。
3. 通过现有版本化导入和事务回退机制切换素材，未完成视觉验收时留在 candidate。
4. Godot 中使用 1600×1000 / 1440×900 视口检查动画的身份、单手剑、发丝和剑尖、真实脚点、循环闭合、帧间抖动、攻击的位移、角色 200px 世界高度及时间线节奏。

**已知限制：** 脚点自动候选并不是真实脚点识别；不自动修复视频里断剑、手臂变形或抠图闪烁；不自动推断根运动。根运动 CSV 只作为离线参考，现有 Godot 运行时不读取此 JSON；真正前冲需后续在已有表现时间线或 AnimationPlayer 中实现。工具不会修改游戏规则或攻击距离。

## 回归

~~~bash
python3 -m unittest discover -s art-production/tools -p 'test_video_to_sprite.py' -v
godot --headless --path demos/changfeng-battle --editor --import --quit
~~~

单测使用合成 RGBA 图验证几何、边距、绝对索引、未复核提示和拒绝覆盖，不替代真实 MP4 / AI 抠图 / Godot GUI 验收。另见 GODOT_IMPORTER.md、SPRITE_ANCHOR_EDITOR.md。
