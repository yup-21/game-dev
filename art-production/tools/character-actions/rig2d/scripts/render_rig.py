"""Render a calibrated modular profile rig to native transparent PNGs in Blender."""

import argparse
from array import array
from hashlib import sha256
import json
import math
from pathlib import Path
import re
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

sys.path.insert(0, str(Path(__file__).resolve().parent))
from modular_rig import load_manifest, solve_frame

def world(p, depth):
    return (p.x / 100, -p.y / 100, depth)


def mesh_from_texture(name, coordinates, image_size, material, transforms, timeline, wrap_frame, depth,
                      bend_angles=None, tip_offsets=None):
    source = [Vector(xy) for xy in coordinates]
    if bend_angles is not None:
        # Soft accessories use a subdivided rectangle so Blender can bend
        # cloth/hair pixels while retaining their original texture UVs.
        if len(source) != 4 or len({p.x for p in source}) != 2 or len({p.y for p in source}) != 2:
            raise ValueError(f"{name}: soft deformation requires a rectangular UV polygon")
        x0, x1 = min(p.x for p in source), max(p.x for p in source)
        y0, y1 = min(p.y for p in source), max(p.y for p in source)
        cols, rows = 5, 12
        source = [Vector((x0 + (x1 - x0) * c / cols,
                          y0 + (y1 - y0) * r / rows))
                  for r in range(rows + 1) for c in range(cols + 1)]
        faces = []
        for r in range(rows):
            for c in range(cols):
                a = r * (cols + 1) + c
                faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    else:
        tess_input = [Vector((p.x, p.y, 0)) for p in source]
        faces = tessellate_polygon([tess_input])
    part = transforms[0].part
    assert all(t.part is part for t in transforms)
    pivot, scale = part.pivot, part.scale
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([world((p - pivot) * scale, 0) for p in source], [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new()
    for face in mesh.polygons:
        for index in face.loop_indices:
            p = source[mesh.loops[index].vertex_index]
            uv_layer.data[index].uv = (p.x / image_size[0], 1 - p.y / image_size[1])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    if tip_offsets is not None:
        obj.shape_key_add(name="Undeformed")
        blocks = []
        for index, tip_px in enumerate(tip_offsets):
            key = obj.shape_key_add(name=f"Soft pose {index:03d}")
            for vertex, source_xy in zip(key.data, source):
                progress = max(0, min(1, (source_xy.y - y0) / max(1, y1 - y0)))
                vertex.co.x += (tip_px * progress * progress) / 100.0
            blocks.append(key)
        for i, time in enumerate(timeline):
            for j, key in enumerate(blocks):
                key.value = 1.0 if i == j else 0.0
                key.keyframe_insert(data_path="value", frame=time)
        if wrap_frame is not None:
            for j, key in enumerate(blocks):
                key.value = 1.0 if j == 0 else 0.0
                key.keyframe_insert(data_path="value", frame=wrap_frame)
        keys_animation = obj.data.shape_keys.animation_data
        if keys_animation is not None and keys_animation.action is not None:
            shape_action = keys_animation.action
            if hasattr(shape_action, "layers"):
                shape_curves = (curve for layer in shape_action.layers for strip in layer.strips
                                for bag in strip.channelbags for curve in bag.fcurves)
            else:
                shape_curves = iter(shape_action.fcurves)
            for curve in shape_curves:
                for key in curve.keyframe_points:
                    key.interpolation = "LINEAR"
    if bend_angles is not None:
        modifier = obj.modifiers.new("Secondary cloth bend", "SIMPLE_DEFORM")
        modifier.deform_method = "BEND"
        modifier.deform_axis = "Y"
        origin = bpy.data.objects.new(name + " bend anchor", None)
        bpy.context.collection.objects.link(origin)
        origin.parent = obj
        origin.location = (0.0, 0.0, 0.0)
        modifier.origin = origin
        bend_keys = list(zip(timeline, bend_angles))
        if wrap_frame is not None:
            bend_keys.append((wrap_frame, bend_angles[0]))
        for time, degrees in bend_keys:
            modifier.angle = math.radians(degrees)
            modifier.keyframe_insert(data_path="angle", frame=time)
    keys = list(zip(timeline, transforms))
    if wrap_frame is not None:
        keys.append((wrap_frame, transforms[0]))
    previous_angle = -transforms[0].radians
    for time, transform in keys:
        target_angle = -transform.radians
        delta = (target_angle - previous_angle + math.pi) % (2 * math.pi) - math.pi
        previous_angle += delta
        obj.location = world(transform.target, depth)
        obj.rotation_euler.z = previous_angle
        obj.keyframe_insert("location", frame=time)
        obj.keyframe_insert("rotation_euler", frame=time)
    animation = obj.animation_data
    action = animation.action
    if hasattr(action, "layers"):
        curves = (curve for layer in action.layers
                  for strip in layer.strips
                  for channelbag in strip.channelbags
                  for curve in channelbag.fcurves)
    else:
        curves = iter(action.fcurves)
    for curve in curves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"


def alpha_material(path):
    image = bpy.data.images.load(str(path.resolve()), check_existing=True)
    if image.channels != 4:
        raise ValueError(f"{path} has no RGBA channel")
    pixels = array("f", [0]) * len(image.pixels)
    image.pixels.foreach_get(pixels)
    alpha = pixels[3::4]
    if min(alpha) > 0.01 or max(alpha) < 0.5:
        raise ValueError(f"{path} does not contain real transparent and visible pixels")
    image.pack()
    material = bpy.data.materials.new(f"Profile texture {path.name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "CLIP"
    emission = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(texture.outputs["Color"], emission.inputs["Color"])
    links.new(texture.outputs["Alpha"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    return image, material


def part_boundary(part, size):
    w, h = size
    vertices = part.polygon or tuple(Vector(p) for p in ((0, 0), (w, 0), (w, h), (0, h)))
    for value in (part.pivot, part.axis, *part.ports.values(), *vertices):
        if not 0 <= value.x <= w or not 0 <= value.y <= h:
            raise ValueError(f"{part.name} has an anchor or polygon point outside its texture: {value}")
    return vertices


def grip_velocity_x(frames, index, loop, duration_ms):
    if len(frames) < 2 or (not loop and index in (0, len(frames) - 1)):
        # One-shot actions begin and end with a settled weapon accessory.
        return 0.0
    before = frames[(index - 1) % len(frames)]
    after = frames[(index + 1) % len(frames)]
    elapsed = after["time_ms"] - before["time_ms"]
    if elapsed <= 0:
        elapsed += duration_ms
    return (after["weapon_geometry"]["grip"][0] - before["weapon_geometry"]["grip"][0]) / elapsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parts", type=Path, required=True)
    parser.add_argument("--motion", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--character-id", default="gu_qingshuang")
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    if not args.check_only and args.output is None:
        parser.error("--output is required when rendering")
    if not re.fullmatch(r"[a-z][a-z0-9_]*", args.character_id):
        parser.error("Invalid character ID")
    parts_digest = sha256(args.parts.read_bytes()).hexdigest()
    motion_bytes = args.motion.read_bytes()
    motion_digest = sha256(motion_bytes).hexdigest()
    art, parts = load_manifest(args.parts)
    motion = json.loads(motion_bytes)
    frames = motion["frames"]
    action = motion["action_id"]
    if not re.fullmatch(r"[a-z][a-z0-9_]*", action):
        raise ValueError(f"Invalid action ID: {action!r}")
    width, height = motion["canvas"]
    origin = motion["logical_origin"]
    if [width, height] not in ([328, 256], [384, 288]) or len(origin) != 2 or not all(
            type(v) is int and 0 <= v < bound for v, bound in zip(origin, (width, height))):
        raise ValueError("Use a supported canvas and a fixed integer origin inside it")
    assert len(frames) == motion["frame_count"] and frames
    elapsed = 0
    for frame in frames:
        assert frame["time_ms"] == elapsed and frame["duration_ms"] > 0
        elapsed += frame["duration_ms"]
    assert elapsed == motion["duration_ms"]
    previous_bends = {}
    poses_and_diagnostics = [
        solve_frame(frame, art, parts, previous_bends,
                    grip_velocity_x(frames, i, motion["loop"], elapsed))
        for i, frame in enumerate(frames)
    ]
    if args.check_only:
        max_reach = max(
            value for _, info in poses_and_diagnostics for key, value in info.items()
            if key.endswith("reach_correction_px") or key == "sword_grip_error_px"
        )
        print("RIG_PREFLIGHT " + json.dumps({
            "action_id": action, "frames": len(frames), "parts": len(parts),
            "max_reach_correction_px": max_reach, "motion_sha256": motion_digest,
            "parts_manifest_sha256": parts_digest,
        }), flush=True)
        return
    args.output = args.output.resolve()
    tick_ms = math.gcd(1000, *(frame["duration_ms"] for frame in frames))
    # Retain a useful editing rate for the 80 ms walk and exact integer timestamps.
    tick_ms = math.gcd(tick_ms, 10)
    timeline = [1 + frame["time_ms"] // tick_ms for frame in frames]
    end_frame = elapsed // tick_ms
    wrap_frame = end_frame + 1 if motion["loop"] else None
    args.output.mkdir(parents=True, exist_ok=True)
    frames_dir = args.output / "frames"
    frames_dir.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    # Flat emissive textures need no denoiser; minimal Blender builds may omit OIDN.
    scene.cycles.use_denoising = False
    bpy.context.view_layer.cycles.use_denoising = False
    scene.cycles.transparent_max_bounces = 32
    scene.render.resolution_x, scene.render.resolution_y = motion["canvas"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.fps = 1000 // tick_ms
    scene.frame_start, scene.frame_end = 1, end_frame
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    transforms = [item[0] for item in poses_and_diagnostics]
    materials = {}
    soft = set(art.get("soft_deformation", []))
    for part in parts.values():
        if part.texture not in materials:
            materials[part.texture] = alpha_material(part.texture)
        image, material = materials[part.texture]
        angles = ([frame.get("rig_soft_bend_degrees", {}).get(part.name, 0.0)
                   for frame in frames] if part.name in soft else None)
        tips = ([frame.get("rig_soft_tip_px", {}).get(part.name, 0.0)
                 for frame in frames] if part.name in soft else None)
        mesh_from_texture(part.name, part_boundary(part, image.size), image.size, material,
                          [t[part.name] for t in transforms], timeline, wrap_frame, part.depth / 100,
                          bend_angles=angles, tip_offsets=tips)

    camera = bpy.data.cameras.new("Fixed orthographic sprite camera")
    camera.type, camera.ortho_scale = "ORTHO", width / 100
    camera_object = bpy.data.objects.new(camera.name, camera)
    bpy.context.collection.objects.link(camera_object)
    camera_object.location = (width / 200, -height / 200, 10)
    scene.camera = camera_object
    scene["logical_origin_px"] = motion["logical_origin"]
    scene["source_generated_atlas_sha256"] = art["generated_atlas"]["sha256"]
    scene["source_motion_sha256"] = motion_digest
    scene["candidate_scope"] = "Rigid profile cutout with independent wrists, elbow cuffs and sword tassel."
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output / f"{args.character_id}_{action}.blend"))
    for index, time in enumerate(timeline):
        scene.frame_set(time)
        scene.render.filepath = str(frames_dir / f"{action}_{index:03d}.png")
        bpy.ops.render.render(write_still=True)
    if sha256(args.motion.read_bytes()).hexdigest() != motion_digest or sha256(args.parts.read_bytes()).hexdigest() != parts_digest:
        raise RuntimeError("Motion or parts manifest changed during rendering.")
    receipt = {
        "parts_manifest": str(args.parts.resolve()),
        "parts_manifest_sha256": parts_digest,
        "generated_atlas": art["generated_atlas"],
        "texture_sha256": {str(path): sha256(path.read_bytes()).hexdigest() for path in materials},
        "motion": str(args.motion.resolve()), "motion_sha256": scene["source_motion_sha256"],
        "canvas": motion["canvas"], "logical_origin": motion["logical_origin"], "action_id": action,
        "character_id": args.character_id,
        "blender_timeline_fps": scene.render.fps, "end_contract": motion["end_contract"],
        "render_engine": "Cycles CPU", "placement": "rigid uniform sprite transforms",
        "original_used_as_initial_frame": False,
        "status": "candidate", "duration_ms": motion["duration_ms"], "loop": motion["loop"],
        "frames": [
            {"file": f"frames/{action}_{i:03d}.png", "source_frame": frame["id"],
             "time_ms": frame["time_ms"], "duration_ms": frame["duration_ms"],
             "weapon_grip": poses_and_diagnostics[i][1]["rendered_sword_grip"],
             "weapon_tip": poses_and_diagnostics[i][1]["rendered_sword_tip"],
             "planned_weapon_grip": frame["weapon_geometry"]["grip"],
             "planned_weapon_tip": frame["weapon_geometry"]["tip"],
             "foot_contact_plan": frame["support_foot_geometry"], "diagnostics": poses_and_diagnostics[i][1]}
            for i, frame in enumerate(frames)
        ],
    }
    (args.output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
