extends SceneTree
## Validate actual native art registrations, not an obsolete JSON ledger.
const ArtRegistry = preload("res://scripts/asset_registry.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, what: String) -> void:
    if not ok:
        failures += 1
        push_error("ASSET_CONTRACT: " + what)

func _run() -> void:
    var assets = ArtRegistry.new()
    _check(assets.load_error.is_empty(), "native asset manifest loads")
    var checked := 0
    for id in assets.definitions.keys():
        var data: Dictionary = assets.record(str(id))
        var path: String = str(data.get("path", ""))
        var columns: int = int(data.get("columns", 1))
        var rows: int = int(data.get("rows", 1))
        _check((str(data.get("kind", "")) == "actor_scene" or path.begins_with("res://assets/imported/")), "registered artwork uses imported path: " + str(id))
        var resource: Resource = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
        _check(resource != null, "registered native resource exists: " + str(id))
        if resource is Texture2D:
            var tex := resource as Texture2D
            _check(columns > 0 and rows > 0 and tex.get_width() % columns == 0 and tex.get_height() % rows == 0,
                "native atlas grid: " + str(id))
        checked += 1
    _check(checked > 0, "native asset definitions registered")
    print("ASSET_CONTRACT_PASS checked=%d failures=%d" % [checked, failures])
    quit(1 if failures > 0 else 0)
