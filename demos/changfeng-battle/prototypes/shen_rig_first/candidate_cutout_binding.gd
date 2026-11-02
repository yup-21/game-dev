extends RefCounted
## Load 20 individually-pivoted transparent PNG candidates, not a single
## sprite-sheet attack swap. Godot-native Sprite2D rigid body attachments and
## Polygon2D weighted optional cosmetic meshes; no JSON runtime actor format.
const CANDIDATE_DIR := "res://prototypes/shen_rig_first/candidate_cutouts/"
const ART_TO_WORLD := 0.25

static func _load_image(path: String) -> ImageTexture:
    var img := Image.new()
    if img.load(path) != OK or img.is_empty():
        push_error("SHEN_CUTOUT_BIND: missing " + path)
        return null
    return ImageTexture.create_from_image(img)


static func _make_sprite(entry: Dictionary, tex: ImageTexture, bone: Node2D) -> Sprite2D:
    var part := Sprite2D.new()
    part.name = "Art_" + str(entry["name"])
    part.texture = tex
    part.centered = true
    part.scale = Vector2.ONE * ART_TO_WORLD
    part.z_index = int(entry["z_index"])
    var size: Vector2 = Vector2(float(entry["canvas_px"][0]), float(entry["canvas_px"][1]))
    var pivot: Vector2 = Vector2(float(entry["pivot_px"][0]), float(entry["pivot_px"][1]))
    # scale=1/4 converts source-pixel offset to native character-world pixels.
    # The sprite has a *fixed canvas*, no bounding-box crop or per-part
    # autoranging, so pivots remain identical across all three motions.
    part.position = (size * 0.5 - pivot) * ART_TO_WORLD
    bone.add_child(part)
    return part


static func _make_mesh(entry: Dictionary, tex: ImageTexture, rig: Skeleton2D) -> Polygon2D:
    var part := Polygon2D.new()
    part.name = "Art_" + str(entry["name"])
    part.texture = tex
    part.skeleton = NodePath("..")
    part.z_index = int(entry["z_index"])
    var size := Vector2(float(entry["canvas_px"][0]), float(entry["canvas_px"][1]))
    var pivot := Vector2(float(entry["pivot_px"][0]), float(entry["pivot_px"][1]))
    var p: Vector2 = -pivot * ART_TO_WORLD
    var w := size.x * ART_TO_WORLD
    var h := size.y * ART_TO_WORLD
    part.polygon = PackedVector2Array([
        p, p+Vector2(w,0), p+Vector2(w,h*0.5),
        p+Vector2(w,h), p+Vector2(0,h), p+Vector2(0,h*0.5),
    ])
    part.uv = PackedVector2Array([
        Vector2.ZERO, Vector2(size.x,0), Vector2(size.x,size.y*0.5),
        size, Vector2(0,size.y), Vector2(0,size.y*0.5)
    ])
    var group: String = str(entry["rig_group"])
    var base := NodePath("HairRoot" if group=="hair" else "CoatRoot")
    var tip: NodePath
    if group == "hair":
        tip = NodePath("HairRoot/HairMid/HairTip")
    elif str(entry["name"]) == "coat_front":
        tip = NodePath("CoatRoot/CoatFrontMid/CoatFrontTip")
    elif str(entry["name"]) == "coat_back":
        tip = NodePath("CoatRoot/CoatBackMid/CoatBackTip")
    else:
        tip = NodePath("CoatRoot/CoatInnerMid/CoatInnerTip")
    part.add_bone(base,PackedFloat32Array([1,1,0.65,0,0,0.65]))
    part.add_bone(tip,PackedFloat32Array([0,0,0.35,1,1,0.35]))
    rig.add_child(part)
    return part


static func bind_parts(scene: Node2D, core: Dictionary, ornaments: Dictionary,
        sockets: Dictionary, ornament_rigs: Dictionary) -> Dictionary:
    var manifest_path := CANDIDATE_DIR + "candidate-manifest.json"
    if not FileAccess.file_exists(manifest_path):
        push_error("SHEN_CUTOUT_BIND: missing candidate manifest; run Python generator first")
        return {"count":0,"missing":["candidate-manifest.json"],"by_group":{}}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not data is Dictionary:
        push_error("SHEN_CUTOUT_BIND: candidate manifest invalid")
        return {"count":0,"missing":["invalid JSON"],"by_group":{}}
    var missing: Array = []
    var kinds := {}
    var count := 0
    for item in data["parts"]:
        var entry: Dictionary = item
        var name := str(entry["name"])
        var group := str(entry["rig_group"])
        var image_path := CANDIDATE_DIR + name + ".png"
        var tex := _load_image(image_path)
        if tex == null:
            missing.append(name)
            continue
        var expected_size := Vector2i(int(entry["canvas_px"][0]), int(entry["canvas_px"][1]))
        if tex.get_size() != expected_size:
            missing.append(name + ":canvas")
            continue
        if group == "hair" or group == "coat":
            var rig: Skeleton2D = ornament_rigs.get(group)
            if rig == null:
                missing.append(name + ":ornament")
                continue
            _make_mesh(entry,tex,rig)
        else:
            var bone: Node2D = sockets.get("SwordGrip",null) if name=="sword" else core.get(str(entry["attach_to_bone"]),null)
            if bone == null:
                missing.append(name + ":bone")
                continue
            _make_sprite(entry,tex,bone)
        count += 1
        kinds[group] = int(kinds.get(group,0)) + 1
    return {"count":count,"missing":missing,"by_group":kinds,"status":"candidate"}
