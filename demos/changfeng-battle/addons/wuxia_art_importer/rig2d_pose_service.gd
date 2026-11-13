@tool
extends RefCounted
## Offline pose_templates -> editable Godot Skeleton2D + AnimationPlayer candidate.
## JSON is only an import source; the saved .tscn is the editing authority.

const COCO_INDEX := {"right_shoulder": 2, "right_elbow": 3, "right_wrist": 4,
    "left_shoulder": 5, "left_elbow": 6, "left_wrist": 7,
    "right_hip": 8, "right_knee": 9, "right_ankle": 10,
    "left_hip": 11, "left_knee": 12, "left_ankle": 13}


static func _json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"error": "无法读取 " + path}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {"error": "JSON 格式不正确：" + path}
    return parsed


static func read_project(path: String) -> Dictionary:
    var project := _json(path)
    if project.has("error"):
        return project
    if not project.has("parts") or not project.has("actions") or not project.has("motion_dir"):
        return {"error": "工程缺少 parts / actions / motion_dir"}
    var directory := path.get_base_dir()
    var manifest := _json(directory.path_join(str(project["parts"])))
    if manifest.has("error"):
        return manifest
    var parts := {}
    var textures := {}
    for entry in manifest.get("parts", []):
        var part: Dictionary = entry
        var name := str(part.get("name", ""))
        var rel := str(part.get("texture", ""))
        if name.is_empty() or rel.is_empty() or parts.has(name):
            return {"error": "重复或空部件/贴图：" + name}
        var source := directory.path_join(rel).simplify_path()
        if not FileAccess.file_exists(source):
            return {"error": "缺失 PNG：" + source}
        if not textures.has(rel):
            var image := Image.new()
            var result := image.load(source)
            if result != OK:
                return {"error": "无法解码 PNG：" + source}
            textures[rel] = ImageTexture.create_from_image(image)
        parts[name] = part
    for required in ["torso", "head", "sword", "left_upper_arm", "left_forearm", "left_hand"]:
        if not parts.has(required):
            return {"error": "缺少基础骨骼：" + required}
    var motions := {}
    for action in project["actions"]:
        var name := str(action)
        var motion := _json(directory.path_join(str(project["motion_dir"]))
            .path_join(name).path_join("motion.json"))
        if motion.has("error"):
            return motion
        if not motion.has("frames") or (motion["frames"] as Array).is_empty():
            return {"error": name + " 不含动作帧"}
        motions[name] = motion
    return {"error": "", "directory": directory, "project": project, "manifest": manifest,
        "parts": parts, "textures": textures, "motions": motions, "project_path": path}


static func vec(value: Variant) -> Vector2:
    return Vector2(float(value[0]), float(value[1]))


static func point(part: Dictionary, transform: Dictionary, source: Variant) -> Vector2:
    var axis := vec(part["axis"]) - vec(part["pivot"])
    var scale := float(part["length_px"]) / axis.length()
    return transform["origin"] + ((vec(source) - vec(part["pivot"])) * scale).rotated(transform["angle"])


static func directed(part: Dictionary, root: Vector2, angle: float) -> Dictionary:
    var axis := vec(part["axis"]) - vec(part["pivot"])
    return {"origin": root, "angle": angle - axis.angle()}


static func port(part: Dictionary, transform: Dictionary, name: String) -> Vector2:
    return point(part, transform, part["ports"][name])


static func solve_chain(root: Vector2, target: Vector2, authored: Vector2,
        first: float, second: float, fallback: int) -> Dictionary:
    var delta := target - root
    var direction := delta.normalized() if delta.length() > 0.0001 else Vector2.RIGHT
    var epsilon := minf(0.1, minf(first, second) * 0.25)
    var reach := clampf(delta.length(), absf(first - second) + epsilon, first + second - epsilon)
    var endpoint := root + direction * reach
    var along := (reach * reach + first * first - second * second) / (2.0 * reach)
    var across := sqrt(maxf(0.0, first * first - along * along))
    var normal := Vector2(-direction.y, direction.x)
    var offset := (authored - root).dot(normal)
    var bend := fallback if absf(offset) <= 1.0 else (1 if offset > 0.0 else -1)
    return {"middle": root + along * direction + float(bend) * across * normal,
        "endpoint": endpoint}


