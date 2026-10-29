# 武学V3目录接入说明

本目录的《武学适配与迁移_V3.md》及 README.md 是原包文档副本，保留参考用途，其中原包的单体引擎、棋盘和启动命令不代表本工程的接入方式。当前工程按根目录 V3_CONTRACT.md 接入原有战斗模型。

`data/school_forms.json` 和 `data/legacy_id_map.json` 原样复制，原包保持不变。`SchoolCatalog` 只读取定义与说明元数据，校验结构和引用；说明文字不会执行。目录错误写入 `load_error`，失败时清空已装载的流派、核心式、状态及连携，避免暴露半成品。

核心式在内存中规范化：三种 `damage_if_*` 合并为根 `deal_damage.conditional_bonus`，低血量百分数转换为 0–1 比值；击退/拉近转换为 `max_distance` 与统一方向值；`opponent` 转换为 `enemy`；敌方攻击的 `target.max_distance` 同步到 `attack_profile.range`，直线视野标注为正交并受角色阻挡。所有数值及使用方式数量沿用原数据。

流派选项包含默认听风，共11项。目录仅保有20个新增式的定义、3个新增状态和7条连携；每门流派牌组12张。听风牌组由调用方传入 `deck_for("tingfeng", default_deck)`。查询函数返回深拷贝；目录不产生卡牌实例，不读写战斗状态或UID。

`LegacySkillAdapter.resolve_legacy(id, old_usage)` 对40个旧ID返回三个字段：`definition_id`、定义层 `card_id`、`usage_id`。`step_01` 在 `old_usage="evasion"` 时选择闪避方式；未知ID及在战UID返回空对象。

定向验证入口是 `../../checks/test_wuxue_catalog.gd`，也可执行 `checks/verify.ps1 -Stage Catalog`。它只加载目录及适配器，不运行工程场景；日志与临时数据写入 captures/checks。检查覆盖数量、41种用法、40个旧ID、深拷贝、规范化和坏结构/引用的原子拒绝。原始数据SHA256对照见 `source-hashes.txt`。
