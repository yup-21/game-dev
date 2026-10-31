# 游戏素材生产管线：基线与技术校验（P2）

当前项目保留**原创高精细国风手绘**的人物和场景方向；HD-2D 主要描述镜头、纵深与遮挡表达，不强制低像素风格。

## 单一资产清单

`assets/production_manifest.json` 为运行时资产技术合同，给每个关键图像记录：

- 稳定 `id`、`kind`、`path`、用途阶段 `status`；
- 来源 `source` 与商业发布前需要核实的 `rights`；
- 可用时声明 `dimensions` 和图集 `grid`；
- `notes` 保存具体美术质量的已知问题。

状态解释：

| 状态 | 含义 |
| --- | --- |
| `concept` | 风格与造型设计，不可直接进战斗 |
| `preview` | 可临时播放的参考图，包括需运行时白底清理的 JPG |
| `candidate` | 技术规格可能符合，但 alpha、脚点、动作连续性仍待人工审查 |
| `runtime` | 当前运行路径实际引用的资源，不代表美术已最终定稿 |
| `approved` | 经实际 GUI、美术一致性、技术规格与授权确认的正式资产 |

**目前没有把任何角色动作候选图直接标为 approved。** 这保持了“已存储资源”和“真正可量产资源”的边界。

## 自动校验

`checks/test_asset_contracts.gd` 在 Godot 资源导入后检查：

1. 清单 JSON 版本、独立 ID 和安全 `res://assets/` 路径；
2. 已导入 `Texture2D`、原始图像可解码；
3. 声明的尺寸和图集切分比例；
4. 每张正式登记资源有来源和使用权状态。

候选素材的视觉 alpha、动作连贯性及版权审核不能自动断言合格，只生成 `ASSET_QA_PENDING`。检查新增资源时应先补元数据，再调整正式代码引用。原始参考与用户上传素材不得自动删除。

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_asset_contracts.gd
```

## 角色图集未来的交付合同

在制作正式主角与一名敌人时，冻结角色像素密度、帧尺寸、左右朝向、脚底位置与以下动作：

- `idle`：至少完整一轮不同姿态，而不是单帧延长；
- `move`：连续步态，含纵深移动时的朝向策略；
- `attack`、`guard`、`hit`、`evade`、`combo`：有明确起手/有效/收招关键帧；
- 动画事件与 `BattleActionTimeline` 对接，**不得直接写入 HP、卡区和 CTB**；
- 每个动作保留关键帧、脚点、武器方向、透明边缘人工验收截图。

先通过一名完整主角 + 一名正式敌人的生产验证，再扩大到六人。现有白底姿势图可以继续作为 preview，不自动升级为正式逐帧动画。

## 未来尚未执行的步骤

- 生成并人工验收独立 `SpriteFrames` 或等价动画资源、音效/VFX 事件资源；
- 按数据索引自动生成可复用的角色 atlas 和 debug 预览；
- 添加导出包实际加载检查，避免动态 `res://` 字符串引用在 PCK 中遗漏；
- 拍摄 1600×1000 与 1440×900 的 GUI 对照截图并检查遮挡与脚点。

本阶段只建立**可重复、机器可校验的前半段管线**。导出验证属于 P4，手工美术及授权验收仍由制作方负责。
