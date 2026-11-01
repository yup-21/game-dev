# R36–R37 · 武学与听风卡牌统一原生资源

> 本页为历史迁移记录；新内容制作统一参阅 [原生 Resource 指南](../../../docs/changfeng-native-authoring.md)。


`r36_school_forms` 和 `r37_tingfeng_cards` 已从两份 `WuxiaDataDocument` 迁为 `WuxiaRuleCatalogDefinition`。拥有独立 `WuxiaRuleSchoolDefinition`、`WuxiaRuleCardDefinition`、`WuxiaRuleUsageDefinition`、`WuxiaRuleCostDefinition`、`WuxiaRuleTargetDefinition`、`WuxiaRuleAttackProfileDefinition`、`WuxiaRuleStatusDefinition`、`WuxiaRuleComboDefinition`、`WuxiaRuleDeckDefinition`、`WuxiaRuleEffectDefinition` 等 Inspector 可编辑子资源。

十套武学、二十张核心式、七个跨卡连携以及听风六卡、三连携、状态、被动、卡组全部登记在 `data/content_manifest.tres.rule_catalogs`。效果参数中仍允许类型可验证的 Dictionary 扩展字段，不允许把整份旧文档作为单个 data 字典存储。

`SchoolCatalog` 和 `CardSystem` 使用原生 Resource 计算出来的规则记录并校验。R41 已删除历史 JSON 与逐字段对照测试；当前 `test_r25_native_documents.gd` 及真实玩法回归固定检查核心招式、卡组规模、连携、阶段技法和遭遇行为，避免静默改变已发布内容。
