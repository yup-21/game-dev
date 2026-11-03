@tool
extends RefCounted
## Editor-only bridge from art-production into native Godot Resources.
## Never read by the game at runtime. The importer never overwrites source images.

const EXTENSIONS := ["png", "webp", "jpg", "jpeg", "svg"]
const MODES := ["portrait", "atlas", "scene", "ui_atlas", "vfx"]
const MANIFEST := "res://data/content_manifest.tres"
const CombatScale = preload("res://scripts/combat_scale.gd")


## Candidate art must have a full-size, safely contained idle reference.
## Old in-use legacy fallback is still importable for compatibility.
static func candidate_idle_scale_error(texture: Texture2D, columns: int, rows: int,
        frame_index: int) -> String:
    var img: Image = texture.get_image() if texture != null else null
    if img == null or img.is_empty() or columns < 1 or rows < 1 or \
            img.get_width() % columns != 0 or img.get_height() % rows != 0 or \
            frame_index < 0 or frame_index >= columns * rows:
        return "无法读取 Atlas 脚点参考帧"
    var fw: int = img.get_width() / columns
    var fh: int = img.get_height() / rows
    var min_x: int = fw
    var min_y: int = fh
    var max_x: int = -1
    var max_y: int = -1
    var ox: int = (frame_index % columns) * fw
    var oy: int = (frame_index / columns) * fh
    for y in range(fh):
        for x in range(fw):
            if img.get_pixel(ox+x,oy+y).a < 0.20:
                continue
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if max_x < 0:
        return "Atlas 待机参考帧没有可见角色"
    var proportion: float = float(max_y-min_y+1)/float(fh)
    if proportion < CombatScale.REFERENCE_HEIGHT_MIN_FRACTION or \
            proportion > CombatScale.REFERENCE_HEIGHT_MAX_FRACTION:
        return "待机人物高度不符合格高 35%～95% 的贴图比例约束"
    var margin: int = CombatScale.SAFE_FRAME_MARGIN_PX
    if min_x < margin or min_y < margin or max_x >= fw-margin or max_y >= fh-margin:
        return "待机参考帧触碰格线；请为四边各留至少 8px 透明边距"
    return ""


static func production_root() -> String:
    return ProjectSettings.globalize_path("res://").path_join("../../art-production").simplify_path()


static func _source_allowed(path: String) -> bool:
    var canonical := path.simplify_path()
    var root := production_root()
    return canonical.begins_with(root + "/in-use/") or canonical.begins_with(root + "/candidates/")


static func collect_sources() -> Array[String]:
    var found: Array[String] = []
    for group in ["in-use", "candidates"]:
        _collect(production_root().path_join(group), found)
    found.sort()
    return found


static func _collect(folder: String, found: Array[String]) -> void:
    if found.size() >= 2000:
        return
    var directory := DirAccess.open(folder)
    if directory == null:
        return
    directory.list_dir_begin()
    var entry := directory.get_next()
    while not entry.is_empty():
        if not entry.begins_with(".") and not directory.is_link(entry):
            var absolute := folder.path_join(entry)
            if directory.current_is_dir():
                _collect(absolute, found)
            elif EXTENSIONS.has(entry.get_extension().to_lower()):
                found.append(absolute.simplify_path())
        entry = directory.get_next()
    directory.list_dir_end()


static func inspect(path: String) -> Dictionary:
    if not _source_allowed(path) or not FileAccess.file_exists(path):
        return {"error": "素材不在 art-production/in-use 或 candidates 中"}
    if not EXTENSIONS.has(path.get_extension().to_lower()):
        return {"error": "仅支持 PNG、WebP、JPG 和 SVG"}
    var image := Image.new()
    var err := OK
    if path.get_extension().to_lower() == "svg":
        err = image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path))
    else:
        err = image.load(path)
    if err != OK or image.is_empty():
        return {"error": "图像解码失败：" + str(err)}
    return {
        "error": "",
        "path": path.simplify_path(),
        "width": image.get_width(),
        "height": image.get_height(),
        "alpha": image.detect_alpha() != Image.ALPHA_NONE,
        "texture": ImageTexture.create_from_image(image),
        "sha256": FileAccess.get_sha256(path),
    }


