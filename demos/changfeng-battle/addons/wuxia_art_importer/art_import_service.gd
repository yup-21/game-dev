@tool
extends RefCounted
## Editor-only bridge from art-production into native Godot Resources.
## Never read by the game at runtime. The importer never overwrites source images.

const EXTENSIONS := ["png", "webp", "jpg", "jpeg", "svg"]
const MODES := ["portrait", "atlas", "scene", "ui_atlas", "vfx", "character_folder"]
const MANIFEST := "res://data/content_manifest.tres"
const CombatScale = preload("res://scripts/combat_scale.gd")
const SpriteAssembly = preload("res://addons/wuxia_art_importer/sprite_assembly.gd")


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


static func candidate_for_source(path: String) -> WuxiaArtCandidateDefinition:
    var root: String = production_root().path_join("candidates") + "/"
    var canonical: String = path.simplify_path()
    if not canonical.begins_with(root):
        return null
    var relative: String = canonical.trim_prefix(root)
    var resource_path: String = "res://data/art_candidates/" + relative.get_basename() + ".tres"
    if not ResourceLoader.exists(resource_path):
        return null
    return ResourceLoader.load(resource_path) as WuxiaArtCandidateDefinition


static func _source_allowed(path: String) -> bool:
    var canonical := path.simplify_path()
    var root := production_root()
    return canonical.begins_with(root + "/in-use/") or canonical.begins_with(root + "/candidates/") \
        or not _imported_path(canonical).is_empty()


