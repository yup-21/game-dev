# R33 · 原生技法阶段图

默认变锋式从旧 `r25_techniques` 通用字典迁至 `data/native/techniques/tf_change_stage.tres`，直接注册在 Manifest 的 techniques 数组。四个阶段节点、名字、timing、cost、target、effect、next、trigger、auto_equip 和 hold_own_actions 都是 Inspector 可编辑的 Resource 字段。

运行时 `TechniqueRuntime` 从注册的 Resource 转换出的标准规则记录构建状态机，不再读取默认 JSON/通用文档；自定义 JSON 测试 fixture 继续走显式路径，供非法规则验证。原版 JSON 只在 `test_r25_native_documents.gd` 比对历史字段。