static func destination(path: String) -> String:
    if not _source_allowed(path):
        return ""
    var relative := path.simplify_path().trim_prefix(production_root() + "/")
    # Production folders already follow the imported/{in-use,candidates}/ type/owner layout.
    return "res://assets/imported/" + relative


static func _check_image(path: String, require_alpha: bool, expected: Vector2i = Vector2i.ZERO, versioned: bool = false) -> Dictionary:
    var info := inspect(path)
    if not str(info.get("error", "")).is_empty():
        return info
    if require_alpha and not bool(info["alpha"]):
        return {"error": "角色或遮挡层必须具有实际透明像素：" + path.get_file()}
    if expected != Vector2i.ZERO and Vector2i(int(info["width"]), int(info["height"])) != expected:
        return {"error": "图层尺寸不符合目标画布 %s：%s" % [str(expected), path.get_file()]}
    var target := destination(path)
    if target.is_empty():
        return {"error": "无法生成导入目标路径"}
    var previous := ""
    if FileAccess.file_exists(target) and FileAccess.get_sha256(target) != str(info["sha256"]):
        if not versioned:
            return {"error": "目标图片已存在且内容不同；勾选版本化替换：" + target}
        previous = target
        target = target.get_basename() + "__" + str(info["sha256"]).substr(0, 12) + "." + target.get_extension()
        if FileAccess.file_exists(target) and FileAccess.get_sha256(target) != str(info["sha256"]):
            return {"error": "版本文件 SHA-256 冲突：" + target}
    info["replaces"] = previous
    info["destination"] = target
    return info


static func _valid_id(value: String) -> bool:
    if value.is_empty() or value.length() > 128 or value.begins_with(".") or value.ends_with(".") or value.contains(".."):
        return false
    for i in range(value.length()):
        var c := value.substr(i, 1)
        if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c not in ["_", ".", "-"]:
            return false
    return true


