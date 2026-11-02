extends SceneTree
## Retargeting acceptance: overlay the NEW universal humanoid joint chains
## directly over EXISTING Shen V3 sprite parts at the identical 200px footpoint.
## Existing sprite parts are not modified or "repaired" for the comparison.

const OLD_SCENE := preload("res://prototypes/shen_bone2d_v3/shen_bone2d_v3_validation.tscn")
const CORE_SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const OUTPUT := "res://captures/shen-rig-first/old-asset-compatibility/"
const CROP := Rect2i(585, 468, 440, 300)

var old_actor: Node2D
var new_core: Node2D
var old_player: AnimationPlayer
var new_player: AnimationPlayer
var bones: Dictionary = {}
var lines: Dictionary = {}
var points: Dictionary = {}
var overlay: Node2D


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Retargeting visual capture requires xvfb graphical display")
        quit(1)
        return
    root.size = Vector2i(1600, 1000)
    old_actor = OLD_SCENE.instantiate()
    root.add_child(old_actor)
    new_core = CORE_SCENE.instantiate()
    new_core.enable_hair = false
    new_core.enable_coat = false
    root.add_child(new_core)
    new_core.visible = false  # Geometry remains alive; preview backdrop is hidden.
    old_player = old_actor.get_node("AnimationPlayer") as AnimationPlayer
    new_player = new_core.get_node("AnimationPlayer") as AnimationPlayer
    _find_bones(new_core.get_node("Skeleton2D"))
    overlay = Node2D.new()
    overlay.name = "NewHumanoidOverlay"
    overlay.z_index = 99
    old_actor.add_child(overlay)
    _build_overlay()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    await process_frame

    # Compare actual old sprite rest positions to NEW 22-bone retargeting joints.
    old_actor.call("_play", "idle")
    old_player.stop()
    old_actor.call("debug_show_bind_pose", false)
    new_core.show_bind_pose()
    _update_overlay()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _capture(OUTPUT.path_join("bind-with-new-core.png")):
        quit(1)
        return

    for action in ["idle", "walk", "attack_sword"]:
        var dir := OUTPUT.path_join(action)
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
        var clip: Animation = new_player.get_animation(action)
        for i in range(8):
            var ratio := float(i) / float(7 if action == "attack_sword" else 8)
            old_actor.call("_play", action)
            new_core.play_motion(action)
            old_player.seek(old_player.get_animation(action).length * ratio, true)
            new_player.seek(clip.length * ratio, true)
            old_player.pause()
            new_player.pause()
            _update_overlay()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _capture(dir.path_join("frame-%02d.png" % i)):
                quit(1)
                return
    print("SHEN_OLD_ASSET_RETARGET_VISUAL_OK")
    quit(0)


func _find_bones(node: Node) -> void:
    for child in node.get_children():
        if child is Bone2D:
            bones[child.name] = child
            _find_bones(child)


func _build_overlay() -> void:
    for name in bones.keys():
        var bone: Bone2D = bones[name]
        var parent := bone.get_parent() as Bone2D
        if parent == null:
            continue
        var line := Line2D.new()
        line.name = str(name) + "Link"
        line.width = 1.7
        line.default_color = Color(0.07, 0.94, 1.0, 0.98)
        line.add_point(Vector2.ZERO)
        line.add_point(Vector2.ZERO)
        overlay.add_child(line)
        lines[name] = line
        var marker := Line2D.new()
        marker.name = str(name) + "Marker"
        marker.width = 1.5
        marker.default_color = Color(1.0, 0.78, 0.1, 1.0)
        marker.closed = true
        for j in range(8):
            var theta := TAU * float(j) / 8.0
            marker.add_point(Vector2(cos(theta), sin(theta)) * 3.2)
        overlay.add_child(marker)
        points[name] = marker


func _update_overlay() -> void:
    for name in lines:
        var bone: Bone2D = bones[name]
        var parent := bone.get_parent() as Bone2D
        var line: Line2D = lines[name]
        line.set_point_position(0, overlay.to_local(parent.global_position))
        line.set_point_position(1, overlay.to_local(bone.global_position))
        var marker: Line2D = points[name]
        marker.position = overlay.to_local(bone.global_position)


func _capture(path: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Retargeting snapshot is empty")
        return false
    image = image.get_region(CROP)
    var err := image.save_png(path)
    if err != OK:
        push_error("Retargeting snapshot write failed: " + path)
    return err == OK
