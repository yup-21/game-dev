# 2026-11-01 首批角色、敌人、分层场景技术验收记录

- 试点：`shen_changfeng`、`pursuer_captain`、`rainy_bridge`
- 技术操作者：ChatGPT 图像生成与 Pillow 内存处理
- 审核状态：**pending owner review**；`approved=false`
- 版本与溯源：`candidates/2026-11-01/PILOT_MANIFEST.json`
- 现有正式资源：**未覆盖、未移动、未重新绑定**

## 自动项目

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 身份设定稿、两份全身立绘 | 已生成 | 1536×1024 设定板；1024×1536 立绘，PNG RGBA |
| 两套九动作 Atlas | 技术装配完成 | 每份 24 帧、6×4、256×256 单格；九组索引均合法 |
| 初稿动作画面 | 未通过最终视觉验收 | V1/V2 检测多格武器与衣缘越界，源码保留 |
| 标准化 Atlas 安全区 | 通过像素阈值检测 | 24/24 格未触 8 px 边界，脚点 y=227–228 |
| 分层场景尺寸/Alpha | 通过离线生成与检查 | background/ground/foreground/weather 同为 1600×1000 RGBA |
| 单母版对位与合成 | 通过算法内存重组 | 多边形掩膜拆层；干层合成像素等于缩放后的母版 |
| 离线可复现脚本 | 源码提供 | `art-production/tools/prepare_pilot_assets.py`；本次依等价逻辑在内存执行 |
| Godot P1/P2 插件正式导入 | **未执行** | 当前环境无可写 Godot 工作树和 GUI；仅制作导入参数与原生 Profile 模板 |
| Godot 编辑器动作 / 站位 / 遮挡 | **未执行** | 需要实际编辑器逐动作、六人站位验收 |
| 两档 GUI 截图与录像 | **未执行** | 待 1600×1000、1440×900 真实应用测试 |
| 作者身份与商用授权审批 | **未通过** | 需负责人确认身份锁与版权风险 |

## 已知缺陷与后续修订

1. AI V2 原稿在剑尖/刀锋及长衣缘存在部分越格，规范化修订可以消除图集邻帧污染，但**不能补回原图已缺失笔画**；需逐帧修图。
2. `idle`、`move` 有多姿势帧，非循环动作有起手/有效/收招，但转身与四方向尚不完整，实机时序未验证。
3. 雨夜断桥合成画面与旧 `rainy_bridge` 地形图没有做逐点映射；不能修改地图碰撞来迁就画面。
4. 透视/前景遮挡采用粗分区遮罩，需美术分层细修边界；背景有轻微烘焙雨丝，无法完全通过 weather 层禁用。
5. 未得实际 Godot Editor GUI、截图、性能和版权审核证据，不得将本批登记为 `approved`、`in_use` 或正式运行资源。

## 批准区（由项目负责人填写）

- Reviewer:
- Identity/style:
- Motion/facing/feet:
- Scene alignment/occlusion:
- Rights/commercial:
- Godot 1600×1000:
- Godot 1440×900:
- Approved SHA / date:
- 结论：**pending**