static func _angle_delta(a: float, b: float) -> float:
    return wrapf(a - b, -PI, PI)


static func _attach(parts: Dictionary, result: Dictionary, part_name: String,
        root: Vector2, heading: float) -> void:
    result[part_name] = directed(parts[part_name], root, heading)


static func solve_pose(rig: Dictionary, frame: Dictionary) -> Dictionary:
    var parts: Dictionary = rig["parts"]
    var art: Dictionary = rig["manifest"]
    var joints: Dictionary = {}
    for name in frame["authored_keypoints_coco18"]:
        joints[name] = vec(frame["authored_keypoints_coco18"][name])
    var hips := vec(frame.get("rig_pelvis_px", ((joints["left_hip"] + joints["right_hip"]) * 0.5)))
    var lean := deg_to_rad(float(frame.get("rig_torso_lean_degrees", 0.0)))
    var result := {"torso": {"origin": hips, "angle": lean}}
    var torso: Dictionary = result["torso"]
    var head_mount := port(parts["torso"], torso, "head")
    result["head"] = {"origin": head_mount,
        "angle": lean + deg_to_rad(float(frame.get("rig_head_counter_degrees", 0.0)))}
    var feet_center: Vector2 = (joints["left_ankle"] + joints["right_ankle"]) * 0.5
    var cloth_sway := clampf((feet_center.x - hips.x) * 0.003, -0.06, 0.06)
    var secondary: Dictionary = frame.get("rig_secondary_degrees", {})
    var hem_follow := float(frame.get("rig_hem_follow_torso", 0.0))
    var hem_heading: Dictionary = frame.get("rig_secondary_heading_degrees", {})
    for entry in art.get("accessories", []):
        var name := str(entry["part"])
        var parent := str(entry.get("parent", "torso"))
        var gain := float(entry.get("lean_gain", 1.0))
        if name in ["front_hem", "back_hem"]:
            gain += (1.0 - gain) * hem_follow
        var heading := lean * gain + cloth_sway * float(entry.get("sway_gain", 0.0)) \
            + deg_to_rad(float(secondary.get(name, 0.0)))
        if hem_heading.has(name):
            heading = deg_to_rad(float(hem_heading[name]))
        result[name] = {"origin": port(parts[parent], result[parent], str(entry["port"])),
            "angle": heading}
    for side in PackedStringArray(["left", "right"]):
        var foot_name := side + "_foot"
        var foot_data: Dictionary = frame["support_foot_geometry"][side]
        var heel := vec(foot_data["heel"])
        var toe := vec(foot_data["toe"])
        var foot: Dictionary = directed(parts[foot_name], heel, (toe - heel).angle())
        var tip_info: Dictionary = art.get("toe_overlays", {}).get(side, {})
        var tip: Dictionary = {}
        if not tip_info.is_empty():
            var tip_name := str(tip_info["part"])
            var flex := deg_to_rad(float(frame.get("rig_toe_flex_degrees", {}).get(side, 0)))
            tip = {"origin": point(parts[foot_name], foot, parts[tip_name]["pivot"]),
                "angle": float(foot["angle"]) + flex}
            if str(foot_data.get("contact", "")) == "toe":
                var shift: Vector2 = toe - point(parts[tip_name], tip, parts[tip_name]["axis"])
                foot["origin"] += shift
                tip["origin"] += shift
        var ankle_goal := port(parts[foot_name], foot, "ankle")
        var hip := port(parts["torso"], torso, side + "_hip")
        var thigh: Dictionary = parts[side + "_thigh"]
        var shin: Dictionary = parts[side + "_shin"]
        var fit := solve_chain(hip, ankle_goal, joints[side + "_knee"],
            float(thigh["length_px"]), float(shin["length_px"]), int(art["bend"][side + "_leg"]))
        var knee: Vector2 = fit["middle"]
        var ankle: Vector2 = fit["endpoint"]
        var correction := ankle - ankle_goal
        _attach(parts, result, side + "_thigh", hip, (knee - hip).angle())
        _attach(parts, result, side + "_shin", knee, (ankle - knee).angle())
        foot["origin"] += correction
        result[foot_name] = foot
        if not tip.is_empty():
            tip["origin"] += correction
            result[str(tip_info["part"])] = tip
        var shaft_info: Dictionary = art.get("ankle_overlays", {}).get(side, {})
        if not shaft_info.is_empty():
            _attach(parts, result, str(shaft_info["part"]), ankle, (knee - ankle).angle())
    var weapon: Dictionary = frame["weapon_geometry"]
    var grip := vec(weapon["grip"])
    var tip := vec(weapon["tip"])
    var sword_angle := (tip - grip).angle()
    for side in PackedStringArray(["left", "right"]):
        var shoulder := port(parts["torso"], torso, side + "_shoulder")
        var shoulder_offset: Dictionary = frame.get("rig_shoulder_offset_px", {})
        shoulder += vec(shoulder_offset.get(side, [0, 0])).rotated(lean)
        var upper: Dictionary = parts[side + "_upper_arm"]
        var fore: Dictionary = parts[side + "_forearm"]
        var hand: Dictionary = parts[side + "_hand"]
        var requested: Vector2 = joints[side + "_wrist"]
        var hand_angle := 0.0
        if side == "right":
            hand_angle = sword_angle + deg_to_rad(float(art["sword_hand_axis_offset_degrees"])) \
                + deg_to_rad(float(frame.get("rig_right_hand_offset_degrees", 0.0)))
            requested = grip - Vector2.RIGHT.rotated(hand_angle) * float(hand["length_px"])
        var fit := solve_chain(shoulder, requested, joints[side + "_elbow"],
            float(upper["length_px"]), float(fore["length_px"]), int(art["bend"][side + "_arm"]))
        var elbow: Vector2 = fit["middle"]
        var wrist: Vector2 = fit["endpoint"]
        var upper_angle := (elbow - shoulder).angle()
        var fore_angle := (wrist - elbow).angle()
        _attach(parts, result, side + "_upper_arm", shoulder, upper_angle)
        _attach(parts, result, side + "_forearm", elbow, fore_angle)
        var over: Dictionary = art.get("shoulder_overlaps", {}).get(side, {})
        if not over.is_empty():
            var layer: Dictionary = parts[over["part"]]
            var rest := (vec(layer["axis"]) - vec(layer["pivot"])).angle() + lean
            _attach(parts, result, str(over["part"]), port(parts["torso"], torso, side + "_shoulder"),
                rest + float(over["arm_weight"]) * _angle_delta(upper_angle, rest))
        var cuff: Dictionary = art.get("elbow_cuffs", {}).get(side, {})
        if not cuff.is_empty():
            var heading := fore_angle + (1.0 - float(cuff["forearm_weight"])) \
                * _angle_delta(upper_angle, fore_angle)
            _attach(parts, result, str(cuff["part"]), elbow, heading)
        if side == "left":
            hand_angle = fore_angle
            if frame.has("rig_left_hand_angle_degrees"):
                var target := deg_to_rad(float(frame["rig_left_hand_angle_degrees"]))
                hand_angle += clampf(_angle_delta(target, fore_angle), -deg_to_rad(35), deg_to_rad(35))
        _attach(parts, result, side + "_hand", wrist, hand_angle)
        if side == "right":
            _attach(parts, result, "sword", point(hand, result["right_hand"], hand["axis"]), sword_angle)
        joints[side + "_shoulder"] = shoulder
        joints[side + "_elbow"] = elbow
        joints[side + "_wrist"] = wrist
    var tassel: Dictionary = art.get("sword_tassel", {})
    if not tassel.is_empty():
        var sword: Dictionary = parts["sword"]
        var heading := PI / 2.0 + deg_to_rad(float(frame.get("rig_tassel_sway_degrees", 0.0)))
        _attach(parts, result, str(tassel["part"]), port(sword, result["sword"], str(tassel["sword_port"])), heading)
    return {"placements": result, "joints": joints}