static func _imported_path(path: String) -> String:
    var canonical := path.simplify_path()
    if canonical.begins_with("res://assets/imported/characters/"):
        return canonical
    var filesystem_root := ProjectSettings.globalize_path("res://assets/imported/characters").simplify_path()
    if canonical.begins_with(filesystem_root + "/"):
        return "res://assets/imported/characters/" + canonical.trim_prefix(filesystem_root + "/")
    return ""


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
        err = image.load(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
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


## Imported filenames identify a role, while folders identify the owner.
## Candidate originals keep their source filename; only the Godot copy is renamed.
static func _import_filename(source: String, mode: String, owner: String) -> String:
    var stem := source.get_file().get_basename()
    var ext := "." + source.get_extension().to_lower()
    if mode == "portrait" and stem.begins_with("portrait_" + owner + "_fullbody_"):
        return "portrait" + ext
    if mode == "atlas" and stem.begins_with("sprite_" + owner + "_atlas_"):
        var variant := stem.trim_prefix("sprite_" + owner + "_atlas_")
        if variant.begins_with("aligned_"):
            return "atlas" + ext
        if variant.begins_with("8x6_") or variant.begins_with("6x4_"):
            variant = variant.substr(4)
        return "atlas_" + variant + ext
    if mode == "scene":
        for layer in ["background", "ground", "foreground", "weather", "composite_preview"]:
            if stem.begins_with("scene_") and stem.contains("_" + layer + "_v"):
                return ("story_preview" if layer == "composite_preview" else layer) + ext
    if mode == "ui_atlas":
        if stem.begins_with("card_"):
            return stem.trim_prefix("card_") + ext
        if stem.begins_with("technique_art_atlas_"):
            return "atlas" + ext
    if mode == "vfx" and stem.begins_with("vfx_"):
        return "atlas" + ext
    return source.get_file()


static func destination(path: String, mode: String = "") -> String:
    if not _source_allowed(path):
        return ""
    var imported := _imported_path(path)
    if not imported.is_empty():
        var relative_import := imported.trim_prefix("res://assets/imported/")
        var parts_import := relative_import.split("/")
        if parts_import.size() < 4 or not _valid_id(str(parts_import[1])):
            return ""
        if mode == "portrait" and parts_import[2] != "portraits":
            return ""
        if mode == "atlas" and parts_import[2] != "sprites":
            return ""
        if mode not in ["portrait", "atlas"]:
            return ""
        return imported
    var relative := path.simplify_path().trim_prefix(production_root() + "/")
    if relative.begins_with("in-use/"):
        # Production status is not part of the Godot path.
        return "res://assets/imported/" + relative.trim_prefix("in-use/")
    if not relative.begins_with("candidates/"):
        return ""
    # A selected candidate becomes a Godot asset; keep production status only
    # in art-production, never in the res:// directory structure.
    # Drop candidate production batches (baseline, sprite-v04, qa-layout).
    var parts := relative.trim_prefix("candidates/").split("/")
    if parts.size() < 3 or not _valid_id(parts[1]):
        return ""
    var group := str(parts[0])
    var owner := str(parts[1])
    var folder := ""
    if group == "characters" and mode in ["portrait", "atlas"]:
        folder = "characters/" + owner + ("/portraits" if mode == "portrait" else "/sprites")
    elif group == "scenes" and mode == "scene":
        folder = "scenes/" + owner
    elif group == "vfx" and mode == "vfx" and parts.size() >= 4 and _valid_id(parts[2]):
        folder = "vfx/" + owner + "/" + str(parts[2])
    elif group == "ui" and mode == "ui_atlas":
        folder = "ui/" + owner
    if folder.is_empty():
        return ""
    return "res://assets/imported/" + folder + "/" + _import_filename(path, mode, owner)


## Both production roots use the same stable type/owner prefix.
## Source batch names and dates are deliberately ignored.
## A VFX has its own validated native Resource type; UI remains a generic asset.
static func _new_asset_card(mode: String) -> WuxiaAssetDefinition:
    return WuxiaVFXDefinition.new() if mode == "vfx" else WuxiaAssetDefinition.new()


static func _source_identity(path: String) -> PackedStringArray:
    if not _source_allowed(path):
        return PackedStringArray()
    var imported := _imported_path(path)
    if not imported.is_empty():
        return imported.trim_prefix("res://assets/imported/").split("/")
    var relative: String = path.simplify_path().trim_prefix(production_root() + "/")
    if relative.begins_with("in-use/"):
        relative = relative.trim_prefix("in-use/")
    elif relative.begins_with("candidates/"):
        relative = relative.trim_prefix("candidates/")
    else:
        return PackedStringArray()
    return relative.split("/")


static func _check_image(path: String, require_alpha: bool, expected: Vector2i = Vector2i.ZERO,
        versioned: bool = false, mode: String = "") -> Dictionary:
    var info := inspect(path)
    if not str(info.get("error", "")).is_empty():
        return info
    if require_alpha and not bool(info["alpha"]):
        return {"error": "角色或遮挡层必须具有实际透明像素：" + path.get_file()}
    if expected != Vector2i.ZERO and Vector2i(int(info["width"]), int(info["height"])) != expected:
        return {"error": "图层尺寸不符合目标画布 %s：%s" % [str(expected), path.get_file()]}
    var target := destination(path, mode)
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


## A character folder is already classified by its owner. Flat canonical
## portrait/atlas filenames are also accepted and moved into their type folder.
## Versioned files are never selected implicitly.
static func _character_folder_owner(folder: String) -> String:
    var source := folder.simplify_path().trim_suffix("/")
    var relative := ""
    var imported := _imported_path(source + "/portrait.png")
    if not imported.is_empty():
        relative = imported.trim_prefix("res://assets/imported/characters/").trim_suffix("/portrait.png")
    elif source.begins_with(production_root() + "/"):
        var parts := source.trim_prefix(production_root() + "/").split("/")
        if parts.size() != 3 or parts[0] not in ["candidates", "in-use"] or parts[1] != "characters":
            return ""
        relative = str(parts[2])
    return relative if _valid_id(relative) and not relative.contains("/") else ""


static func _default_image(folder: String, stem: String) -> Dictionary:
    if not DirAccess.dir_exists_absolute(folder):
        return {"error": "", "path": ""}
    var matches: Array[String] = []
    for file in DirAccess.get_files_at(folder):
        if str(file).get_basename() == stem and EXTENSIONS.has(str(file).get_extension().to_lower()):
            matches.append(folder.path_join(str(file)))
    if matches.size() > 1:
        return {"error": "同一默认素材存在多种格式：" + folder.path_join(stem), "path": ""}
    return {"error": "", "path": matches[0] if not matches.is_empty() else ""}


static func _one_of_default(folder: String, subdir: String, stem: String) -> Dictionary:
    var organized := _default_image(folder.path_join(subdir), stem)
    if not str(organized["error"]).is_empty():
        return organized
    var flat := _default_image(folder, stem)
    if not str(flat["error"]).is_empty():
        return flat
    if not str(organized["path"]).is_empty() and not str(flat["path"]).is_empty():
        return {"error": "同一素材在根目录与分类目录重复：" + stem, "path": ""}
    return organized if not str(organized["path"]).is_empty() else flat


static func _plan_to_path(source: String, target_path: String, require_alpha: bool,
        versioned: bool) -> Dictionary:
    var info := inspect(source)
    if not str(info.get("error", "")).is_empty():
        return info
    if require_alpha and not bool(info["alpha"]):
        return {"error": "角色立绘/动作要求真实透明像素：" + source.get_file()}
    var original := ""
    var destination_path := target_path
    if FileAccess.file_exists(destination_path) and \
            FileAccess.get_sha256(destination_path) != str(info["sha256"]):
        if not versioned:
            return {"error": "目标已存在且内容不同，请勾选版本化替换：" + target_path}
        original = destination_path
        destination_path = target_path.get_basename() + "__" + str(info["sha256"]).substr(0, 12) \
            + "." + target_path.get_extension()
        if FileAccess.file_exists(destination_path) and \
                FileAccess.get_sha256(destination_path) != str(info["sha256"]):
            return {"error": "版本文件 SHA-256 冲突：" + destination_path}
    info["destination"] = destination_path
    info["replaces"] = original
    return info


## This checks the declared grid, never tries to detect or rearrange AI frames.
## Visual continuity and real support-foot contacts still need separate review.
static func candidate_frame_geometry_error(texture: Texture2D, cols: int, count_rows: int,
        used_frames: PackedInt32Array) -> String:
    var image := texture.get_image() if texture != null else null
    if image == null or image.is_empty() or cols < 1 or count_rows < 1 or \
            image.get_width() % cols != 0 or image.get_height() % count_rows != 0:
        return "候选动作 Atlas 行列无法整除画布"
    var occupied := {}
    for frame in used_frames:
        if frame < 0 or frame >= cols * count_rows:
            return "动作帧索引超出候选 Atlas"
        occupied[frame] = true
    var fw := image.get_width() / cols
    var fh := image.get_height() / count_rows
    for frame in range(cols * count_rows):
        var rect := Rect2i((frame % cols) * fw, (frame / cols) * fh, fw, fh)
        var pixel_bounds := image.get_region(rect).get_used_rect()
        if occupied.has(frame):
            if not pixel_bounds.has_area():
                return "有效帧为空：" + str(frame)
            if pixel_bounds.position.x < SpriteAssembly.MARGIN or \
                    pixel_bounds.position.y < SpriteAssembly.MARGIN or \
                    pixel_bounds.end.x > fw - SpriteAssembly.MARGIN or \
                    pixel_bounds.end.y > fh - SpriteAssembly.MARGIN:
                return "候选帧四边不足 8px 真透明留白：" + str(frame)
        elif pixel_bounds.has_area():
            return "未使用帧格存在像素：" + str(frame)
    return ""


static func _composed_profile(template: WuxiaActorAnimationProfile, atlas: Texture2D,
        assembly: Dictionary, fields: Dictionary) -> WuxiaActorAnimationProfile:
    var profile := template.duplicate(true) as WuxiaActorAnimationProfile
    profile.atlas = atlas
    profile.columns = int(assembly["columns"])
    profile.rows = int(assembly["rows"])
    profile.feet_offset = fields.get("feet_offset", Vector2(0, -102))
    profile.faces_left_unflipped = bool(fields.get("faces_left", false))
    profile.action_fallbacks = {} # No legacy aliases or missing-action fallback.
    profile.clips.clear()
    for action in SpriteAssembly.ACTIONS:
        var config: Dictionary = assembly["clips"][action]
        var clip := WuxiaActorAnimationClip.new()
        clip.action = action
        clip.frames = config["frames"]
        clip.loop = bool(config["loop"])
        clip.loop_fps = float(config["fps"])
        clip.frame_durations = config["durations"]
        profile.clips.append(clip)
    return profile


## Explicit multi-source sheet assembly. Source images remain in art-production;
## the new packed PNG and its fully authored twelve-action Profile are imported
## together through the existing transactional review/rollback path.
static func plan_composition(target: String, fields: Dictionary) -> Dictionary:
    if not target.begins_with("res://data/native/characters/") or not target.ends_with(".tres"):
        return {"error": "请选择目标角色 Resource"}
    var actor := ResourceLoader.load(target) as WuxiaCharacterDefinition
    if actor == null:
        return {"error": "目标角色 Resource 不存在"}
    var source_definitions: Array = fields.get("composition_sources", [])
    var sources: Array = []
    for item in source_definitions:
        var config: Dictionary = (item as Dictionary).duplicate(true)
        var path := str(config.get("path", ""))
        var details := inspect(path)
        if not str(details.get("error", "")).is_empty():
            return {"error": "源图：" + str(details["error"])}
        var identity := _source_identity(path)
        if identity.size() < 2 or identity[0] != "characters" or identity[1] != actor.content_id:
            return {"error": "源图不属于所选角色：" + path}
        var candidate := candidate_for_source(path)
        if path.simplify_path().begins_with(production_root().path_join("candidates/")):
            if candidate == null:
                return {"error": "候选源图缺少独立 .tres：" + path}
            var error: String = candidate.validate_source()
            if not error.is_empty():
                return {"error": error}
            if candidate.columns <= 0 or candidate.rows <= 0:
                return {"error": "候选源图尚未在 .tres 声明真实 C×R 网格：" + path}
            if candidate.columns != int(config.get("columns", 0)) or \
                    candidate.rows != int(config.get("rows", 0)):
                return {"error": "源图网格与候选 Resource 声明不同：" + path}
        config["texture"] = details["texture"]
        sources.append(config)
    var requested_cell := Vector2i(384, 288) if bool(fields.get("composition_tall", false)) \
        else Vector2i(328, 256)
    var assembly := SpriteAssembly.build(sources,
        fields.get("composition_actions", {}), fields.get("composition_metadata", {}), requested_cell)
    if not str(assembly.get("error", "")).is_empty():
        return assembly
    var template_path := str(fields.get("clip_profile_path", "")).strip_edges()
    if not template_path.is_empty() and (not template_path.begins_with("res://data/") or \
            template_path.contains("..") or not ResourceLoader.exists(template_path)):
        return {"error": "动作 Profile 模板路径不可用"}
    var template: WuxiaActorAnimationProfile = ResourceLoader.load(template_path) as WuxiaActorAnimationProfile \
        if not template_path.is_empty() else actor.animation_profile
    if template == null:
        template = ResourceLoader.load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
    if template == null:
        return {"error": "缺少动画 Profile 模板"}
    var staged := _composed_profile(template, assembly["texture"], assembly, fields)
    if not staged.valid_profile():
        return {"error": "组合图集动作配置未通过原生 Profile 验证"}
    var hash: String = assembly["sha256"]
    var destination_path := "res://assets/imported/characters/" + actor.content_id + "/sprites/atlas.png"
    var replaced := ""
    if FileAccess.file_exists(destination_path) and FileAccess.get_sha256(destination_path) != hash:
        if not bool(fields.get("versioned_replace", false)):
            return {"error": "目标 Atlas 已存在且内容不同；请启用版本化替换"}
        replaced = destination_path
        destination_path = destination_path.get_basename() + "__" + hash.substr(0, 12) + ".png"
        if FileAccess.file_exists(destination_path) and FileAccess.get_sha256(destination_path) != hash:
            return {"error": "版本化图片哈希冲突"}
    return {"error": "", "mode": "atlas", "composition": true, "target": target,
        "owner": actor, "profile_path": "res://data/native/animations/" + actor.content_id + ".tres",
        "template_path": template_path, "clip_profile_path": template_path,
        "assembly": assembly, "feet_offset": fields.get("feet_offset", Vector2(0, -102)),
        "faces_left": bool(fields.get("faces_left", false)),
        "files": {"primary": {"path": str(source_definitions[0]["path"]), "destination": destination_path,
            "sha256": hash, "generated_bytes": assembly["bytes"], "replaces": replaced}},
        "current_binding": actor.sprite_sheet.resource_path if actor.sprite_sheet != null else "",
        "next_binding": destination_path}


## One atomic plan for an existing character: portrait + shared Atlas and/or
## independently configured per-action Atlas. No image content is used to guess
## a grid, a frame index or an animation's meaning.
static func plan_character_folder(folder: String, target: String, fields: Dictionary) -> Dictionary:
    var actor_id := _character_folder_owner(folder)
    if actor_id.is_empty():
        return {"error": "请选择角色根目录：candidates/characters/<id>、in-use/characters/<id> 或 res://assets/imported/characters/<id>"}
    if not DirAccess.dir_exists_absolute(folder):
        return {"error": "角色目录不存在：" + folder}
    if target != "res://data/native/characters/" + actor_id + ".tres":
        return {"error": "角色目录 ID 与目标 Resource 不匹配：" + actor_id}
    var character := ResourceLoader.load(target) as WuxiaCharacterDefinition
    if character == null or character.content_id != actor_id:
        return {"error": "请先创建并登记角色定义：" + target}

    var found: Dictionary = {}
    for role in ["portrait", "atlas"]:
        var subdir := "portraits" if role == "portrait" else "sprites"
        var item := _one_of_default(folder, subdir, role)
        if not str(item["error"]).is_empty():
            return item
        if not str(item["path"]).is_empty():
            found[role] = str(item["path"])
    for action in WuxiaActorAnimationProfile.MODERN_REQUIRED_ACTIONS:
        var in_sprites := _default_image(folder.path_join("sprites").path_join(action), "atlas")
        var in_actions := _default_image(folder.path_join("actions").path_join(action), "atlas")
        if not str(in_sprites["error"]).is_empty():
            return in_sprites
        if not str(in_actions["error"]).is_empty():
            return in_actions
        if not str(in_sprites["path"]).is_empty() and not str(in_actions["path"]).is_empty():
            return {"error": "动作存在重复来源：" + action}
        var source := str(in_sprites["path"]) if not str(in_sprites["path"]).is_empty() else str(in_actions["path"])
        if not source.is_empty():
            found["clip_" + action] = source
    if found.is_empty():
        return {"error": "没有找到规范化的 portrait/atlas 文件；不会自动选择 _vNN 备选或猜测 Sprite Sheet 帧格"}

    var files := {}
    var replace := bool(fields.get("versioned_replace", false))
    for role in found:
        var source_path := str(found[role])
        var extension := source_path.get_extension().to_lower()
        var suffix := "portraits/portrait" if role == "portrait" else "sprites/atlas"
        if str(role).begins_with("clip_"):
            suffix = "sprites/" + str(role).trim_prefix("clip_") + "/atlas"
        var destination_path := "res://assets/imported/characters/" + actor_id + "/" + suffix + "." + extension
        var info := _plan_to_path(source_path, destination_path, true, replace)
        if not str(info.get("error", "")).is_empty():
            return info
        files[role] = info

    var result := {"error": "", "mode": "character_folder", "target": target,
        "files": files, "owner": actor_id, "source_folder": folder,
        "current_binding": character.sprite_sheet.resource_path if character.sprite_sheet != null else "",
        "next_binding": str(files["atlas"]["destination"]) if files.has("atlas") else "（保留当前 Atlas）"}
    var has_clips := false
    for key in files:
        has_clips = has_clips or str(key).begins_with("clip_")
    if files.has("atlas") or has_clips:
        var template_path := str(fields.get("clip_profile_path", "")).strip_edges()
        if not template_path.is_empty() and (not template_path.begins_with("res://data/") or
                template_path.contains("..") or not ResourceLoader.exists(template_path)):
            return {"error": "原生动画 Profile 模板不可用：" + template_path}
        var profile: WuxiaActorAnimationProfile = ResourceLoader.load(template_path) as WuxiaActorAnimationProfile \
            if not template_path.is_empty() else character.animation_profile
        if profile == null:
            return {"error": "角色缺少有效的动画 Profile；请先选择模板"}
        var staged := profile.duplicate(true) as WuxiaActorAnimationProfile
        if files.has("atlas"):
            staged.atlas = files["atlas"]["texture"]
        for key in files:
            if not str(key).begins_with("clip_"):
                continue
            var action := str(key).trim_prefix("clip_")
            var clip: WuxiaActorAnimationClip = staged.clip_for(action)
            if clip == null:
                return {"error": "Profile 缺少动作 Clip：" + action}
            clip.atlas = files[key]["texture"]
        if not staged.valid_profile():
            return {"error": "动作帧索引、行列或统一格子不匹配；请在 Profile 中明确配置各 Clip"}
        if folder.simplify_path().begins_with(production_root() + "/candidates/"):
            var shared_indices := PackedInt32Array()
            for action in WuxiaActorAnimationProfile.MODERN_REQUIRED_ACTIONS:
                var clip: WuxiaActorAnimationClip = staged.clip_for(action)
                if clip == null:
                    continue
                var key: String = "clip_" + str(action)
                if files.has(key):
                    var geometry_error := candidate_frame_geometry_error(
                        files[key]["texture"], clip.columns, clip.rows, clip.frames)
                    if not geometry_error.is_empty():
                        return {"error": action + "：" + geometry_error}
                elif clip.atlas == null:
                    for frame in clip.frames:
                        if not shared_indices.has(frame):
                            shared_indices.append(frame)
            if files.has("atlas") and not shared_indices.is_empty():
                var atlas_error := candidate_frame_geometry_error(
                    staged.atlas, staged.columns, staged.rows, shared_indices)
                if not atlas_error.is_empty():
                    return {"error": atlas_error}
        if files.has("atlas") and folder.simplify_path().begins_with(production_root() + "/candidates/"):
            var idle := staged.clip_for("idle")
            var ref_index := int(idle.frames[0]) if idle != null and not idle.frames.is_empty() else -1
            var scale_error := candidate_idle_scale_error(staged.atlas, staged.columns, staged.rows, ref_index)
            if not scale_error.is_empty():
                return {"error": scale_error}
        result["profile_path"] = "res://data/native/animations/" + actor_id + ".tres"
        result["template_path"] = template_path
    return result


static func plan(mode: String, source: String, target: String, fields: Dictionary) -> Dictionary:
    if mode == "character_folder":
        return plan_character_folder(source, target, fields)
    if mode == "atlas" and bool(fields.get("composition_enabled", false)):
        return plan_composition(target, fields)
    var result := {"error": "", "mode": mode, "target": target, "files": {}}
    if not MODES.has(mode):
        return {"error": "不支持的导入模式"}
    var candidate_root: String = production_root().path_join("candidates") + "/"
    var candidate: WuxiaArtCandidateDefinition = null
    if source.simplify_path().begins_with(candidate_root):
        candidate = candidate_for_source(source)
        if candidate == null:
            return {"error": "候选图片缺少对应的原生 .tres Resource"}
        var candidate_problem: String = candidate.validate_source()
        if not candidate_problem.is_empty():
            return {"error": candidate_problem}
        if mode in ["atlas", "vfx"] and candidate.columns == 0:
            return {"error": "候选 Resource 尚未声明图集 C×R 网格；请先核实原图后填写"}
        if mode in ["atlas", "vfx"] and (
                candidate.columns != int(fields.get("columns", 0)) or
                candidate.rows != int(fields.get("rows", 0))):
            return {"error": "图集列/行与候选 Resource 声明不一致；请先调整候选 Resource 或导入设置"}
        if mode == "atlas" and candidate.display_scale_override > 0.0:
            if candidate.reference_visible_height_px <= 0.0:
                return {"error": "手动角色缩放需要先测量待机可见高度"}
            var displayed_height: float = candidate.reference_visible_height_px * candidate.display_scale_override
            if absf(displayed_height - CombatScale.actor_height_pixels()) > 10.0:
                return {"error": "候选角色缩放偏离统一 200px 站立高度，请校正参考高度或倍数"}
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
        if existing != null:
            if mode == "vfx" and not existing is WuxiaVFXDefinition:
                return {"error": "VFX 必须使用 WuxiaVFXDefinition"}
            if mode == "ui_atlas" and (not existing is WuxiaAssetDefinition or existing is WuxiaVFXDefinition):
                return {"error": "UI 目标不是通用 Asset Resource"}
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
    var source_parts: PackedStringArray = _source_identity(source)
    if source_parts.size() >= 2:
        if mode in ["portrait", "atlas"] and source_parts[0] == "characters" and \
                source_parts[1] != str(owner.get("content_id")):
            return {"error": "候选角色 ID 与目标角色 Resource 不一致：" + str(source_parts[1])}
        if mode == "scene" and source_parts[0] == "scenes" and \
                (owner is WuxiaMapDefinition or owner is WuxiaGridMapDefinition) and \
                source_parts[1] != str(owner.get("content_id")):
            return {"error": "场景素材 ID 与目标地图 Resource 不一致：" + str(source_parts[1])}
        if mode == "vfx" and source_parts[0] == "vfx" and source_parts[1] != "shared" and \
                _valid_id(str(source_parts[1])):
            result["owner_character_id"] = str(source_parts[1])
    var alpha_required := mode in ["portrait", "atlas", "vfx"]
    var versioned := bool(fields.get("versioned_replace", false))
    var first := _check_image(source, alpha_required, expected, versioned, mode)
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
        if candidate != null and candidate.display_scale_override > 0.0:
            result["candidate_scale_override"] = candidate.display_scale_override
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
            if not bool(fields.get("reuse_existing_clips", false)):
                return {"error": "新 Atlas 必须通过自由装配指定十二动作帧序，或显式选择 Profile 模板；旧素材可勾选沿用已有帧配置"}
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
            var check := _check_image(layer_path, layer in ["ground", "foreground", "weather"], expected, versioned, mode)
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
            if str(info["sha256"]) != FileAccess.get_sha256(target):
                return "文件内容发生变化，停止导入：" + target
            continue
        var absolute := ProjectSettings.globalize_path(target)
        var err := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
        if err != OK:
            return "无法创建素材目录：" + str(err)
        if info.has("generated_bytes"):
            var output := FileAccess.open(target, FileAccess.WRITE)
            if output == null:
                return "无法创建装配图集：" + target
            output.store_buffer(info["generated_bytes"])
            output.close()
        else:
            var source_absolute := ProjectSettings.globalize_path(source) if source.begins_with("res://") else source
            err = DirAccess.copy_absolute(source_absolute, absolute)
        if err != OK:
            return "复制素材失败：" + str(err)
        if str(info["sha256"]) != FileAccess.get_sha256(target):
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
    if mode == "character_folder":
        var actor := ResourceLoader.load(target) as WuxiaCharacterDefinition
        if actor == null or actor.content_id != str(plan_data.get("owner", "")):
            return "角色目录导入时目标 Resource 已改变"
        if textures.has("portrait"):
            actor.portrait = textures["portrait"]
            actor.portrait_quality = "candidate"
        if plan_data.has("profile_path"):
            var template_path := str(plan_data.get("template_path", ""))
            var source_profile := ResourceLoader.load(template_path) as WuxiaActorAnimationProfile \
                if not template_path.is_empty() else actor.animation_profile
            if source_profile == null:
                return "动画 Profile 模板在导入期间消失"
            var profile := source_profile.duplicate(true) as WuxiaActorAnimationProfile
            if textures.has("atlas"):
                profile.atlas = textures["atlas"]
                actor.sprite_sheet = textures["atlas"]
            for key in textures:
                if not str(key).begins_with("clip_"):
                    continue
                var action := str(key).trim_prefix("clip_")
                var clip: WuxiaActorAnimationClip = profile.clip_for(action)
                if clip == null:
                    return "缺少动作 Clip：" + action
                clip.atlas = textures[key]
            if not profile.valid_profile():
                return "分动作 Atlas 与原生 Profile 不兼容"
            var profile_error := _save(profile, str(plan_data["profile_path"]))
            if not profile_error.is_empty():
                return profile_error
            actor.animation_profile = profile
            actor.sheet_quality = "candidate"
        var error := _save(actor, target)
        if error.is_empty():
            actor.emit_changed()
        return error
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
            var profile: WuxiaActorAnimationProfile
            if bool(plan_data.get("composition", false)):
                profile = _composed_profile(template, textures["primary"],
                    plan_data["assembly"], plan_data)
            else:
                profile = template.duplicate(true) as WuxiaActorAnimationProfile
                profile.atlas = textures["primary"]
                profile.columns = int(plan_data["columns"])
                profile.rows = int(plan_data["rows"])
                profile.feet_offset = plan_data["feet_offset"]
            if float(plan_data.get("candidate_scale_override", 0.0)) > 0.0:
                profile.auto_fit_height = false
                profile.actor_scale = Vector2.ONE * float(plan_data["candidate_scale_override"])
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
    if card != null:
        if mode == "vfx" and not card is WuxiaVFXDefinition:
            return "现有 VFX Resource 不是 WuxiaVFXDefinition"
        if mode == "ui_atlas" and card is WuxiaVFXDefinition:
            return "不能将 VFX Resource 当作 UI 资源覆盖"
    var creating := card == null
    if creating:
        card = _new_asset_card(mode)
        card.content_id = target.get_file().get_basename()
    card.asset_kind = mode
    # Importing and binding makes this the active runtime selection, not a candidate.
    card.status = "runtime"
    card.resource = textures["primary"]
    card.source = "art_production"
    card.rights = "owner_review_required"
    card.columns = int(plan_data.get("columns", 1)) if mode == "vfx" else 1
    card.rows = int(plan_data.get("rows", 1)) if mode == "vfx" else 1
    if mode == "vfx":
        var detected_owner: String = str(plan_data.get("owner_character_id", ""))
        if not detected_owner.is_empty():
            if not card.owner_character_id.is_empty() and card.owner_character_id != detected_owner:
                return "VFX 已属于其他角色，请使用新的素材 ID 或手动调整原生 Resource"
            card.owner_character_id = detected_owner
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
