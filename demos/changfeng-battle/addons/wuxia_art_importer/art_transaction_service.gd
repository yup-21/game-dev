@tool
extends RefCounted
## Offline transaction journal for .tres changes. New image files remain recoverable.
## A rollback never silently overwrites subsequent user edits.

const MANIFEST := "res://data/content_manifest.tres"


static func _root() -> String:
    return ProjectSettings.globalize_path("res://").path_join("../../art-production/reviews/import-transactions").simplify_path()


static func _inside(path: String, root: String) -> bool:
    return path.simplify_path().begins_with(root.simplify_path() + "/")


static func _write(path: String, value: Dictionary) -> String:
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
        return "无法创建事务目录"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return "无法写入事务记录：" + path
    file.store_string(JSON.stringify(value, "\t") + "\n")
    file.close()
    return ""


static func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var obj = JSON.parse_string(FileAccess.get_file_as_string(path))
    return obj if obj is Dictionary else {}


static func validate(plans: Array[Dictionary]) -> String:
    if plans.is_empty() or plans.size() > 64:
        return "批量导入需要 1..64 个条目"
    var targets: Dictionary = {}
    var logical_targets: Dictionary = {}
    var images: Dictionary = {}
    for plan in plans:
        if not str(plan.get("error", "")).is_empty():
            return str(plan["error"])
        var key := str(plan.get("target", "")) + "|" + str(plan.get("mode", ""))
        if targets.has(key):
            return "同一 Resource 和导入类型重复入队：" + key
        targets[key] = true
        var target_path := str(plan.get("target", ""))
        if target_path.is_empty() or not target_path.begins_with("res://data/") or ".." in target_path:
            return "非法 Resource 目标路径：" + target_path
        if logical_targets.has(target_path):
            if str(plan.get("mode", "")) in ["vfx", "ui_atlas"] or bool(logical_targets[target_path]):
                return "同一 Resource 不允许混合 UI/VFX 或冲突目标：" + target_path
        logical_targets[target_path] = str(plan.get("mode", "")) in ["vfx", "ui_atlas"]
        for item in plan.get("files", {}).values():
            var path := str(item.get("destination", ""))
            var source_hash := str(item.get("sha256", ""))
            if not path.begins_with("res://assets/imported/") or ".." in path or source_hash.length() != 64:
                return "导入计划的目标路径或哈希非法：" + path
            if images.has(path) and images[path] != source_hash:
                return "不同图片写入同一路径：" + path
            images[path] = source_hash
    return ""


static func _resource_paths(plans: Array[Dictionary]) -> Array[String]:
    var paths: Dictionary = {}
    for plan in plans:
        paths[str(plan["target"])] = true
        if plan.has("profile_path"):
            paths[str(plan["profile_path"])] = true
        if str(plan["mode"]) in ["ui_atlas", "vfx"]:
            paths[MANIFEST] = true
    var sorted: Array[String] = []
    for path in paths:
        sorted.append(str(path))
    sorted.sort()
    return sorted


static func begin(plans: Array[Dictionary]) -> Dictionary:
    var failure := validate(plans)
    if not failure.is_empty():
        return {"error": failure}
    var id := Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_usec())
    var journal := _root().path_join(id)
    if DirAccess.make_dir_recursive_absolute(journal) != OK:
        return {"error": "事务备份目录创建失败"}
    var resources: Array[Dictionary] = []
    for path in _resource_paths(plans):
        if not path.begins_with("res://data/") or ".." in path:
            return {"error": "拒绝备份非内容 Resource：" + path}
        var absolute := ProjectSettings.globalize_path(path)
        var exists := FileAccess.file_exists(path)
        var before := ""
        if exists:
            before = journal.path_join("before/" + str(resources.size()) + ".tres")
            if DirAccess.make_dir_recursive_absolute(before.get_base_dir()) != OK:
                return {"error": "无法创建事务备份路径"}
            if DirAccess.copy_absolute(absolute, before) != OK:
                return {"error": "无法备份 Resource：" + path}
        resources.append({
            "path": path, "existed": exists, "before": before,
            "before_sha256": FileAccess.get_sha256(path) if exists else "",
            "after_sha256": ""
        })
    var files: Array[Dictionary] = []
    var seen: Dictionary = {}
    for plan in plans:
        for item in plan["files"].values():
            var path := str(item["destination"])
            if not seen.has(path):
                files.append({
                    "path": path, "sha256": str(item["sha256"]),
                    "preexisting": FileAccess.file_exists(path)
                })
                seen[path] = true
    var record := {
        "schema_version": 1, "state": "prepared",
        "resources": resources, "images": files, "error": ""
    }
    var log_path := journal.path_join("import-log.json")
    failure = _write(log_path, record)
    return {"error": failure, "journal": log_path}


static func commit(log_path: String) -> String:
    if not _inside(log_path, _root()):
        return "非法事务记录路径"
    var record := _read(log_path)
    if str(record.get("state", "")) != "prepared":
        return "事务不是 prepared 状态"
    for item in record["resources"]:
        var path := str(item["path"])
        if not FileAccess.file_exists(path):
            return "提交后 Resource 缺失：" + path
        item["after_sha256"] = FileAccess.get_sha256(path)
    for item in record["images"]:
        if FileAccess.get_sha256(str(item["path"])) != str(item["sha256"]):
            return "提交后图片不一致：" + str(item["path"])
    record["state"] = "committed"
    return _write(log_path, record)


static func rollback(log_path: String, failed_during_apply: bool = false) -> String:
    if not _inside(log_path, _root()) or log_path.get_file() != "import-log.json":
        return "非法事务记录路径"
    var record := _read(log_path)
    var state := str(record.get("state", ""))
    if state != "committed" and not (failed_during_apply and state == "prepared"):
        return "当前事务不能回退：" + state
    # Preflight all paths before restoring any file.
    for item in record.get("resources", []):
        var path := str(item.get("path", ""))
        if not path.begins_with("res://data/") or ".." in path:
            return "事务 Resource 路径越界"
        if state == "committed" and FileAccess.get_sha256(path) != str(item["after_sha256"]):
            return "Resource 已被后续修改，拒绝覆盖：" + path
        if bool(item["existed"]):
            var before := str(item["before"])
            if not _inside(before, _root()) or FileAccess.get_sha256(before) != str(item["before_sha256"]):
                return "事务备份已损坏，拒绝回退：" + path
    var recovered := log_path.get_base_dir().path_join("recovered-new")
    for item in record["resources"]:
        var path := str(item["path"])
        var absolute := ProjectSettings.globalize_path(path)
        if bool(item["existed"]):
            if DirAccess.copy_absolute(str(item["before"]), absolute) != OK:
                return "无法恢复原始 Resource：" + path
            ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
        elif FileAccess.file_exists(path):
            var safe := recovered.path_join(path.trim_prefix("res://"))
            if DirAccess.make_dir_recursive_absolute(safe.get_base_dir()) != OK:
                return "无法保留新增 Resource"
            if DirAccess.rename_absolute(absolute, safe) != OK:
                return "无法移动新增 Resource：" + path
    record["state"] = "failed_rolled_back" if failed_during_apply else "rolled_back"
    record["error"] = "未删除新图片；仅恢复 .tres。若 Inspector 仍显示旧缓存，请重新打开 Resource。"
    return _write(log_path, record)