static func plan(mode: String, source: String, target: String, fields: Dictionary) -> Dictionary:
    var result := {"error": "", "mode": mode, "target": target, "files": {}}
    if not MODES.has(mode):
        return {"error": "不支持的导入模式"}
    var owner: Resource = null
    var expected := Vector2i.ZERO
    if mode == "portrait" or mode == "atlas":
        if not target.begins_with("res://data/native/characters/") or not target.ends_with(".tres"):
            return {"error": "需要选择 data/native/characters 内的角色卡"}
        owner = ResourceLoader.load(target)
        if not owner is WuxiaCharacterDefinition:
            return {"error": "角色 Resource 类型不正确"}
    elif mode == "scene":
        if not target.ends_with(".tres") or not (
                target.begins_with("res://data/maps/") or target.begins_with("res://data/native/chapters/")):
            return {"error": "需要选择 data/maps 地图或 data/native/chapters 章节 Resource"}
        owner = ResourceLoader.load(target)
        if owner is WuxiaMapDefinition or owner is WuxiaGridMapDefinition:
            if not CombatScale.valid_map_pixels_per_unit(float(owner.get("pixels_per_unit"))):
                return {"error": "地图比例尺与战斗统一比例尺不符"}
            var art_rotation: float = float(owner.get("rotation_degrees")) if owner is WuxiaGridMapDefinition else float(owner.get("image_rotation_degrees"))
            if not CombatScale.valid_map_art_transform(float(owner.get("image_scale")), art_rotation):
                return {"error": "地图贴图变换必须为原始 1:1 尺度且旋转为 0"}
            expected = owner.get("viewport_size")
        elif owner is WuxiaChapterDefinition and owner.get("scene") is WuxiaChapterSceneDefinition:
            expected = Vector2i(owner.get("scene").get("world_size"))
        else:
            return {"error": "场景目标不是有效的地图或章节 Resource"}
    else:
        var id := str(fields.get("asset_id", "")).strip_edges()
        if not _valid_id(id):
            return {"error": "UI/VFX 登记 ID 只允许小写字母、数字、点、横线、下划线"}
        result["target"] = "res://data/native/assets/" + id + ".tres"
        var existing := ResourceLoader.load(result["target"]) if ResourceLoader.exists(result["target"]) else null
        if existing != null and not existing is WuxiaAssetDefinition:
            return {"error": "登记路径已有非 WuxiaAssetDefinition Resource"}
        if existing == null:
            var manifest := ResourceLoader.load(MANIFEST) as WuxiaContentManifest
            if manifest == null:
                return {"error": "无法加载内容注册表"}
            for category in ["schools", "characters", "buffs", "items", "affixes",
                             "rule_catalogs", "action_timelines", "skills", "techniques",
                             "effect_handlers", "stories", "chapters", "quests",
                             "encounters", "assets", "maps"]:
                for registered in manifest.get(category):
                    if registered is WuxiaContentDefinition and registered.content_id == id:
                        return {"error": "登记 ID 已被其他内容占用：" + id}
    var alpha_required := mode in ["portrait", "atlas", "vfx"]
    var versioned := bool(fields.get("versioned_replace", false))
    var first := _check_image(source, alpha_required, expected, versioned)
    if not str(first.get("error", "")).is_empty():
        return first
    result["files"]["primary"] = first
    result["next_binding"] = str(first["destination"])
    result["current_binding"] = ""
    if mode == "portrait":
        var old_portrait: Texture2D = owner.get("portrait") as Texture2D
        result["current_binding"] = old_portrait.resource_path if old_portrait != null else ""
    if mode == "atlas":
        var old_sheet: Texture2D = owner.get("sprite_sheet") as Texture2D
        result["current_binding"] = old_sheet.resource_path if old_sheet != null else ""
        var cols := int(fields.get("columns", 6))
        var rows := int(fields.get("rows", 4))
        if cols < 1 or cols > 64 or rows < 1 or rows > 64:
            return {"error": "Atlas 列数和行数必须为 1..64"}
        if int(first["width"]) % cols != 0 or int(first["height"]) % rows != 0:
            return {"error": "Atlas 宽高必须能被列数和行数整除"}
        result["columns"] = cols
        result["rows"] = rows
        result["feet_offset"] = fields.get("feet_offset", Vector2(0, -102))
        result["faces_left"] = bool(fields.get("faces_left", false))
        var clip_path := str(fields.get("clip_profile_path", "")).strip_edges()
        var profile: WuxiaActorAnimationProfile = null
        if not clip_path.is_empty():
            if not clip_path.begins_with("res://data/") or clip_path.contains("..") or not ResourceLoader.exists(clip_path):
                return {"error": "动画 Profile 模板路径不可用：" + clip_path}
            profile = ResourceLoader.load(clip_path) as WuxiaActorAnimationProfile
            if profile == null:
                return {"error": "动画 Profile 模板不是 WuxiaActorAnimationProfile"}
        else:
            profile = owner.get("animation_profile") as WuxiaActorAnimationProfile
            if profile == null:
                profile = ResourceLoader.load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
        if profile == null:
            return {"error": "缺少原生动画 Profile 模板"}
        result["clip_profile_path"] = clip_path
        var staged := profile.duplicate(true) as WuxiaActorAnimationProfile
        staged.atlas = first["texture"]
        staged.columns = cols
        staged.rows = rows
        if not staged.valid_profile():
            return {"error": "现有动作帧与新 Atlas 不兼容；请在 Inspector 先编辑 Profile 的 clips"}
        if source.simplify_path().begins_with(production_root().path_join("candidates/")):
            var idle_clip: WuxiaActorAnimationClip = staged.clip_for("idle")
            var reference: int = int(idle_clip.frames[0]) if idle_clip != null and not idle_clip.frames.is_empty() else -1
            var scale_problem: String = candidate_idle_scale_error(
                first["texture"], cols, rows, reference)
            if not scale_problem.is_empty():
                return {"error": scale_problem}
        result["profile_path"] = "res://data/native/animations/" + str(owner.get("content_id")) + ".tres"
    if mode == "scene":
        var scene_holder: Resource = owner.get("scene") if owner is WuxiaChapterDefinition else owner
        var old_background: Texture2D = scene_holder.get("background") as Texture2D
        var old_scene: WuxiaSceneArtProfile = scene_holder.get("scene_art") as WuxiaSceneArtProfile
        result["current_binding"] = old_background.resource_path if old_background != null else ""
        result["current_scene_profile"] = old_scene.resource_path if old_scene != null else ""
        for layer in ["ground", "foreground", "weather", "story_preview"]:
            var layer_path := str(fields.get(layer, "")).strip_edges()
            if layer == "ground" and layer_path.is_empty():
                return {"error": "场景必须提供独立 ground 图层"}
            if layer == "ground" and layer_path.simplify_path() == source.simplify_path():
                return {"error": "ground 不得复用 background 文件；需独立地面图层"}
            if layer_path.is_empty():
                continue
            var check := _check_image(layer_path, layer in ["ground", "foreground", "weather"], expected, versioned)
            if not str(check.get("error", "")).is_empty():
                return check
            result["files"][layer] = check
        var scene_id := str(owner.get("content_id")) + ("_story" if owner is WuxiaChapterDefinition else "")
        result["profile_path"] = "res://data/native/scene_art/" + scene_id + ".tres"
    if mode in ["vfx", "ui_atlas"] and ResourceLoader.exists(str(result["target"])):
        var old_asset := ResourceLoader.load(str(result["target"])) as WuxiaAssetDefinition
        if old_asset != null and old_asset.resource != null:
            result["current_binding"] = old_asset.resource.resource_path
    if mode == "vfx":
        var vfx_columns: int = int(fields.get("columns", 1))
        var vfx_rows: int = int(fields.get("rows", 1))
        if vfx_columns < 1 or vfx_columns > 64 or vfx_rows < 1 or vfx_rows > 64:
            return {"error": "VFX 图集行列必须为 1..64"}
        if int(first["width"]) % vfx_columns != 0 or int(first["height"]) % vfx_rows != 0:
            return {"error": "VFX 图集必须能被行列整除"}
        var vfx_frames: PackedInt32Array = fields.get("frame_indices", PackedInt32Array())
        if vfx_frames.is_empty():
            vfx_frames = PackedInt32Array([0])
        if vfx_frames.size() > 256:
            return {"error": "VFX 帧数不可超过 256"}
        for frame in vfx_frames:
            if frame < 0 or frame >= vfx_columns * vfx_rows:
                return {"error": "VFX 帧索引超出图集范围"}
        result["columns"] = vfx_columns
        result["rows"] = vfx_rows
        result["frame_indices"] = vfx_frames
        var event := str(fields.get("event_kind", "")).strip_edges()
        if not event.is_empty():
            var manifest := ResourceLoader.load(MANIFEST) as WuxiaContentManifest
            if manifest == null:
                return {"error": "无法加载 VFX 注册表"}
            for registered in manifest.assets:
                if registered is WuxiaAssetDefinition and registered.content_id != str(fields.get("asset_id", "")) and registered.event_kind == event:
                    return {"error": "VFX 事件已绑定其他素材：" + event}
        result["event_kind"] = event
    result["owner"] = owner
    return result


