# 黑衣刀客（敌方喽啰）AI 设定与十二动作候选

- `asset_id`: `black_blade`
- 管理状态：`candidate`；当前尚不属于 `in_use`
- 角色设定与动作目标：`res://data/native/characters/black_blade.tres`、`res://data/native/animations/black_blade.tres`
- 风格与身份：按本目录新 `concept/character_design_v01.png` 作本批次参考；黑灰叠甲、灰围巾、红褐腰绳、束发、单柄黑刃长刀，侧视向右。此图是待审核设定，不替代 `baseline/` 的既有正式身份参考。
- 用户原始要求（可追溯部分）：「根据敌方首领人设，帮我生成敌方喽啰角色设定图」「按照美术生成skills，创建精灵图，先创建3组动作」「继续生成三组其他动作」「继续生成下一批」「继续下一批，最后提交pr」。详细逐张图像模型提示词未随素材保存，**不可将美术模板误记为实际发送的提示词**；待补录。
- 当前原生素材与 Resource 均未更改。下列文件是原始候选图的逐字节归档副本，按角色及动作分组；`_vNN` 只区分候选版本，不作为自动绑定入口。

## 已取回原图

| 对应动作 | 目标帧数 / 参考格数 | 候选文件（相对本目录） | 原始文件名 |
| --- | --- | --- | --- |
| 角色设定 | 非动画 | `concept/character_design_v01.png` | `黑衣刀客角色设定图.png` |
| `idle` | 8 / 4×2 | `actions/idle/sprite_idle_v01.png` | `黑衣刀客八帧待机图.png` |
| `walk` | 10 / 5×2 | `actions/walk/sprite_walk_v01.png` | `黑衣刀客十帧行走精灵图.png` |
| `run` | 8 / 4×2 | `actions/run/sprite_run_v01.png` | `黑衣刀客八帧奔跑循环.png` |
| `run` 备选 | 8 / 4×2 | `actions/run/sprite_run_v02.png` | `八帧透明武侠奔跑剑客.png` |
| `run` 备选 | 待核 / 5×2 待核 | `actions/run/sprite_run_v03.png` | `黑衣刀客疾跑动画精灵表.png` |
| `attack1`：直刺 | 6 / 3×2 | `actions/attack1/sprite_attack1_v01.png` | `黑衣刀客突刺动作精灵表.png` |
| `attack1` 备选 | 6 / 3×2 | `actions/attack1/sprite_attack1_v02.png` | `六帧黑衣刀客精灵图.png` |
| `attack1` 备选 | 6 / 3×2 | `actions/attack1/sprite_attack1_v03.png` | `黑衣刀客六帧突刺透明精灵图.png` |
| `attack2`：下劈 | 8 / 4×2 | `actions/attack2/sprite_attack2_v01.png` | `黑衣刀客八帧下劈动作表.png` |
| `attack3`：横斩 | 8 / 4×2 | `actions/attack3/sprite_attack3_v01.png` | `黑衣刀客八帧横斩.png` |
| `attack4`：蓄力重击 | 8 / 4×2 | `actions/attack4/sprite_attack4_v01.png` | `黑衣刀客·蓄力重斩.png` |
| `skill`：追风挑斩 | 8 / 4×2 | `actions/skill/sprite_skill_v01.png` | `黑衣刀客追风挑斩.png` |
| `evade`：向后闪避 | 6 / 3×2 | `actions/evade/sprite_evade_v01.png` | `黑衣刀客后撤闪避 久久精品.png` |
| `evade` 备选 | 6 / 3×2 待核 | `actions/evade/sprite_evade_v02.png` | `透明背景黑衣武侠六姿精灵图.png` |

帧数是先前生成记录中的**目标数**，并非通过拆格数出的有效帧数。备选图的真实动作类别、先后顺序与连续性仍需复核。`guard`（格挡，生成记录为 6 帧）、`hit`（受击，6 帧）、`defeat`（倒地，8 帧）在先前会话中已生成，但本次可读取的文件中没有这三张原图，故**未提交、未假造替代文件**；取回后补到对应动作目录。

## 本次只读技术初筛

检查对象：14 张动画 PNG + 1 张设定板。通过 Pillow 解码全部文件；设定板为 RGB 1536×1024（纸底），14 张动作图均有 RGBA 通道。以下统计以 Alpha 大于 0 视为有效像素，按文件名／先前分镜对应的候选网格进行试算，**未对图像做抠图、改尺寸或裁切**。

| 检查 | 实际结果 | 结论 |
| --- | --- | --- |
| 文件解码 | 15/15 PNG 可解码 | 通过 |
| 目标网格能否整除图像尺寸 | 9/14 动作图不能整除：4×2 的 1774×887 及 5×2 的 1983×793 | 不通过，不能据此机械切成正确等格 |
| 可整除图的四边 Alpha 安全边距 | 5/14 为 1536×1024、3×2；各自至少一格边距为 0 像素 | 不通过，存在触边风险 |
| 背景 Alpha | `run/sprite_run_v01.png` 完全没有 Alpha=0 的像素；其余有透明像素，但部分带暗色聚光背景／边缘残留 | 不通过完整透明背景要求，需返工复核 |
| 帧序、真实 N、完整刀刃、支撑脚、根位移、循环／复位 | 未按完整分镜逐帧验收，也无 Godot 实速预览 | 未通过验收，不能宣称可运行 |

**结论：仅可作为原始候选对照。** G1 多帧 Sheet 几何关口未过，禁止装配正式 Atlas、绑定 `WuxiaActorAnimationProfile` 或替换 `assets/imported/` 中在用素材。后续按 `SPRITE_ANIMATION_QA.md` 逐动作重新生成／返工，先做预声明 C×R 分格与透明边距检查，再做 GIF 动态和 Godot 验收。候选中存在的图像瑕疵不能通过增加 FPS、逐帧居中或强行裁切宣称修复。

## 未完成项

- [ ] 取回或按既有角色设定重制 `guard/hit/defeat` 的三张多帧原图。
- [ ] 补录每张实际使用的模型提示词与明确网格／每帧时间；保存分镜和真实帧索引。
- [ ] 逐张修复或重绘透明底、触边／越格、武器末端完整性；完成机械拆格 G1 与装配 G2。
- [ ] 实速预览 12 组的持刀一致性、承重、循环／收势、后撤位移和倒地终帧。
- [ ] 经视觉审核后，再单独评估正式 `Resource` 引用、`frame_durations`、`root_offsets` 与 Godot 运行验收。
