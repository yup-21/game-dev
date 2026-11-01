# R38 · 旧 ID 在数据边界强类型化

> **历史记录（R38）**：本页记载对应里程碑当时的状态，不是当前的内容制作或加载指南。R41 后旧游戏 JSON、ID 适配器和相关测试已经删除。正式制作以 [唯一原生 Resource 指南](../../../docs/changfeng-native-authoring.md) 为准。


四十项原版武学 ID 映射迁为可直接编辑的 `WuxiaLegacyMappingEntryDefinition`。`LegacySkillAdapter` 不再读取 `WuxiaDataDocument`，也不再写死 `step_01` 的闪避使用方式；特殊映射属于原生映射卡的显式配置。

旧 ID 仅服务用户主动导入的旧技能记录，正式内容的 ID 直接引用当前卡牌与 usage；保持映射数值是为历史回归，不能把旧 UID、牌区、战斗状态自动导入新游戏。JSON 文件只作静态对照 fixture。
