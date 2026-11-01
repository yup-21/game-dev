# 首批美术素材：Godot 原生导入与验收指南

本批 **candidate** 由 2 套角色/敌人、1 套分层场景组成。请在**独立临时工作树或审核分支**使用 Godot 4.7.2 Editor 的 Art Production Dock；未经负责人批准不要在正式 main 修改原角色/地图的 .tres 引用。

## 0. 离线重新装配与预检

```bash
python3 -m pip install Pillow
python3 art-production/tools/prepare_pilot_assets.py
# 输出每项 OK 和 PILOT_ASSETS_OK，默认只读
```

资源重建时可使用 `--write` 创建缺失文件；不同版本已有文件必须显式 `--write --replace`，但正式制作应优先另存 vNN。
离线清单 `PILOT_MANIFEST.json` 只保存来源/尺寸/SHA-256，不用作运行时 JSON。

## 1. 角色与敌人导入（独立审核分支执行）

| 角色 | 目标 WuxiaCharacterDefinition | 透明立绘 | 规范化 Atlas | 原生动作模板 |
| --- | --- | --- | --- | --- |
| 沈长风 | `res://data/native/characters/shen_changfeng.tres` | `shen_changfeng/portrait_shen_changfeng_fullbody_v01.png` | `shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png` | `res://data/art_previews/shen_changfeng_pilot_clip_profile.tres` |
| 追镖首领 | `res://data/native/characters/pursuer_captain.tres` | `pursuer_captain/portrait_pursuer_captain_fullbody_v01.png` | `pursuer_captain/sprite_pursuer_captain_atlas_normalized_v02.png` | `res://data/art_previews/pursuer_captain_pilot_clip_profile.tres` |

1. 在 Art Production 中选择立绘、目标角色，查看 Alpha/尺寸/SHA 和绑定差异，再显式导入。
2. 选 Atlas，设置 columns=6、rows=4、脚点偏移初值 (0,-102)、选中上表的 **原生动作帧 Profile 模板**。勾选“版本化替换”以确保旧图片仍可恢复。
3. 在预览下拉栏逐一核验 `idle/move/attack/guard/hit/evade/skill/combo/defeat`，确认映射为：
   - idle 0,1；move 2,3,4,5；attack 6,7,8；guard 9,10；hit 11,12；
   - evade 13,14,15；skill 16,17,18；combo 19,20,21；defeat 22,23。
4. **动作真实视觉验收尚未完成**：需要补绘被原稿裁断的剑/刀尖、校准左右朝向、调整特效生效窗口和速度。导入器技术预检通过不等于批准。
5. 在本地测试副本截图并录像；用导入事务日志撤销，核查原 `.tres` 哈希不变。

注意：两份 `data/art_previews/*_clip_profile.tres` 仅给编辑器作为动作帧范围的**原生模板**。其 atlas 指向默认回退图，导入时会复制模板并替换为新纹理；它们不在 Content Manifest 中登记，也不会自动改变任何战斗角色。

## 2. 分层场景导入（独立审核分支执行）

- 目标：`res://data/maps/rainy_bridge.tres`
- 主层选择 `rainy_bridge/scene_rainy_bridge_background_v01.png`
- ground 选择 `scene_rainy_bridge_ground_v01.png`
- foreground 选择 `scene_rainy_bridge_foreground_v01.png`
- weather 选择 `scene_rainy_bridge_weather_v01.png`
- 4 层均是 **1600×1000** 真 RGBA；共享左上角原点。导入器创建 `WuxiaSceneArtProfile` 并绑定地图的 `scene_art`；禁止从图片自动推断碰撞。

**尚未通过的关键关卡**：原 `rainy_bridge.tres` 的 `first_center` / `cell_size` / 障碍是为另一张旧背景校准的。不能把分层图导入成功等同于地图站位正确；须人工完成与现有 15×10 地形的六人站位、桥面、遮挡检查。原母图也有少量静态雨线，关闭 weather 不能消除全部雨。

## 3. 最终验收门槛

- 角色设定板由负责人冻结身份与色板；补齐方向/中间帧、武器不截断和动画脚点。
- 真实 Godot Editor 下 9 类动作逐一播放，前景遮挡和角色穿行一致，天气关闭不影响路径/LOS。
- 捕获 1600×1000 和 1440×900 的实际 GUI 截图，记录性能与导出可加载性。
- 审核 AI 生成来源、商用权属、与现有作品近似风险；在 `art-production/reviews/` 记录版本 SHA、审核者和日期。
- 上述全部通过前：**candidate，不把 `.tres` 变更合入 main，不替换任何当前在用素材。**
