# 美术资源来源与许可 / Art asset provenance

本次仅引入 **Kenney 制作的 CC0 原始 PNG**，没有使用商业游戏截图、LPC 多许可证素材、字体或第三方 AI 素材。

- 作者：**Kenney**（https://kenney.nl）
- 许可：**Creative Commons Zero (CC0 1.0)**，https://creativecommons.org/publicdomain/zero/1.0/
- Kenney 官方许可说明：https://kenney.nl/support （允许免费、商用、修改；署名非必需）
- 二进制文件上游：[`shorepine/kenney`](https://github.com/shorepine/kenney)，固定上游 Git 提交：`3694c6879e487c108f55677be7dd2ca75b07cc3b`。此仓库是 Kenney 原包的公开归档，`LICENSE.txt` 与仓库 README 标明 CC0。
- 素材使用位置：`res://assets/kenney/`。只保留项目实际引用或待使用的精选素材，不直接提交整套素材包。

| 资源组 | 数量 | 原始 Kenney 产品 | 项目路径 | 上游路径 |
|---|---:|---|---|---|
| 冒险 UI：按钮、面板、血条 | 6 | [UI Pack - Adventure](https://kenney.nl/assets/ui-pack-adventure) | `assets/kenney/ui/` | `ui/UI Pack - Adventure/Double/` |
| 16×16 像素角色：6 种人物外形 | 6 | [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) | `assets/kenney/characters/` | `2d/Tiny Dungeon/Tiles/` |
| 16×16 战场地形：草地、土路、树木等 | 6 | [Tiny Town](https://kenney.nl/assets/tiny-town) | `assets/kenney/terrain/` | `2d/Tiny Town/Tiles/` |

所有文件保留上游原始文件名。项目未修改或重新分发 Kenney 商标。遵守原作者愿望，建议游戏正式发布时在鸣谢名单中显示 `Kenney (kenney.nl) — CC0 assets`。

## 已接入位置

- `scripts/battle_art.gd`：双人／多人战斗使用角色贴图替代原程序化相同人形，地图格使用地形装饰贴图，卡牌背景使用统一的冒险面板。
- `scripts/opening_flow.gd`：标题页和故事对话按钮使用冒险 UI 皮肤。
- 保留原规则、格子颜色高亮、战斗碰撞与鼠标输入逻辑；资源加载失败时绘制层回退到原始矢量占位。

## 校验

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_kenney_assets.gd
```

该 PR 是**素材落地和初步替换**，并非已经完成的美术重制。素材在原始 16×16 像素和 128px UI 尺寸下可能需要进一步统一像素缩放、光照、人物动作、战场镜头和地图地形衔接；初始五式和连段玩法需在后续单独验收。
