extends RefCounted
## Validates and resolves Godot-imported assets. No runtime filesystem scan.
const Native = preload("res://scripts/content/content_registry.gd")
const KINDS = ["portrait","pose_sheet","static_pose","scene","vfx","actor_scene","audio","ui_atlas"]
const STATUSES = ["concept","preview","candidate","runtime","approved"]
var definitions: Dictionary = {}
var character_index: Dictionary = {}
var event_index: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = Native.DEFAULT_MANIFEST) -> void:
    var native = Native.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for entry in native.entries("asset").values():
        if not _register(entry): return

func _register(spec: Variant) -> bool:
    if not spec is Dictionary or str(spec.get("id","")).is_empty():
        return _fail("Invalid asset ID")
    var id: String = str(spec.id)
    var kind: String = str(spec.get("kind",""))
    var path: String = str(spec.get("path",""))
    if definitions.has(id) or kind not in KINDS or str(spec.get("status","")) not in STATUSES or \
            not path.begins_with("res://") or path.contains("..") or \
            not (path.begins_with("res://assets/") or (kind == "actor_scene" and path.begins_with("res://scenes/"))) or \
            not ResourceLoader.exists(path):
        return _fail("Invalid or missing asset: " + id)
    if str(spec.get("source","")).is_empty() or str(spec.get("rights","")).is_empty():
        return _fail("Asset provenance missing: " + id)
    if str(spec.status) == "approved" and str(spec.rights) != "verified":
        return _fail("Approved asset without verified rights: " + id)
    var expected: String = "PackedScene" if kind == "actor_scene" else ("AudioStream" if kind == "audio" else "Texture2D")
    var loaded: Resource = ResourceLoader.load(path, expected)
    if loaded == null:
        return _fail("Wrong asset resource type: " + id)
    if loaded is Texture2D:
        var columns: int = int(spec.get("columns",0))
        var rows: int = int(spec.get("rows",0))
        if columns < 1 or rows < 1 or columns > 64 or rows > 64 or \
                loaded.get_width() < columns or loaded.get_height() < rows or \
                loaded.get_width() % columns != 0 or loaded.get_height() % rows != 0:
            return _fail("Invalid asset grid: " + id)
        if kind == "pose_sheet" and (columns != 6 or rows != 4):
            return _fail("Battle pose sheet must be 6x4: " + id)
    var character_id: String = str(spec.get("owner_character_id",""))
    if not character_id.is_empty():
        var key: String = character_id + ":" + kind
        if character_index.has(key) or kind not in ["portrait","pose_sheet","static_pose","actor_scene"]:
            return _fail("Duplicate/invalid character art binding: " + key)
        character_index[key] = id
    var event_kind: String = str(spec.get("event_kind",""))
    if not event_kind.is_empty():
        if event_index.has(event_kind) or kind not in ["vfx","audio"]:
            return _fail("Duplicate/invalid event art binding: " + event_kind)
        event_index[event_kind] = id
    definitions[id] = spec.duplicate(true)
    return true

func _fail(message: String) -> bool:
    load_error = message
    definitions.clear()
    character_index.clear()
    event_index.clear()
    return false

func record(id: String) -> Dictionary:
    return definitions.get(id,{}).duplicate(true)

func record_for_character(character_id: String, kind: String) -> Dictionary:
    return record(str(character_index.get(character_id + ":" + kind,"")))

func texture(id: String) -> Texture2D:
    var spec: Dictionary = definitions.get(id,{})
    if spec.is_empty() or str(spec.get("kind","")) in ["actor_scene","audio"]: return null
    return ResourceLoader.load(str(spec.path),"Texture2D") as Texture2D

func texture_for_character(character_id: String, kind: String) -> Texture2D:
    return texture(str(character_index.get(character_id + ":" + kind,"")))

func texture_for_event(event_kind: String) -> Texture2D:
    return texture(str(event_index.get(event_kind,"")))

func scene_for_character(character_id: String) -> PackedScene:
    var spec: Dictionary = record_for_character(character_id,"actor_scene")
    if spec.is_empty(): return null
    return ResourceLoader.load(str(spec.path),"PackedScene") as PackedScene

func audio_for_event(event_kind: String) -> AudioStream:
    var spec: Dictionary = record(str(event_index.get(event_kind,"")))
    if spec.is_empty() or str(spec.kind) != "audio": return null
    return ResourceLoader.load(str(spec.path),"AudioStream") as AudioStream
