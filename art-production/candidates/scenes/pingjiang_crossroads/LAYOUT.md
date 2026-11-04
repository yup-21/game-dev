# PJ-02 十字路口路线/坐标设计（候选）

画布 1600×1000；左上 (0,0)，X 向右、Y 向下。`mixed` 四向可走面由一个真实相交的纵横交叉区组成；这里记录的是美术设计锚点，**不是已经写入 Godot 的碰撞或传送数据**。

| 区域/入口 | 建议脚点 (px) | 连接目标及目标出生点 | 备注 |
| --- | --- | --- | --- |
| `north` | (800, 90) | `pingjiang_yamen_street` / `south` | 牌坊内侧，北向出街 |
| `south` | (800, 920) | `pingjiang_south_gate` / `north` | 南门方向 |
| `west` | (90, 790) | `pingjiang_riverside_market` / `east` | 西行临河水市 |
| `east` | (1510, 790) | `pingjiang_su_estate` / `west` | 东行苏府 |
| `shop_clothier` | (235, 655) | `pingjiang_clothier` / `door` | 布庄门前交互区，非覆盖图上建筑门框 |
| `shop_pawnshop` | (1390, 655) | `pingjiang_pawnshop` / `door` | 当铺门前交互区 |

建议返程 `spawn` 应位于出口触发半径内侧，避免载入后再次触发原出口；确切脚点应在正式 `walkable_outline` 中留有 24px 碰撞安全余量。门洞坐标、街角遮挡、瓦檐与人物脚点必须在 Godot Editor 逐处审查。

本地图与邻区的连接仅由真实地图 `zone_exit`/`spawn` marker 的 `target_zone_id` 与 `target_entry_id` 明确配置；不依赖地图贴图文件名或自动兜底。