static func copy_images(files: Dictionary) -> String:
    for info in files.values():
        var source := str(info["path"])
        var target := str(info["destination"])
        if FileAccess.file_exists(target):
            if FileAccess.get_sha256(source) != FileAccess.get_sha256(target):
                return "文件内容发生变化，停止导入：" + target
            continue
        var absolute := ProjectSettings.globalize_path(target)
        var err := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
        if err != OK:
            return "无法创建素材目录：" + str(err)
        err = DirAccess.copy_absolute(source, absolute)
        if err != OK:
            return "复制素材失败：" + str(err)
        if FileAccess.get_sha256(source) != FileAccess.get_sha256(target):
            return "复制后 SHA-256 不一致：" + target
    return ""


static func _backup(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var root := production_root().path_join("reviews/import-backups")
    if DirAccess.make_dir_recursive_absolute(root) != OK:
        return "创建备份目录失败：" + root
    var stamp := Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_usec())
    var target := root.path_join(path.get_file() + "." + stamp + ".bak")
    var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), target)
    return "" if err == OK else "备份失败：" + path


static func _save(resource: Resource, path: String) -> String:
    var absolute := ProjectSettings.globalize_path(path)
    var make_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if make_error != OK:
        return "无法创建 Resource 目录：" + str(make_error)
    var backup_error := _backup(path)
    if not backup_error.is_empty():
        return backup_error
    var err := ResourceSaver.save(resource, path)
    return "" if err == OK else "保存 Resource 失败：" + path + " (" + str(err) + ")"


