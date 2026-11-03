# 批量脚点重排器：五名角色、九类动作

入口：`batch_anchor_align.py`；测试：`test_batch_anchor_align.py`。

## 与沈长风 v05 的关系

延续 PR #103 固定点工具的理念，但采用 **原像素搬移**：根据每帧脚点的左/右/上/下 Alpha 极值计算统一新格尺寸，再平移、打包；不会像旧 `rebuild_shen_v05.py` 那样为装入预设格子逐帧缩放。自动估算点一律 `reviewed=0`，不得用它证明动作没有脚滑。没有自动增加间帧或修复跨格截断。

## 命令

```bash
python -m pip install Pillow
python art-production/tools/test_batch_anchor_align.py
python art-production/tools/batch_anchor_align.py --all
python art-production/tools/batch_anchor_align.py --actor night_assassin --no-gif
python art-production/tools/batch_anchor_align.py --all --annotations art-production/candidates/characters --require-reviewed
```

输入是 `art-production/candidates/characters/<actor>/baseline/sprite_<actor>_atlas_aligned_v03.png`。输出独立候选文件夹，不变更任何正在使用的 Godot Resource。

## CSV 字段

| 字段 | 含义 |
|---|---|
| `action` | `idle/move/attack/guard/hit/evade/skill/combo/defeat`；格 0 记录为 `unused` |
| `frame` | **动作内部** 0 起始帧号，兼容可视化标注器 |
| `atlas_index` | 旧 6×4 图集的绝对帧号（可省略；省略时按动作帧号推导） |
| `x,y` | 原始 256×256 源格坐标中的承重脚/触地点 |
| `anchor_type` | 例如 `rear_foot/front_foot/body_contact` |
| `reviewed` | 人工复核才填 1；自动推算为 0 |
| `root_dx,root_dy` | 有人工证明的动作位移（像素），未经复核禁止非零 |
| `source_edge_warning` | 任何非零 Alpha 是否贴源格边缘，可能存在缺画 |

图集第 0 格不能当待机间帧。九类动作总共使用其他 23 格；五人共 115 个需要复核的运行姿势。对移动中的支撑脚切换与倒地身体接触点，应逐帧检验，不要只依据像素下边界。

## 与 Godot 接口

需要经批准后将 Atlas 导入 `assets/imported/candidates/characters/<actor>/sprites` 并建立独立 `WuxiaActorAnimationProfile` 预览资源，其 `columns=6, rows=4`、帧号沿用旧资源。新格宽高是可变的，必须校准 `feet_offset` 和 `actor_scale`，保持普通角色 200 世界像素视觉高度。不要直接把旧版 `feet_offset=(0,-102)` 当成新图集正确值；也不要改 BattleModel / 技能结算。