static func update_left_joint(rig: Dictionary, action: String, index: int,
        joint_name: String, position: Vector2) -> void:
    var frame: Dictionary = rig["motions"][action]["frames"][index]
    var pose := solve_pose(rig, frame)
    var points: Dictionary = frame["authored_keypoints_coco18"]
    if joint_name == "left_elbow":
        var shoulder: Vector2 = pose["joints"]["left_shoulder"]
        var old_elbow: Vector2 = pose["joints"]["left_elbow"]
        var old_wrist: Vector2 = pose["joints"]["left_wrist"]
        var first := float(rig["parts"]["left_upper_arm"]["length_px"])
        var second := float(rig["parts"]["left_forearm"]["length_px"])
        var elbow := shoulder + (position - shoulder).normalized() * first
        var fore := (old_wrist - old_elbow).normalized()
        position = elbow
        var wrist := elbow + fore * second
        points["left_wrist"] = [wrist.x, wrist.y]
        frame["pose_keypoints"][int(COCO_INDEX["left_wrist"])] = [wrist.x, wrist.y]
    points[joint_name] = [position.x, position.y]
    frame["pose_keypoints"][int(COCO_INDEX[joint_name])] = [position.x, position.y]


static func _image_dest(output: String, relative: String) -> String:
    return output.path_join("textures").path_join(relative)