static func save_bindings(plan_data: Dictionary) -> String:
    var files: Dictionary = plan_data["files"]
    var textures := {}
    for key in files:
        var path := str(files[key]["destination"])
        var tex := ResourceLoader.load(path, "Texture2D") as Texture2D
        if tex == null:
            return "Godot Importer 尚未完成：" + path
        textures[key] = tex
    var mode := str(plan_data["mode"])
    var target := str(plan_data["target"])
    if mode == "portrait" or mode == "atlas":
        var character := ResourceLoader.load(target) as WuxiaCharacterDefinition
        if character == null:
            return "角色卡在导入期间发生变化"
        if mode == "portrait":
            character.portrait = textures["primary"]
            character.portrait_quality = "candidate"
        else:
            var clip_path := str(plan_data.get("clip_profile_path", ""))
            var template: WuxiaActorAnimationProfile = null
            if not clip_path.is_empty():
                template = ResourceLoader.load(clip_path) as WuxiaActorAnimationProfile
            else:
                template = character.animation_profile
                if template == null:
                    template = ResourceLoader.load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
            if template == null:
                return "动画 Profile 模板不可用"
            var profile := template.duplicate(true) as WuxiaActorAnimationProfile
            profile.atlas = textures["primary"]
            profile.columns = int(plan_data["columns"])
            profile.rows = int(plan_data["rows"])
            profile.feet_offset = plan_data["feet_offset"]
            profile.faces_left_unflipped = bool(plan_data["faces_left"])
            if not profile.valid_profile():
                return "新 Atlas 的动作定义不合法"
            var profile_error := _save(profile, str(plan_data["profile_path"]))
            if not profile_error.is_empty():
                return profile_error
            character.sprite_sheet = textures["primary"]
            character.animation_profile = profile
            character.sheet_quality = "candidate"
        var char_error := _save(character, target)
        if char_error.is_empty():
            character.emit_changed()
        return char_error
    if mode == "scene":
        var map := ResourceLoader.load(target)
        if map == null:
            return "场景 Resource 在导入期间发生变化"
        var scene_holder: Resource = map.get("scene") if map is WuxiaChapterDefinition else map
        if scene_holder == null:
            return "章节缺少场景定义"
        var profile := WuxiaSceneArtProfile.new()
        profile.reference_size = Vector2i(map.get("scene").get("world_size")) if map is WuxiaChapterDefinition else map.get("viewport_size")
        profile.background = textures["primary"]
        profile.ground = textures["ground"]
        if textures.has("foreground"):
            profile.foreground = textures["foreground"]
        if textures.has("weather"):
            profile.weather = textures["weather"]
        if textures.has("story_preview"):
            profile.story_preview = textures["story_preview"]
        if not profile.valid_for(profile.reference_size):
            return "场景层未通过 viewport 一致性检查"
        var art_error := _save(profile, str(plan_data["profile_path"]))
        if not art_error.is_empty():
            return art_error
        scene_holder.set("scene_art", profile)
        # Both chapter and battle consumers may still read the single background.
        # Never allow the pre-import painting to mask newly imported layers.
        scene_holder.set("background", textures["primary"])
        if map is WuxiaGridMapDefinition:
            map.source_size = map.viewport_size
            map.rotation_degrees = 0.0
            map.image_scale = 1.0
        elif map is WuxiaMapDefinition:
            map.image_rotation_degrees = 0.0
            map.image_scale = 1.0
        var map_error := _save(map, target)
        if map_error.is_empty():
            map.emit_changed()
        return map_error

    var card := ResourceLoader.load(target) as WuxiaAssetDefinition if ResourceLoader.exists(target) else null
    var creating := card == null
    if creating:
        card = WuxiaAssetDefinition.new()
        card.content_id = target.get_file().get_basename()
    card.asset_kind = mode
    card.status = "candidate"
    card.resource = textures["primary"]
    card.source = "art_production"
    card.rights = "owner_review_required"
    card.columns = int(plan_data.get("columns", 1)) if mode == "vfx" else 1
    card.rows = int(plan_data.get("rows", 1)) if mode == "vfx" else 1
    if mode == "vfx":
        card.frame_indices = plan_data.get("frame_indices", PackedInt32Array())
        card.event_kind = str(plan_data.get("event_kind", ""))
    var manifest := ResourceLoader.load(MANIFEST) as WuxiaContentManifest
    if manifest == null:
        return "内容注册表不可用"
    if creating:
        manifest.assets.append(card)
    var card_error := _save(card, target)
    if not card_error.is_empty():
        return card_error
    if creating:
        var manifest_error := _save(manifest, MANIFEST)
        if not manifest_error.is_empty():
            return manifest_error
    return ""
