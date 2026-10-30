extends RefCounted
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
## Original procedural wuxia diorama decorations. Visual only: no collisions or rules.
## Intentionally positioned outside the 15x10 tactical grid.
const LEAF_DARK = Color("294c3f")
const LEAF_LIGHT = Color("496b50")
const WOOD = Color("5b4536")
const STONE = Color("777b70")

static func _mat(color: Color, roughness: float = 0.95) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

static func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = mesh
    instance.material_override = _mat(color)
    instance.position = pos
    parent.add_child(instance)
    return instance

static func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
    var stem := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.72
    shape.bottom_radius = radius
    shape.height = height
    stem.mesh = shape
    stem.material_override = _mat(color)
    stem.position = pos
    parent.add_child(stem)

static func _pine(parent: Node3D, pos: Vector3, height: float, variant: int) -> void:
    _cylinder(parent, pos + Vector3(0, height * 0.31, 0), 0.15, height * 0.62, WOOD)
    # Layered soft foliage masses read as hand-painted shapes at oblique angles.
    for layer in range(3):
        var crown := MeshInstance3D.new()
        var leaves := SphereMesh.new()
        leaves.radius = height * (0.30 - float(layer) * 0.03)
        leaves.height = height * 0.36
        crown.mesh = leaves
        crown.material_override = _mat(LEAF_DARK if (variant + layer) % 2 else LEAF_LIGHT)
        crown.position = pos + Vector3(
            sin(float(variant) * 1.7 + float(layer)) * height * 0.055,
            height * (0.61 + float(layer) * 0.12),
            cos(float(variant) * 2.1 + float(layer)) * height * 0.05)
        crown.scale = Vector3(1.36, 1.0, 1.15)
        parent.add_child(crown)

static func _rock(parent: Node3D, pos: Vector3, size: float, variant: int) -> void:
    var stone := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = size
    mesh.height = size * 1.3
    stone.mesh = mesh
    stone.material_override = _mat(STONE.lightened(float(variant % 4) * 0.045))
    stone.position = pos
    stone.scale = Vector3(1.3, 0.54, 0.8)
    parent.add_child(stone)

static func _lantern(parent: Node3D, pos: Vector3) -> void:
    _cylinder(parent, pos + Vector3(0, 0.8, 0), 0.065, 1.6, WOOD)
    _box(parent, "LanternFrame", pos + Vector3(0, 1.66, 0), Vector3(0.35, 0.44, 0.35), Color("6f4c30"))
    var lamp := _box(parent, "LanternLight", pos + Vector3(0, 1.66, 0), Vector3(0.25, 0.33, 0.25), Color("f5cc7a"))
    var emissive := _mat(Color("f7cb80"))
    emissive.emission_enabled = true
    emissive.emission = Color("f8c16e")
    emissive.emission_energy_multiplier = 2.0
    lamp.material_override = emissive
    var light := OmniLight3D.new()
    light.light_color = Color("f4bb77")
    light.light_energy = 0.7
    light.omni_range = 4.0
    light.position = pos + Vector3(0, 1.66, 0)
    parent.add_child(light)

static func build(parent: Node3D, story_encounter: bool = false, camera: Camera3D = null) -> void:
    var scenery := Node3D.new()
    scenery.name = "WuxiaScenery"
    parent.add_child(scenery)
    # Match the distant illustration to the encounter: rainy bridge for story,
    # snowy sword-sect courtyard for the standalone training preview.
    var painting := ArtCatalog.scenery("rainy_bridge" if story_encounter else "snow")
    if painting != null:
        var backdrop := Sprite3D.new()
        backdrop.name = "IllustratedBackdrop"
        backdrop.texture = painting
        backdrop.pixel_size = 0.04
        # Keep the painting aligned with the camera and far behind the board.
        # A world-space plane gets lost above the horizon in this steep tactical view.
        backdrop.position = Vector3(0.0, 0.0, -100.0)
        backdrop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        backdrop.shaded = false
        backdrop.modulate = Color(0.92, 0.96, 1.0, 1.0)
        if camera != null:
            camera.add_child(backdrop)
        else:
            scenery.add_child(backdrop)
    # Layered forest silhouettes on both sides of the tactical area.
    for i in range(18):
        var z := -10.0 + float(i) * 1.19
        var offset := sin(float(i) * 2.41) * 1.8
        _pine(scenery, Vector3(-13.4 + offset, 0, z), 2.5 + float(i % 5) * 0.42, i)
        _pine(scenery, Vector3(13.1 - offset, 0, z + 0.6), 2.8 + float((i + 2) % 5) * 0.38, i + 1)
    for i in range(14):
        var z := -10.0 + float(i) * 1.5
        _rock(scenery, Vector3(-11.9 + sin(float(i)) * 0.5, 0.05, z), 0.35 + float(i % 3) * 0.12, i)
        _rock(scenery, Vector3(12.0 + cos(float(i)) * 0.4, 0.05, z + 0.25), 0.35 + float(i % 4) * 0.09, i + 2)
    # Wooden rails frame the central crossing without affecting logical passability.
    for z in [-1.0, 1.0]:
        for x in [-2.0, 2.0]:
            _box(scenery, "BridgePost", Vector3(x, 0.48, z), Vector3(0.18, 0.96, 0.18), WOOD)
        _box(scenery, "BridgeRail", Vector3(0, 0.75, z), Vector3(4.2, 0.12, 0.14), Color("72543a"))
    _lantern(scenery, Vector3(-3.3, 0, -1.7))
    _lantern(scenery, Vector3(3.3, 0, 1.7))
    # Overlapping rounded mountains avoid the old hard cuboid skyline.
    for i in range(9):
        var ridge := MeshInstance3D.new()
        var ridge_shape := SphereMesh.new()
        ridge_shape.radius = 2.8
        ridge_shape.height = 2.9
        ridge.mesh = ridge_shape
        ridge.material_override = _mat(Color("53685c").darkened(float(i % 3) * 0.08))
        ridge.position = Vector3(-17.0 + float(i) * 4.3,
            0.1 + float((i * 7) % 4) * 0.28, -19.0)
        ridge.scale = Vector3(1.55, 0.96 + float(i % 3) * 0.20, 1.1)
        scenery.add_child(ridge)
