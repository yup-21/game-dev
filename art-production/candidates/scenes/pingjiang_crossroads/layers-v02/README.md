# PJ-02 v02 同原点图层

来源：上级 `environment_pingjiang_crossroads_master_v02.webp`，原始提示词见上级 `PROMPTS.md`。未再次调用生图。

可编辑母版由原图与 `art-production/tools/build_pj02_layers.py` 的具名多边形蒙版组成。运行脚本生成 background/ground/foreground 三张 1600×1000 RGBA PNG；互斥 Alpha、无空洞、精确重建原图。候选、导入副本与在用镜像一致，原始图不变；旧 v01 draft 未使用。

Map：`res://data/maps/pingjiang_crossroads.tres`；SceneArt：`res://data/native/scene_art/pingjiang_crossroads.tres`。仅在独立四区探索与 QA 场景绑定；人工质量/权属验收待完成。图层蒙版不决定碰撞，几何在 Map Resource 中独立编辑。牌坊立面目前为固定背景，不宣称已具备可在前后穿行的动态遮挡。

重建：`python art-production/tools/build_pj02_layers.py`。
只读检查：`python art-production/tools/build_pj02_layers.py --check`。
