@tool
extends RefCounted
## Editor-only artwork exporter. Copies original source files, never imported caches.
## The journal is offline art-production metadata, not a runtime data model.

const IMAGE_EXTS := ["png", "webp", "jpg", "jpeg", "svg"]
const IMAGE_REF := "res://assets/[A-Za-z0-9_./%+-]+"
const RESOURCE_REF := "res://[A-Za-z0-9_./%+-]+"
const ExportKinds := ["all", "character", "scene", "resource"]
const Native = preload("res://scripts/content/content_registry.gd")
const ArtBinding = preload("res://scripts/content/art_resource_binding.gd")


static func production_root() -> String:
    return ProjectSettings.globalize_path("res://").path_join("../../art-production").simplify_path()


static func _patterns() -> Array[RegEx]:
    var image := RegEx.new()
    image.compile(IMAGE_REF)
    var resource := RegEx.new()
    resource.compile(RESOURCE_REF)
    return [image, resource]


static func _inside(path: String, prefix: String) -> bool:
    return path.simplify_path().begins_with(prefix.simplify_path() + "/")


static func _collect(folder: String, files: Array[String], extensions: Array[String], excluded: Array[String] = []) -> void:
    var directory := DirAccess.open(folder)
    if directory == null:
        return
    directory.list_dir_begin()
    var filename := directory.get_next()
    while not filename.is_empty():
        if not filename.begins_with(".") and not directory.is_link(filename):
            var path := folder.path_join(filename)
            var skip := false
            for denied in excluded:
                if path == denied or path.begins_with(denied + "/"):
                    skip = true
                    break
            if not skip:
                if directory.current_is_dir():
                    _collect(path, files, extensions, excluded)
                elif extensions.has(filename.get_extension().to_lower()):
                    files.append(path)
        filename = directory.get_next()
    directory.list_dir_end()


