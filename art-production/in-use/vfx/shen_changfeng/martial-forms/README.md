# 沈长风共用武学特效图集

使用中原图：`vfx_shen_martial_5x4.svg`。这是一张共用图集，不按技能重复存储文件；每个技能仍由自己的 Godot 原生 Resource 选择帧号。

| 技能资产 ID | 原生 Resource | 绝对帧索引 |
| --- | --- | --- |
| `shen_sword_thrust` | `data/native/assets/shen_sword_thrust.tres` | 0–3 |
| `shen_sword_sweep` | `data/native/assets/shen_sword_sweep.tres` | 4–7 |
| `shen_sword_heavy` | `data/native/assets/shen_sword_heavy.tres` | 8–11 |
| `shen_wind_guard` | `data/native/assets/shen_wind_guard.tres` | 12–15 |
| `shen_wind_step` | `data/native/assets/shen_wind_step.tres` | 16–19 |

技能事件、动作与实际生效帧仍以对应 `.tres` 为准。本文件仅用于按角色/技能查找素材，不是额外配置层。
