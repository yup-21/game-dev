# 通用人体骨架与沈长风可选装饰（骨架先行）

## 原则

**人体骨架不包含角色专属装饰。** 使用 Godot 原生 `Skeleton2D/Bone2D`，按部件的天然父级自动跟随位置，但只有本角色确实拥有的装饰才实例化对应独立骨架。不得以整张立绘裁剪图推算人体骨点。

| 模块 | 资源 | 范围 |
| --- | --- | --- |
| 通用人体 | `res://prototypes/humanoid_rig/humanoid_side_core.tscn` | 22 根人体骨骼；脚底基准为 (0,0)，头颈/胸腰/骨盆/左右肩肘腕手/髋膝踝脚 |
| 头发装饰 | `res://prototypes/humanoid_rig/accessories/hair_basic.tscn` | 3 根独立 Bone2D，`HairSocket` 挂在人体 Head 上；可省略 |
| 长袍衣摆 | `res://prototypes/humanoid_rig/accessories/coat_three_panel.tscn` | 7 根独立 Bone2D，`CoatSocket` 挂在 Pelvis 上；可省略 |
| 武器 | 人体手部 `WeaponSocket` / `WeaponTip` Marker2D | 剑不是人体骨骼，任意角色可换装不同武器 |
| 示例组合 | `res://prototypes/shen_rig_first/shen_skeleton_first.tscn` | 沈长风将通用人体与可选装饰组装，同时预览 idle / walk / attack_sword |

由于每套装饰拥有自己的 `Skeleton2D`，不能把 `Polygon2D` 同时跨两套 Skeleton2D 混合权重。人体材质只绑定核心骨架；头发/衣摆材质分别绑定自身的独立装饰骨架。装饰的根节点作为人体骨骼的子节点自动跟随人体运动，再叠加自身的摆动。

`rig_rest_initializer.gd` 自动用独立场景中每根 Bone2D 的初始 transform 初始化 rest；这不是一次性运行时猜测部件枢轴。

## 复用与素材生成

- 人体：所有相同侧身比例的角色复用**同一份 22 根骨骼**；需要另一体型时建立另一类核心骨架，不在角色身上加临时特例。
- 装饰：短发可不装 hair 骨骼；短衣可不装 coat 骨骼；其他装饰（发带、飘带、披风）今后按同样方式添加可选场景，不改人体核心。
- 整体仍是右向侧身、200px 游戏身高、80px / 战斗长度单位。
- `rig_contract.json` **v2**：`bones` 只记录 22 根通用人体骨点；`accessories` 记录各自骨架和挂接点；`sockets` 记录剑柄/剑尖；`parts` 维护原有 20 个素材模板，并新增 `rig_group` 以明确区分 body / hair / coat / weapon。
- 运行 `python3 tools/build_shen_rig_art_templates.py` 输出 4x 绘图尺度下的 `art_frames.json`、全身 `master-rig-template.svg` 与 `per-part-svg/*.svg`。每件独立透明 PNG 需要匹配画布尺寸、pivot、挂载骨骼和遮挡区，不允许导入后再任意缩放。
- 素材保持 `candidate` / `in_use` 两状态；当前所有新绘制模板仅为 candidate，尚无新正式角色贴图。

## 验收

`test_shen_rig_first.gd` 同时验证：
1. 独立实例化的通用骨架恰好 22 根 Bone2D，未引用任何头发、衣摆或剑的专有骨骼；
2. 带装饰的沈长风是 22 根人体骨骼 + 3 根头发 + 7 根衣摆骨骼，各有不同的 Skeleton2D；Rest Pose、子骨骼层级和挂点对齐；
3. 没有头发和衣摆时，22 根人体骨骼仍可直接播放 idle / walk / attack_sword；
4. 武器由手部 Marker2D 控制位置与旋转，脚底世界锚点在三个动作中不移动。

`visual-evidence` 继续生成绑骨姿势及三动作的 GIF、关键帧与素材套版。只有骨架和动作初步验收后，才按模板绘制人物贴图并进一步做真实皮肤权重/遮挡视觉验收；CI 通过不等于正式视觉验收。

PR #99 保持 Draft；不会修改现有正式游戏运行角色。