static func save_native_candidate(rig: Dictionary, target: String) -> Dictionary:
    if not target.begins_with("res://") or not target.ends_with(".tscn"):
        return {"error": "目标必须是 res:// 下的新 .tscn 文件"}
    if FileAccess.file_exists(target):
        return {"error": "目标场景已存在，停止以保护手工编辑：" + target}
    var output := target.get_base_dir()
    var parts: Dictionary = rig["parts"]
    var saved_paths := {}
    # PNGs are candidates under the selected output directory, never bound to
    # WuxiaCharacterDefinition or content_manifest by the importer.
    for name in parts:
        var rel := str(parts[name]["texture"])
        if saved_paths.has(rel):
            continue
        var dest := _image_dest(output, rel)
        if FileAccess.file_exists(dest):
            if FileAccess.get_sha256(dest) != FileAccess.get_sha256(rig["directory"].path_join(rel)):
                return {"error": "贴图已被单独修改，停止覆盖：" + dest}
        saved_paths[rel] = dest
    for relative in saved_paths:
        var to_path: String = saved_paths[relative]
        var absolute := ProjectSettings.globalize_path(to_path)
        var result := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
        if result != OK:
            return {"error": "无法创建候选文件夹：" + to_path}
        if not FileAccess.file_exists(to_path):
            result = DirAccess.copy_absolute(rig["directory"].path_join(relative), absolute)
            if result != OK:
                return {"error": "无法复制 PNG：" + relative}
    # Refer to imported PNG resources. Never embed 31MB of ImageTexture pixel
    # data into the .tscn: that would make native editing and diffing painful.
    var imported_textures := {}
    for relative in saved_paths:
        var loaded := ResourceLoader.load(str(saved_paths[relative]), "Texture2D") as Texture2D
        if loaded == null:
            return {"error": "PNG 已复制；请等待 Godot 导入贴图后重试生成。", "pending_import": true}
        imported_textures[relative] = loaded
    var root := Node2D.new()
    root.name = target.get_file().get_basename()
    var skeleton := Skeleton2D.new()
    skeleton.name = "Skeleton2D"
    root.add_child(skeleton)
    skeleton.owner = root
    var first_action := str(rig["project"]["actions"].keys()[0])
    var first_frame: Dictionary = rig["motions"][first_action]["frames"][0]
    skeleton.position = -vec(first_frame.get("logical_origin", [171, 256]))
    var initial: Dictionary = solve_pose(rig, first_frame)["placements"]
    for name in parts:
        var part: Dictionary = parts[name]
        var bone := Bone2D.new()
        bone.name = str(name)
        bone.set_autocalculate_length_and_angle(false)
        bone.set_bone_angle((vec(part["axis"]) - vec(part["pivot"])).angle())
        bone.length = float(part["length_px"])
        skeleton.add_child(bone)
        bone.owner = root
        var transform: Dictionary = initial[name]
        bone.position = transform["origin"]
        bone.rotation = float(transform["angle"])
        bone.rest = bone.transform
        var polygon := Polygon2D.new()
        polygon.name = "Art"
        polygon.z_as_relative = false
        polygon.z_index = int(part["depth"])
        var source: Array = part.get("polygon", [])
        var texture: Texture2D = imported_textures[str(part["texture"])]
        if source.is_empty():
            var dimensions := texture.get_size()
            source = [[0, 0], [dimensions.x, 0], [dimensions.x, dimensions.y], [0, dimensions.y]]
        var points := PackedVector2Array()
        var uvs := PackedVector2Array()
        var factor := float(part["length_px"]) / (vec(part["axis"]) - vec(part["pivot"])).length()
        for item in source:
            var uv := vec(item)
            uvs.append(uv)
            points.append((uv - vec(part["pivot"])) * factor)
        polygon.polygon = points
        polygon.uv = uvs
        polygon.texture = texture
        bone.add_child(polygon)
        polygon.owner = root
    var player := AnimationPlayer.new()
    player.name = "AnimationPlayer"
    root.add_child(player)
    player.owner = root
    player.root_node = NodePath("..")
    var library := AnimationLibrary.new()
    for action in rig["project"]["actions"]:
        var motion: Dictionary = rig["motions"][action]
        var animation := Animation.new()
        animation.length = maxf(0.001, float(motion["duration_ms"]) / 1000.0)
        animation.loop_mode = Animation.LOOP_LINEAR if bool(motion.get("loop", false)) else Animation.LOOP_NONE
        var tracks := {}
        for name in parts:
            var bone_path := "Skeleton2D/" + str(name)
            var position_track := animation.add_track(Animation.TYPE_VALUE)
            animation.track_set_path(position_track, NodePath(bone_path + ":position"))
            animation.value_track_set_update_mode(position_track, Animation.UPDATE_DISCRETE)
            var angle_track := animation.add_track(Animation.TYPE_VALUE)
            animation.track_set_path(angle_track, NodePath(bone_path + ":rotation"))
            animation.value_track_set_update_mode(angle_track, Animation.UPDATE_DISCRETE)
            tracks[name] = [position_track, angle_track]
        for frame in motion["frames"]:
            var placements: Dictionary = solve_pose(rig, frame)["placements"]
            var time := float(frame["time_ms"]) / 1000.0
            for name in parts:
                var pose: Dictionary = placements[name]
                animation.track_insert_key(tracks[name][0], time, pose["origin"])
                animation.track_insert_key(tracks[name][1], time, pose["angle"])
        library.add_animation(str(action), animation)
    player.add_animation_library("", library)
    player.autoplay = first_action
    var packed := PackedScene.new()
    var packed_error := packed.pack(root)
    if packed_error == OK:
        packed_error = ResourceSaver.save(packed, target)
    root.free()
    if packed_error != OK:
        return {"error": "原生场景保存失败：" + error_string(packed_error)}
    return {"error": "", "scene": target, "textures": saved_paths.size(),
        "actions": library.get_animation_list().size()}
