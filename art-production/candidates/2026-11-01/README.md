# 2026-11-01 原创美术首批试点（审核候选）

**本批不是在用素材，也没有获项目负责人批准。** 正式游戏资源路径、角色 `.tres`、地图几何和战斗逻辑未被此批替换。

| 样板 | 重点内容 | 审核 |
| --- | --- | --- |
| [沈长风](shen_changfeng/WORK_ORDER.md) | 四视图身份板、透明立绘、9 动作 24 帧归一化 Atlas、源版本 | candidate |
| [追镖首领](pursuer_captain/WORK_ORDER.md) | 不同身型与武器身份板、透明立绘、9 动作 24 帧归一化 Atlas、源版本 | candidate |
| [雨夜断桥](rainy_bridge/WORK_ORDER.md) | 1600×1000 四层 PNG、同原点可复合、预览合成图 | candidate |

- [全量 Prompt 与参考版本](PROMPTS.md)
- [离线 SHA-256 和 Git Blob 索引](PILOT_MANIFEST.json)
- [Godot 导入/验收流程](IMPORT_GUIDE.md)
- [技术验收及遗留问题](../../reviews/2026-11-01-pilot-review.md)
- [可复现装配工具](../../tools/prepare_pilot_assets.py)：由 V2 姿势源图生成归一化 Atlas，由同一断桥母版生成四层及合成预览

后续生产复用 `art-production/standards/`、`prompts/` 和对应 wuxia-* Skill，不以试点的 256 px、6×4 帧数替代通用规范；仍须按角色/动作实际需要重新定义列行及 FPS。
