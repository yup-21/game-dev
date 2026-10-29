# CC0 第三方美术素材清单

本分支从 OpenGameArt 原作者作品下载实际 PNG 文件，使用 GitHub Actions 验证 PNG 文件签名与上限后提交。下载来源和许可证在下面逐项列明，不包含商用游戏截图或受版权限制的设计图。

| 仓库内文件 | 作者 | 页面 | 许可 | 当前用途 |
|---|---|---|---|---|
| `assets/third_party/oga_cc0/open_tileset.png` | russpuppy | https://opengameart.org/content/rpg-tileset | CC0 | 战场河岸上方装饰条 |
| `assets/third_party/oga_cc0/rpg_skill_tree_icons.png` | Keiffer | https://opengameart.org/content/misc-rpg-icons | CC0 | 武学五重进阶图标 |
| `assets/third_party/oga_cc0/misc_icons.png` | Keiffer | https://opengameart.org/content/misc-rpg-icons | CC0 | 备用技能和状态图标 |

原图直链（可在 `.github/workflows/vendor-cc0-art.yml` 核对）：

- https://opengameart.org/sites/default/files/open_tileset_0.png
- https://opengameart.org/sites/default/files/rpg_skill_tree_icons_1.png
- https://opengameart.org/sites/default/files/misc_icons.png

素材文件的 CC0 许可证见各作品页面；CC0 不强制署名，但仓库保留作者和来源，方便持续审计和替换。游戏原有程序化场景、角色、交互规则保持不变。美术加载失败会自动回退到原先绘制，避免影响战斗模型测试。

注意：以上是第一批真实资源导入与有限整合，**不表示完成了全部美术重制**。仓库另有 PR #16（Kenney CC0 素材）和 PR #17（统一武侠像素表现），应在合并前选择统一风格并处理共同修改的 `battle_art.gd`。切勿直接把三个独立方案不经视觉验收全部堆叠。
