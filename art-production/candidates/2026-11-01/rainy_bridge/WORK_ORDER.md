# 雨夜断桥：分层场景制作工作单

## 场景合同
- asset_id: `rainy_bridge`，16:10 固定 HD-2D 镜头
- 与 `data/maps/rainy_bridge.tres` 的原生地形定义关联，但**没有改动现有 15×10 网格**或背景贴图
- 主桥沿横向贯穿画面中央，湍流垂向穿过桥下；六人走位视觉区位于桥面
- 底色：雨夜蓝/墨青/苔绿；局部灯笼暖金，岩石与湿桥石真实手绘材质
- 源母版 `environment_rainy_bridge_master_v01.png` 为 1586×992。分层时 LANCZOS 采样到严格 1600×1000。
- 生产日期：2026-11-01
- 生成工具：内置图像生成工具；底层模型 ID 未公开；seed 不可获取
- 风格基准：`art-production/standards/ART_PRODUCTION_STANDARD.md` 与 `prompts/ART_STYLE_AI_PROMPTS_V1.md`
- 来源/权属：本项目定向原创 AI 生成，未使用外部商业角色图；仍须由负责人完成可商用权属、相似性与最终视觉审核
- 状态：**candidate / owner_review_required**；绝不等同 approved 或 runtime/in_use
- 全量提示词见同批 `PROMPTS.md`；SHA-256 与版本源流见 `PILOT_MANIFEST.json`。

## 图层
| 层级 | 文件 | 透明/坐标 |
| --- | --- | --- |
| background | `scene_rainy_bridge_background_v01.png` | 1600×1000 RGBA；远山、山谷、水流；地面/前景区域透明 |
| ground | `scene_rainy_bridge_ground_v01.png` | 1600×1000 RGBA；桥面可站立部分 |
| foreground | `scene_rainy_bridge_foreground_v01.png` | 1600×1000 RGBA；桥身前缘、竹叶与近景遮挡 |
| weather | `scene_rainy_bridge_weather_v01.png` | 1600×1000 RGBA；可关闭的独立细雨，程序固定随机种子 |
| composite preview | `scene_rainy_bridge_composite_preview_v01.png` | 同画布；合成检查，非运行时图层 |

- 左上角 (0,0)，X 向右、Y 向下；所有图层严格同原点。
- 从同一母图使用确定性遮罩拆层，避免 AI 再生成导致地标漂移；干层重组在像素上等同缩放后的母图。
- 离线可编辑母版是源 PNG + 可复现 `tools/prepare_pilot_assets.py` 中的分层多边形；后续美术可在 Krita/PSD 内对独立图层细修。
- 游戏中由 `WuxiaSceneArtProfile` 引用四层，由地图 `scene_art` 显式挂载，**不能凭贴图颜色自动生成路径或碰撞**。

## 验收现状
- [x] 4 层画布尺寸 1600×1000 和 RGBA 校验；前景及天气真实透明
- [x] 单母版、同原点、像素重组；可独立关闭 weather
- [ ] 当前主桥画面与既有地图 `first_center`、`cell_size`、障碍/出生点的逐点校准
- [ ] Godot 编辑器里实际六人站位、脚点、前景遮挡和低性能天气开关
- [ ] 1600×1000、1440×900 GUI 实机截图与负责人视觉/授权批准
- [ ] 母版中原有细雨依然画在静态背景中；完全关闭全部降雨需后续人工重绘干背景

**结论：图层技术候选；旧地图和正式背景路径不替换。**
