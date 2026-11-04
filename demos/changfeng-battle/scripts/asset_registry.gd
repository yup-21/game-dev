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
            not (path.begins_with("res://assets/imported/") or (kind in ["actor_scene", "vfx"] and path.begins_with("res://scenes/"))) or \
            not ResourceLoader.exists(path):
        return _fail("Invalid or missing asset: " + id)
    if str(spec.get("source","")).is_empty() or str(spec.get("rights","")).is_empty():
        return _fail("Asset provenance missing: " + id)
    if str(spec.status) == "approved" and str(spec.rights) != "verified":
        return _fail("Approved asset without verified rights: " + id)
    var is_scene_vfx: bool = kind == "vfx" and path.get_extension() in ["tscn", "scn"]
    var expected: String = "PackedScene" if kind == "actor_scene" or is_scene_vfx else ("AudioStream" if kind == "audio" else "Texture2D")
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
        # The 6x4 layout is a legacy playback convention, not a registry contract.
        # Authored sheets use their character-owned AnimationProfile for frame indices.
    if kind == "vfx":
        if is_scene_vfx:
            var instance: Node = (loaded as PackedScene).instantiate()
            if not instance is Node2D:
                if instance != null:
                    instance.free()
                return _fail("VFX scene root must be Node2D: " + id)
            instance.free()
            if int(spec.get("columns", 1)) != 1 or int(spec.get("rows", 1)) != 1:
                return _fail("VFX scene must not declare a texture grid: " + id)
        var indices: PackedInt32Array = spec.get("frame_indices", PackedInt32Array())
        var capacity: int = int(spec.get("columns", 1)) * int(spec.get("rows", 1))
        if indices.size() > 256:
            return _fail("VFX frame limit exceeded: " + id)
        for frame in indices:
            if frame < 0 or frame >= capacity:
                return _fail("Invalid VFX frame index: " + id)
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
    if spec.is_empty() or str(spec.get("kind","")) in ["actor_scene","audio"] or \
            str(spec.get("path", "")).get_extension() in ["tscn", "scn"]: return null
    return ResourceLoader.load(str(spec.path),"Texture2D") as Texture2D

func texture_for_character(character_id: String, kind: String) -> Texture2D:
    return texture(str(character_index.get(character_id + ":" + kind,"")))

func record_for_event(event_kind: String) -> Dictionary:
    return record(str(event_index.get(event_kind, "")))

## A VFX binding may name a native asset ID or an authored event_kind.
func vfx_spec(slot: String) -> Dictionary:
    var direct: Dictionary = record(slot)
    if str(direct.get("kind", "")) == "vfx":
        return direct
    var event: Dictionary = record_for_event(slot)
    return event if str(event.get("kind", "")) == "vfx" else {}

func vfx_scene(slot: String) -> PackedScene:
    var spec: Dictionary = vfx_spec(slot)
    if spec.is_empty():
        return null
    var path: String = str(spec.get("path", ""))
    if path.get_extension() not in ["tscn", "scn"]:
        return null
    return ResourceLoader.load(path, "PackedScene") as PackedScene

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