static func _read_text(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    return FileAccess.get_file_as_string(path)


static func _all_images() -> Array[String]:
    var files: Array[String] = []
    _collect("res://scripts", files, ["gd"])
    _collect("res://data", files, ["tres"], ["res://data/templates", "res://data/art_previews", "res://data/native/assets"])
    _collect("res://scenes", files, ["tscn"])
    var root := DirAccess.open("res://")
    if root != null:
        for filename in DirAccess.get_files_at("res://"):
            if str(filename).ends_with(".tscn"):
                files.append("res://" + str(filename))
    var pattern := _patterns()[0]
    var art: Dictionary = {}
    for path in files:
        for match in pattern.search_all(_read_text(path)):
            var resource := match.get_string()
            if IMAGE_EXTS.has(resource.get_extension().to_lower()) and FileAccess.file_exists(resource):
                art[resource] = true
    var sorted: Array[String] = []
    for resource in art:
        sorted.append(str(resource))
    sorted.sort()
    return sorted


## Native Resources also contain convention-resolved textures that are absent
## from serialized .tres path literals. Walk only presentation-bearing fields,
## including independent per-clip atlases; never scan candidate directories.
static func _add_texture(paths: Dictionary, texture: Texture2D) -> void:
    if texture != null and not texture.resource_path.is_empty():
        paths[texture.resource_path] = true


static func _collect_native_images(resource: Resource, paths: Dictionary) -> void:
    if resource == null:
        return
    if resource is WuxiaCharacterDefinition:
        for key in ["portrait", "sprite_sheet", "static_pose"]:
            _add_texture(paths, resource.get(key) as Texture2D)
        _collect_native_images(resource.get("animation_profile") as Resource, paths)
    elif resource is WuxiaActorAnimationProfile:
        var profile: WuxiaActorAnimationProfile = resource as WuxiaActorAnimationProfile
        _add_texture(paths, profile.atlas)
        for entry in profile.clips:
            if entry is WuxiaActorAnimationClip:
                var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
                _add_texture(paths, clip.atlas)
    elif resource is WuxiaMapDefinition or resource is WuxiaGridMapDefinition or resource is WuxiaChapterSceneDefinition:
        _add_texture(paths, resource.get("background") as Texture2D)
        _collect_native_images(resource.get("scene_art") as Resource, paths)
    elif resource is WuxiaChapterDefinition:
        _collect_native_images(resource.get("scene") as Resource, paths)
    elif resource is WuxiaSceneArtProfile:
        for key in ["background", "ground", "foreground", "weather", "story_preview"]:
            _add_texture(paths, resource.get(key) as Texture2D)
    elif resource is WuxiaAssetDefinition:
        _add_texture(paths, resource.get("resource") as Texture2D)


static func native_image_paths(resource: Resource) -> Array[String]:
    var paths: Dictionary = {}
    _collect_native_images(resource, paths)
    var result: Array[String] = []
    for path in paths:
        result.append(str(path))
    result.sort()
    return result


static func _resource_graph(first: String) -> Dictionary:
    var images: Dictionary = {}
    var resources: Dictionary = {}
    var queue: Array[String] = [first]
    var pattern := _patterns()[1]
    var limit := 0
    while not queue.is_empty() and limit < 512:
        var path := queue.pop_front()
        limit += 1
        if resources.has(path) or not FileAccess.file_exists(path):
            continue
        if not path.begins_with("res://") or ".." in path:
            continue
        if path.get_extension().to_lower() not in ["tres", "tscn"]:
            continue
        resources[path] = true
        for match in pattern.search_all(_read_text(path)):
            var dependency := match.get_string()
            if dependency.begins_with("res://assets/") and IMAGE_EXTS.has(dependency.get_extension().to_lower()) and FileAccess.file_exists(dependency):
                images[dependency] = true
            elif dependency.begins_with("res://data/") and dependency.ends_with(".tres") and not resources.has(dependency):
                queue.append(dependency)
            elif dependency.begins_with("res://scenes/") and dependency.ends_with(".tscn") and not resources.has(dependency):
                queue.append(dependency)
    return {"images": images.keys(), "resources": resources.keys(), "truncated": not queue.is_empty()}


## A native map .tscn points *to* the canonical WuxiaMapDefinition, not vice
## versa. Follow the reverse link only for explicit scene exports, otherwise
## exporting the Map Resource would silently omit its editable scene layout.
static func native_map_scenes(map_path: String) -> Array[String]:
    var files: Array[String] = []
    _collect("res://scenes", files, ["tscn"])
    var result: Array[String] = []
    for path in files:
        var content := _read_text(path)
        if content.contains("source_map =") and content.contains('path="' + map_path + '"'):
            result.append(path)
    result.sort()
    return result


static func destination(source: String, is_resource: bool = false) -> String:
    if is_resource:
        return production_root().path_join("in-use/resources/" + source.trim_prefix("res://"))
    # In-use copies are grouped by type/owner; no date or imported/ nesting.
    if not source.begins_with("res://assets/imported/") or ".." in source:
        return ""
    var relative := source.trim_prefix("res://assets/imported/")
    return production_root().path_join("in-use/" + relative)


static func plan(kind: String, resource_path: String = "", allow_replace: bool = false) -> Dictionary:
    if kind not in ExportKinds:
        return {"error": "未知导出范围"}
    var image_paths: Array[String] = []
    var resource_paths: Array[String] = []
    if kind == "all":
        image_paths = _all_images()
        var native = Native.new()
        if not native.load_error.is_empty():
            return {"error": "Native Resource 引用校验失败：" + native.load_error}
        for content_kind in ["character", "map", "chapter", "asset"]:
            for definition in native.definition_resources.get(content_kind, {}).values():
                image_paths.append_array(native_image_paths(definition as Resource))
    else:
        if not resource_path.begins_with("res://") or not resource_path.ends_with(".tres") or ".." in resource_path:
            return {"error": "请选择有效的 Godot .tres Resource"}
        var source := ResourceLoader.load(resource_path)
        if source == null:
            return {"error": "无法加载选定 Resource"}
        if kind == "character" and not source is WuxiaCharacterDefinition:
            return {"error": "所选不是角色 Resource"}
        if kind == "scene" and not (source is WuxiaMapDefinition or source is WuxiaGridMapDefinition or
                (source is WuxiaChapterDefinition and source.get("scene") is WuxiaChapterSceneDefinition)):
            return {"error": "所选不是地图或章节场景 Resource"}
        var binding_problem: String = ArtBinding.apply(source)
        if not binding_problem.is_empty():
            return {"error": "Resource 默认素材绑定失败：" + binding_problem}
        var graph := _resource_graph(resource_path)
        if graph["truncated"]:
            return {"error": "Resource 依赖超过 512 个，拒绝不完整导出"}
        if kind == "scene" and source is WuxiaMapDefinition:
            for native_path in native_map_scenes(resource_path):
                var native_graph := _resource_graph(native_path)
                if native_graph["truncated"]:
                    return {"error": "原生场景依赖超过 512 个，拒绝不完整导出"}
                graph["images"].append_array(native_graph["images"])
                graph["resources"].append_array(native_graph["resources"])
        for image in graph["images"]:
            image_paths.append(str(image))
        var unique_resources: Dictionary = {}
        for metadata in graph["resources"]:
            unique_resources[metadata] = true
        for metadata in unique_resources:
            var dependency_path: String = str(metadata)
            resource_paths.append(dependency_path)
            if dependency_path == resource_path:
                continue
            var dependency: Resource = ResourceLoader.load(dependency_path) as Resource
            if dependency == null:
                return {"error": "无法加载 Resource 依赖：" + dependency_path}
            binding_problem = ArtBinding.apply(dependency)
            if not binding_problem.is_empty():
                return {"error": "Resource 依赖默认绑定失败：" + dependency_path + ": " + binding_problem}
            image_paths.append_array(native_image_paths(dependency))
        image_paths.append_array(native_image_paths(source))
    # Direct .tres references and convention-resolved paths can overlap.
    var distinct: Dictionary = {}
    for image in image_paths:
        distinct[image] = true
    image_paths.clear()
    for image in distinct:
        image_paths.append(str(image))
    image_paths.sort()
    resource_paths.sort()
    var entries: Array[Dictionary] = []
    var conflicts := 0
    var creates := 0
    var unchanged := 0
    for source in image_paths + resource_paths:
        var metadata := resource_paths.has(source)
        var target := destination(source, metadata)
        if target.is_empty():
            return {"error": "仅允许导出 assets/imported 下的正式图片：" + source}
        if not _inside(target, production_root().path_join("in-use")):
            return {"error": "目标路径越界：" + target}
        var sha := FileAccess.get_sha256(source)
        if sha.is_empty():
            return {"error": "无法校验源文件：" + source}
        var old := FileAccess.get_sha256(target) if FileAccess.file_exists(target) else ""
        var action := "create" if old.is_empty() else ("identical" if old == sha else "replace")
        if action == "create":
            creates += 1
        elif action == "identical":
            unchanged += 1
        else:
            conflicts += 1
        entries.append({
            "source": source, "destination": target, "sha256": sha,
            "previous_sha256": old, "action": action, "resource_metadata": metadata
        })
    return {"error": "", "kind": kind, "resource": resource_path,
            "entries": entries, "creates": creates, "identical": unchanged,
            "replaces": conflicts, "can_apply": conflicts == 0 or allow_replace,
            "allow_replace": allow_replace}


static func _write_json(path: String, value: Dictionary) -> String:
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
        return "无法创建导出日志目录"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return "无法保存导出日志：" + path
    file.store_string(JSON.stringify(value, "\t") + "\n")
    file.close()
    return ""


static func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}


