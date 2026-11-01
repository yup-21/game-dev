# R33 · 原生技法阶段图

> 本页为历史迁移记录；新内容制作统一参阅 [原生 Resource 指南](../../../docs/changfeng-native-authoring.md)。


默认变锋式从旧 `r25_techniques` 通用字典迁至 `data/native/techniques/tf_change_stage.tres`，直接注册在 Manifest 的 techniques 数组。四个阶段节点、名字、timing、cost、target、effect、next、trigger、auto_equip 和 hold_own_actions 都是 Inspector 可编辑的 Resource 字段。

运行时 `TechniqueRuntime` 从注册的原生 Resource 构建阶段状态机。R41 已删除旧 JSON fixture 与逐字段对照；当前用类型化定义校验、实际技法执行和战斗回归确认阶段行为。
