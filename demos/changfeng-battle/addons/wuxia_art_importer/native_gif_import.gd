@tool
extends RefCounted
## Explicit editor-only GIF -> native SpriteFrames importer.
## Original GIFs stay in art-production; no battle rules or runtime JSON.

const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const DECODER := "res://tools/gif_to_atlas.py"


static func _inside(path: String, root: String) -> bool:
    return path.simplify_path().begins_with(root.simplify_path() + "/")


static func _decode(source: String, output: String, cell: Vector2i) -> Dictionary:
    var decoder: String = ProjectSettings.globalize_path(DECODER)
    var extra: Array[String] = [decoder, source, output, str(cell.x), str(cell.y)]
    var result: Array = []
    var code := -1
    for interpreter in ["python3", "python"]:
        result.clear()
        code = OS.execute(interpreter, extra, result, true, true)
        if code != -1:
            break
    if code == -1:
        return {"error": "未找到 Python；GIF 解码器需要 Python 3 和 Pillow"}
    var output_text: String = "\n".join(result).strip_edges()
    var lines := output_text.split("\n", false)
    var parsed: Variant = JSON.parse_string(lines[-1]) if not lines.is_empty() else null
    if parsed is not Dictionary:
        return {"error": "GIF 解码器输出无效：" + output_text.substr(0, 240)}
    if code != 0 and str(parsed.get("error", "")).is_empty():
        return {"error": "GIF 解码失败：" + output_text.substr(0, 240)}
    return parsed


## Explicit action=absolute-GIF lines. Actions may be any lowercase identifier;
## no fixed nine/twelve-action table and no guessing inside mixed sheets.
static func parse_mapping(value: String) -> Dictionary:
    var mappings: Dictionary = {}
    for raw in value.split("\n", false):
        var line := raw.strip_edges()
        if line.is_empty() or line.begins_with("#"):
            continue
        var sep := line.find("=")
        if sep < 1:
            return {"error": "每行需要 action=完整 GIF 路径", "actions": {}}
        var action := line.substr(0, sep).strip_edges()
        var path := line.substr(sep + 1).strip_edges()
        if action.length() > 64 or not action.is_valid_identifier() or \
                action != action.to_lower() or not path.to_lower().ends_with(".gif") or \
                mappings.has(action):
            return {"error": "动作名或重复绑定非法：" + action, "actions": {}}
        mappings[action] = path
    if mappings.is_empty() or not mappings.has("idle") or mappings.size() > 64:
        return {"error": "至少指定 idle，最多 64 个不同动作", "actions": {}}
    return {"error": "", "actions": mappings}


## Explicit candidate registration, not an in-use binding. Existing candidate
## metadata is immutable here and must be fixed in the Inspector if it differs.
static func register_candidates(target: String, lines: String) -> Dictionary:
    var character: WuxiaCharacterDefinition = load(target) as WuxiaCharacterDefinition
    if character == null or character.content_id.is_empty() or \
            target != "res://data/native/characters/" + character.content_id + ".tres":
        return {"error": "请选择真实的目标角色 Resource"}
    var parsed := parse_mapping(lines)
    if not str(parsed["error"]).is_empty():
        return parsed
    var root: String = Service.production_root()
    var candidates: Array = []
    for action in parsed["actions"]:
        var path: String = str(parsed["actions"][action]).simplify_path()
        if not _inside(path, root.path_join("candidates/characters/" + character.content_id)) \
                or not FileAccess.file_exists(path):
            return {"error": "无法登记非本角色候选 GIF：" + path}
        var descriptor := "res://data/art_candidates/" + path.trim_prefix(
            root.path_join("candidates") + "/").get_basename() + ".tres"
        if FileAccess.file_exists(descriptor):
            var existing: WuxiaArtCandidateDefinition = load(descriptor) as WuxiaArtCandidateDefinition
            if existing == null or existing.action_id != action or existing.owner_id != character.content_id:
                return {"error": "已有候选 .tres 属性冲突，请人工修改：" + descriptor}
            continue
        var input := FileAccess.open(path, FileAccess.READ)
        if input == null or input.get_length() < 13 or \
                input.get_buffer(6).get_string_from_ascii() not in ["GIF87a", "GIF89a"]:
            return {"error": "候选 GIF 文件头损坏：" + path}
        var size := Vector2i(input.get_16(), input.get_16())
        if size.x <= 0 or size.y <= 0:
            return {"error": "候选 GIF 尺寸非法：" + path}
        var resource := WuxiaArtCandidateDefinition.new()
        resource.asset_kind = "sprite"
        resource.owner_id = character.content_id
        resource.action_id = str(action)
        resource.source_path = "art-production/candidates/" + path.trim_prefix(
            root.path_join("candidates") + "/")
        resource.source_pixel_size = size
        if not resource.validate_source().is_empty():
            return {"error": "候选 GIF 参数非法：" + path}
        candidates.append({"path": descriptor, "resource": resource})
    for item in candidates:
        var descriptor: String = item["path"]
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(descriptor).get_base_dir()) != OK \
                or ResourceSaver.save(item["resource"], descriptor) != OK:
            return {"error": "无法登记候选 .tres：" + descriptor}
    return {"error": "", "created": candidates.size()}