static func export(plan_data: Dictionary) -> Dictionary:
    if not bool(plan_data.get("can_apply", false)):
        return {"error": "存在不同内容的副本，请先显式允许替换"}
    var entries: Array = plan_data.get("entries", [])
    # All bytes must be unchanged since the review dialog.
    for item in entries:
        var source := str(item["source"])
        var target := str(item["destination"])
        var old := FileAccess.get_sha256(target) if FileAccess.file_exists(target) else ""
        if FileAccess.get_sha256(source) != str(item["sha256"]) or old != str(item["previous_sha256"]):
            return {"error": "预检后文件已变化，请重新检查：" + source}
        if not _inside(target, production_root().path_join("in-use")):
            return {"error": "导出目标越界"}
    var id := Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_usec())
    var journal := production_root().path_join("reviews/export-transactions/" + id)
    if DirAccess.make_dir_recursive_absolute(journal) != OK:
        return {"error": "无法创建导出备份目录"}
    var saved: Array[Dictionary] = []
    for item in entries:
        var action := str(item["action"])
        var dest := str(item["destination"])
        var before := ""
        if action == "replace":
            before = journal.path_join("before/" + str(saved.size()) + ".bak")
            if DirAccess.make_dir_recursive_absolute(before.get_base_dir()) != OK or DirAccess.copy_absolute(dest, before) != OK:
                return {"error": "无法备份既有生产素材：" + dest}
        saved.append({
            "destination": dest, "action": action, "before": before,
            "sha256": str(item["sha256"]), "previous_sha256": str(item["previous_sha256"])
        })
    var log_path := journal.path_join("export-log.json")
    var record := {
        "schema_version": 1, "state": "prepared", "kind": str(plan_data.get("kind", "")),
        "source_resource": str(plan_data.get("resource", "")), "entries": saved,
        "error": ""
    }
    var journal_error := _write_json(log_path, record)
    if not journal_error.is_empty():
        return {"error": journal_error}
    var failure := ""
    for item in entries:
        if item["action"] == "identical":
            continue
        var dest := str(item["destination"])
        if DirAccess.make_dir_recursive_absolute(dest.get_base_dir()) != OK:
            failure = "无法创建导出目录：" + dest
            break
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(str(item["source"])), dest) != OK:
            failure = "导出复制失败：" + dest
            break
        if FileAccess.get_sha256(dest) != str(item["sha256"]):
            failure = "导出 SHA-256 不一致：" + dest
            break
    record["state"] = "committed" if failure.is_empty() else "failed"
    record["error"] = failure
    journal_error = _write_json(log_path, record)
    if not journal_error.is_empty():
        return {"error": journal_error, "journal": log_path}
    if not failure.is_empty():
        var rollback_error := rollback(log_path, true)
        return {"error": failure + ("；自动回退失败：" + rollback_error if not rollback_error.is_empty() else "；已自动回退"),
                "journal": log_path}
    return {"error": "", "journal": log_path, "count": saved.size()}


