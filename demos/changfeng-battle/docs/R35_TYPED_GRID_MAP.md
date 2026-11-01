# R35 · 类型化 GRID 地形地图

已将 `rainy_bridge` 15×10 手工地形蒙版迁移成 `WuxiaGridMapDefinition`，在 Manifest 的 maps 内注册。`terrain_keys` 是独立 `WuxiaGridTerrainKeyDefinition`，每行文字、地形符号、格心校准、背景 Texture2D、旋转比例均支持 Inspector 编辑。

`MapBake` 默认从 `ContentRegistry.entries("map")` 读取类型化地图记录，不再依赖 `r25_rainy_bridge` 旧文档。原有 JSON 仍作为显式非法数据 fixture 与逐字段回归基准。`WuxiaMapDefinition` 多边形 FREE 模式继续并存，这两种是同一导航服务的两种地图表示，不是两套战斗规则。