static func plan(target: String, lines: String, tall: bool = false) -> Dictionary:
    if not target.begins_with("res://data/native/characters/") or \
            not target.ends_with(".tres") or target.contains(".."):
        return {"error": "请指定正式角色 .tres"}
    var character := load(target) as WuxiaCharacterDefinition
    if character == null or character.content_id.is_empty():
        return {"error": "找不到目标角色定义"}
    var mapping := parse_mapping(lines)
    if not str(mapping["error"]).is_empty():
        return mapping
    var id: String = character.content_id
    var root: String = Service.production_root()
    var cell := Vector2i(384, 288) if tall else Vector2i(328, 256)
    var temp: String = OS.get_cache_dir().path_join("wuxia-native-gif-" + str(Time.get_ticks_usec()))
    if DirAccess.make_dir_recursive_absolute(temp) != OK:
        return {"error": "无法创建临时 GIF 审核文件夹"}
    var files: Dictionary = {}
    var actions: Dictionary = {}
    var originals: Dictionary = {}
    var action_ids: Array = mapping["actions"].keys()
    action_ids.sort()
    for key in action_ids:
        var action: String = str(key)
        var source: String = str(mapping["actions"][action]).simplify_path()
        if not (_inside(source, root.path_join("candidates/characters/" + id)) or \
                _inside(source, root.path_join("in-use/characters/" + id))):
            return {"error": action + "：GIF 必须位于本角色的 art-production 候选或在用目录"}
        if not FileAccess.file_exists(source):
            return {"error": action + "：GIF 源文件不存在"}
        if _inside(source, root.path_join("candidates/characters/" + id)):
            var candidate: WuxiaArtCandidateDefinition = Service.candidate_for_source(source)
            if candidate == null or candidate.asset_kind != "sprite" or \
                    candidate.owner_id != id or candidate.action_id != action or \
                    candidate.validate_source() != "":
                return {"error": action + "：候选 GIF 缺少有效独立 .tres 或动作归属不匹配"}
        var output := temp.path_join(action + ".png")
        var decoded := _decode(source, output, cell)
        if not str(decoded.get("error", "")).is_empty():
            return {"error": action + "：" + str(decoded["error"])}
        var digest := str(decoded.get("sha256", ""))
        if digest.length() != 64 or not FileAccess.file_exists(output) or \
                FileAccess.get_sha256(output) != digest:
            return {"error": action + "：临时图集哈希与解码结果不一致"}
        var destination := "res://assets/imported/characters/%s/sprites/%s/atlas__%s.png" % \
            [id, action, digest.substr(0, 12)]
        if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) != digest:
            return {"error": action + "：同名版本化图集存在哈希冲突"}
        files[action] = {"path": source, "destination": destination, "sha256": digest,
            "generated_path": output}
        decoded["source"] = source
        decoded["source_sha256"] = FileAccess.get_sha256(source)
        actions[action] = decoded
        originals[action] = source
    return {"error": "", "mode": "native_gif", "target": target,
        "profile_path": "res://data/native/animations/" + id + ".tres",
        "native_frames_path": "res://data/native/animations/" + id + "_frames.tres",
        "files": files, "actions": actions, "owner": id, "cell": cell,
        "originals": originals}