static func rollback(log_path: String, failed_during_apply: bool = false) -> String:
    var root := production_root().path_join("reviews/export-transactions")
    if not _inside(log_path, root) or log_path.get_file() != "export-log.json":
        return "非法导出日志路径"
    var record := _read_json(log_path)
    var state := str(record.get("state", ""))
    if state != "committed" and not (failed_during_apply and state == "failed"):
        return "仅允许回退已完成或执行失败的导出"
    # Refuse a rollback if an artist edited any copy since export.
    for item in record.get("entries", []):
        var dest := str(item.get("destination", ""))
        if not _inside(dest, production_root().path_join("in-use")):
            return "记录中的导出目标越界"
        var current := FileAccess.get_sha256(dest) if FileAccess.file_exists(dest) else ""
        var expected := str(item["sha256"])
        var previous := str(item["previous_sha256"])
        if state == "committed" and item["action"] != "identical" and current != expected:
            return "素材已被后续修改，拒绝回退：" + dest
        if state == "failed" and current != expected and current != previous and not (item["action"] == "create" and current.is_empty()):
            return "素材在导出失败后被其他进程修改，拒绝回退：" + dest
        if item["action"] == "replace":
            var before := str(item["before"])
            if not _inside(before, root) or FileAccess.get_sha256(before) != previous:
                return "旧素材备份缺失或已损坏：" + dest
    var recovered := log_path.get_base_dir().path_join("recovered-new")
    for item in record["entries"]:
        var action := str(item["action"])
        var dest := str(item["destination"])
        if action == "replace":
            if FileAccess.get_sha256(dest) != str(item["previous_sha256"]) and DirAccess.copy_absolute(str(item["before"]), dest) != OK:
                return "恢复旧素材失败：" + dest
        elif action == "create" and FileAccess.file_exists(dest):
            var safe := recovered.path_join(str(record["entries"].find(item)) + ".bak")
            if DirAccess.make_dir_recursive_absolute(safe.get_base_dir()) != OK:
                return "无法保留导出的新文件"
            if DirAccess.rename_absolute(dest, safe) != OK:
                return "移动新导出文件失败：" + dest
    record["state"] = "failed_rolled_back" if failed_during_apply else "rolled_back"
    return _write_json(log_path, record)
