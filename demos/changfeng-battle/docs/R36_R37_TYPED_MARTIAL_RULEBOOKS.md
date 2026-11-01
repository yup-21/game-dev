# R36–R37 · 武学与听风卡牌统一原生资源

`r36_school_forms` 和 `r37_tingfeng_cards` 已从两份 `WuxiaDataDocument` 迁为 `WuxiaRuleCatalogDefinition`。拥有独立 `WuxiaRuleSchoolDefinition`、`WuxiaRuleCardDefinition`、`WuxiaRuleUsageDefinition`、`WuxiaRuleCostDefinition`、`WuxiaRuleTargetDefinition`、`WuxiaRuleAttackProfileDefinition`、`WuxiaRuleStatusDefinition`、`WuxiaRuleComboDefinition`、`WuxiaRuleDeckDefinition`、`WuxiaRuleEffectDefinition` 等 Inspector 可编辑子资源。

十套武学、二十张核心式、七个跨卡连携以及听风六卡、三连携、状态、被动、卡组全部登记在 `data/content_manifest.tres.rule_catalogs`。效果参数中仍允许类型可验证的 Dictionary 扩展字段，不允许把整份旧文档作为单个 data 字典存储。

`SchoolCatalog` 和 `CardSystem` 使用原生 Resource 计算出来的规则记录，规则合法性验证保持原实现；JSON 只在测试提供显式路径或历史完整值对照时读取。`test_r25_native_documents.gd` 对比两份完整源 JSON 逐字段，不容静默丢失或更改牌式、效果、费用与连携条件。