static func frames_for(plan_data: Dictionary, preview: bool = false) -> Dictionary:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    var actions: Dictionary = plan_data["actions"]
    var action_ids: Array = actions.keys()
    action_ids.sort()
    for key in action_ids:
        var action: String = str(key)
        var info: Dictionary = actions[action]
        var atlas_path: String = str(plan_data["files"][action]["destination"])
        var atlas: Texture2D = null
        if not preview and ResourceLoader.exists(atlas_path, "Texture2D"):
            atlas = ResourceLoader.load(atlas_path, "Texture2D") as Texture2D
        if atlas == null:
            # Headless or just-copied images may not yet have an .import cache.
            # Embedded ImageTexture is a valid native fallback, never a placeholder.
            var image := Image.new()
            var disk_path := str(plan_data["files"][action]["generated_path"]) if preview else \
                ProjectSettings.globalize_path(atlas_path)
            if image.load(disk_path) != OK:
                return {"error": "无法读取已复制的动作图集：" + atlas_path}
            atlas = ImageTexture.create_from_image(image)
        frames.add_animation(action)
        frames.set_animation_speed(action, 10.0)
        frames.set_animation_loop(action, action in ["idle", "walk", "run"])
        var count := int(info["frames"])
        var cols := int(info["columns"])
        var cell: Vector2i = plan_data["cell"]
        var durations: Array = info["durations_ms"]
        for index in range(count):
            var cropped := AtlasTexture.new()
            cropped.atlas = atlas
            cropped.region = Rect2(Vector2(index % cols, index / cols) * Vector2(cell), Vector2(cell))
            frames.add_frame(action, cropped, float(durations[index]) / 100.0)
    return {"error": "", "frames": frames}


## Save native assets via the existing hash-guarded transaction journal.
## The caller must present a confirmation dialog with the explicit target list.
static func apply(plan_data: Dictionary) -> Dictionary:
    if not str(plan_data.get("error", "")).is_empty() or \
            str(plan_data.get("mode", "")) != "native_gif":
        return {"error": "无效的原生 GIF 导入计划"}
    for key in plan_data["actions"]:
        var source: String = str(plan_data["actions"][key]["source"])
        if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != \
                str(plan_data["actions"][key]["source_sha256"]):
            return {"error": "预检后 GIF 被修改，请重新预检：" + source}
    var list: Array[Dictionary] = [plan_data]
    var transaction := Transaction.begin(list)
    if not str(transaction.get("error", "")).is_empty():
        return transaction
    var log_path: String = transaction["journal"]
    var failure := ""
    for item in plan_data["files"].values():
        var dest: String = str(item["destination"])
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest).get_base_dir()) != OK:
            failure = "无法创建动作图集目录：" + dest
            break
        if not FileAccess.file_exists(dest) and \
                DirAccess.copy_absolute(str(item["generated_path"]), ProjectSettings.globalize_path(dest)) != OK:
            failure = "无法复制动作图集：" + dest
            break
    if failure.is_empty():
        var built := frames_for(plan_data)
        failure = str(built.get("error", ""))
        if failure.is_empty():
            var frames: SpriteFrames = built["frames"]
            var char: WuxiaCharacterDefinition = load(str(plan_data["target"])) as WuxiaCharacterDefinition
            var profile: WuxiaActorAnimationProfile = char.animation_profile.duplicate(true) as WuxiaActorAnimationProfile \
                if char != null and char.animation_profile != null else \
                load("res://data/templates/actor_animation_profile.tres").duplicate(true) as WuxiaActorAnimationProfile
            profile.native_frames = frames
            profile.atlas = null
            profile.clips.clear() # Native frames are the only frame-order source.
            profile.action_fallbacks.clear()
            if not profile.valid_profile():
                failure = "生成的原生 SpriteFrames 未通过 Profile 校验"
            elif DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
                    str(plan_data["profile_path"])).get_base_dir()) != OK:
                failure = "无法创建原生 Resource 目录"
            elif ResourceSaver.save(frames, str(plan_data["native_frames_path"])) != OK:
                failure = "无法保存 SpriteFrames.tres"
            elif ResourceSaver.save(profile, str(plan_data["profile_path"])) != OK:
                failure = "无法保存 AnimationProfile.tres"
            else:
                var updated: WuxiaCharacterDefinition = char.duplicate(true) as WuxiaCharacterDefinition
                updated.animation_profile = profile
                if ResourceSaver.save(updated, str(plan_data["target"])) != OK:
                    failure = "无法更新角色原生 Resource"
    if failure.is_empty():
        failure = Transaction.commit(log_path)
    if not failure.is_empty():
        var rollback_error: String = Transaction.rollback(log_path, true)
        return {"error": failure + ("；撤销失败：" + rollback_error if not rollback_error.is_empty() else ""),
            "journal": log_path}
    return {"error": "", "journal": log_path, "frames_path": str(plan_data["native_frames_path"]),
        "profile_path": str(plan_data["profile_path"])}
