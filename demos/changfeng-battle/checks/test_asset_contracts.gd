extends SceneTree
## Technical asset-import gate. This does not certify visual quality or rights.
const MANIFEST_PATH := "res://assets/production_manifest.json"
const KINDS := ["scene", "portrait", "pose_sheet", "pose_study", "ui_atlas"]
const STATUSES := ["concept", "preview", "candidate", "runtime", "approved"]
var failures: int = 0
var count: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("ASSET_CONTRACT: " + label)

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if not raw is Dictionary or raw.get("schema_version") != 1 or not raw.get("assets") is Array:
        _check(false, "valid manifest schema")
        quit(1)
        return
    var ids: Dictionary = {}
    var paths: Dictionary = {}
    for entry in raw.assets:
        if not entry is Dictionary:
            _check(false, "each asset entry is an object")
            continue
        var id: String = str(entry.get("id", ""))
        var path: String = str(entry.get("path", ""))
        var kind: String = str(entry.get("kind", ""))
        var status: String = str(entry.get("status", ""))
        _check(not id.is_empty() and not ids.has(id), "unique nonempty id: " + id)
        _check(path.begins_with("res://assets/") and not path.contains("..")
            and not paths.has(path), "safe unique asset path: " + path)
        _check(KINDS.has(kind) and STATUSES.has(status), id + ": controlled kind/status")
        _check(str(entry.get("source", "")).length() > 0
            and str(entry.get("rights", "")).length() > 0,
            id + ": provenance and usage-rights review recorded")
        ids[id] = true
        paths[path] = true
        if not path.begins_with("res://assets/") or path.contains(".."):
            continue
        _check(ResourceLoader.exists(path, "Texture2D"), id + ": imported Texture2D")
        var image := Image.new()
        var load_error: Error = image.load(path)
        _check(load_error == OK, id + ": source image decodes")
        if load_error != OK:
            continue
        count += 1
        var dimensions: Variant = entry.get("dimensions", [])
        if dimensions is Array and dimensions.size() == 2:
            _check(image.get_width() == int(dimensions[0])
                and image.get_height() == int(dimensions[1]),
                id + ": declared pixel dimensions")
        var grid: Variant = entry.get("grid", [])
        if grid is Array and grid.size() == 2:
            var cols: int = int(grid[0])
            var rows: int = int(grid[1])
            _check(cols > 0 and rows > 0
                and image.get_width() % maxi(1, cols) == 0
                and image.get_height() % maxi(1, rows) == 0,
                id + ": atlas cells divide evenly")
        if status == "candidate" or status == "preview":
            print("ASSET_QA_PENDING id=%s status=%s" % [id, status])
    print("ASSET_CONTRACT_PASS checked=%d failures=%d" % [count, failures])
    quit(1 if failures > 0 else 0)
