# R39 · 代码迁移完结与验证边界

## 已迁移的正式目录

通过 `data/content_manifest.tres` 唯一入口注册：角色、技能与技法、状态/物品/词条、剧情/章节/任务/遭遇、原生 FREE 多边形地图与 GRID 精确地形、角色/场景素材、动作时间轴、十套武学及听风卡组、旧技能 ID 只读导入映射。

R32–R38 逐类将七份 `WuxiaDataDocument` 迁为原生 Resource；R39 删除了通用文档类型、Manifest 的 `documents` 属性和注册分支。生产入口不读取旧 JSON。显式非法数据与历史数值回归保留 `data/*.json` 作为 fixture，属于测试数据而不是第二个正式内容系统。

## 必须通过的验证

- `checks/test_r25_native_documents.gd`：武学与听风所有原始字段 1:1、四节点技法、双六人遭遇、GRID 全格与地图校准、40 个旧 ID 保持一致
- `checks/test_r32_native_action_timeline.gd`：9 种动作及 13 个语义事件数值保持一致
- `checks/test_r39_content_cleanup.gd`：旧通用文档和实现完全消失、原生 Manifest 及主要规则消费者可正常加载
- 原有 R11–R31、HUD/spatial/视觉截图以及 Windows/Linux 可执行导出工作流持续通过

`BattleModel` 是唯一对战斗规则下结论的权威，动画时间轴和 AssetRegistry 只负责表现。无格子 FREE 模式与 GRID 模式是同一战斗模型的两套空间服务。保留旧行为回归，不恢复旧玩家场景、旧 3D 叠图或旧角色美术。

## 人工验收（仍需实际操作，不属于自动 CI）

在 Godot 4.7.2 Editor 检验各种 Resource 子卡 Inspector 编辑/保存；确认场景层级、地图画笔坐标、序章到战斗完整操作、角色每方向 24 帧、UI 截图真实观感；在 Windows/Linux 上运行导出可执行文件并对第三方素材授权及版权来源完成审查。在这些条件满足之前 PR 保持 Draft，不自动合并主分支。
