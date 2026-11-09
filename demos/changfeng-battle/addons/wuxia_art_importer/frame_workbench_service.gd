@tool
extends RefCounted
## Editor-only, source-format-independent frame preparation. Runtime truth remains SpriteFrames.
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const ACTIONS := ["idle", "walk", "run", "attack1", "attack2", "attack3", "attack4",
    "skill", "evade", "guard", "hit", "defeat"]
const MARGIN := 8
const GIF_DECODER := "res://tools/gif_to_frames.py"


static func load_source(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": "源文件不存在"}
    var suffix := path.get_extension().to_lower()
    if suffix == "gif":
        var folder := OS.get_cache_dir().path_join("wuxia-workbench-" + str(Time.get_ticks_usec()))
        var script := ProjectSettings.globalize_path(GIF_DECODER)
        var output: Array = []
        var code := -1
        for interpreter in ["python3", "python"]:
            output.clear()
            code = OS.execute(interpreter, [script, path, folder], output, true, true)
            if code != -1:
                break
        if code == -1:
            return {"error": "导入 GIF 需要 Python 3 与 Pillow"}
        var result: Variant = JSON.parse_string("\n".join(output).strip_edges())
        if not result is Dictionary:
            return {"error": "GIF 解码失败：" + "\n".join(output).substr(0, 180)}
        if not str(result.get("error", "")).is_empty():
            return result
        var frames: Array[Dictionary] = []
        for entry in result.get("frames", []):
            var image := Image.load_from_file(str(entry["path"]))
            if image == null or image.is_empty():
                return {"error": "GIF 帧读取失败：" + str(entry["path"])}
            image.convert(Image.FORMAT_RGBA8)
            frames.append({"image": image, "duration_ms": int(entry["duration_ms"])})
        return {"error": "", "frames": frames, "size": result["size"]}
    if suffix not in ["png", "webp", "jpg", "jpeg"]:
        return {"error": "仅支持 GIF、PNG、WebP、JPG 图片"}
    var image := Image.load_from_file(path)
    if image == null or image.is_empty():
        return {"error": "原图解码失败"}
    image.convert(Image.FORMAT_RGBA8)
    return {"error": "", "frames": [{"image": image, "duration_ms": 100}],
        "size": image.get_size()}


static func stage_candidate(source: String, actor_id: String, action: String,
        source_size: Vector2i) -> Dictionary:
    if not actor_id.is_valid_identifier() or not ACTIONS.has(action) or not FileAccess.file_exists(source):
        return {"error": "非法角色、动作或源图片"}
    var project := ProjectSettings.globalize_path("res://").rstrip("/")
    var production := project.path_join("../../art-production").simplify_path()
    var digest := FileAccess.get_sha256(source)
    var extension := source.get_extension().to_lower()
    var basename := "workbench_" + digest.substr(0, 16) + ("_" + action if extension == "gif" else "")
    var relative := "characters/%s/workbench/%s.%s" % [actor_id, basename, extension]
    var destination := production.path_join("candidates/" + relative)
    if not FileAccess.file_exists(destination):
        if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK or \
                DirAccess.copy_absolute(source, destination) != OK:
            return {"error": "无法自动归档源图片到候选区"}
    if FileAccess.get_sha256(destination) != digest:
        return {"error": "候选源图存在同名哈希冲突"}
    var resource_path := "res://data/art_candidates/" + relative.get_basename() + ".tres"
    if FileAccess.file_exists(resource_path):
        var existing := load(resource_path) as WuxiaArtCandidateDefinition
        if existing == null or existing.owner_id != actor_id or \
                (extension == "gif" and existing.action_id != action):
            return {"error": "候选 Resource 归属冲突"}
        return {"error": "", "path": destination, "candidate": resource_path}
    var candidate := WuxiaArtCandidateDefinition.new()
    candidate.asset_kind = "sprite"
    candidate.owner_id = actor_id
    candidate.source_path = "art-production/candidates/" + relative
    candidate.source_pixel_size = source_size
    if extension == "gif":
        candidate.action_id = action
    if not candidate.validate_source().is_empty():
        return {"error": "候选记录生成失败：" + candidate.validate_source()}
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resource_path).get_base_dir()) != OK \
            or ResourceSaver.save(candidate, resource_path) != OK:
        return {"error": "候选 Resource 保存失败"}
    return {"error": "", "path": destination, "candidate": resource_path}


static func _difference(a: Color, b: Color) -> float:
    return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## Conservative background removal: flood only border-connected, near-uniform pixels.
## A complex scene must be refined with the hand-drawn mask; it is never guessed away.
static func clean_edges(original: Image, alpha_cutoff: float = 0.07,
        background_tolerance: float = 0.12, min_island_area: int = 8) -> Image:
    var image := original.duplicate() as Image
    image.convert(Image.FORMAT_RGBA8)
    var width := image.get_width()
    var height := image.get_height()
    if width == 0 or height == 0:
        return image
    var corners := [image.get_pixel(0, 0), image.get_pixel(width - 1, 0),
        image.get_pixel(0, height - 1), image.get_pixel(width - 1, height - 1)]
    var opaque := true
    for y in range(height):
        for x in range(width):
            if image.get_pixel(x, y).a < 0.999:
                opaque = false
                break
        if not opaque:
            break
    if opaque:
        var opaque_backup := image.duplicate() as Image
        var visited := PackedByteArray()
        visited.resize(width * height)
        var queue: Array[Vector2i] = []
        for x in range(width):
            queue.append(Vector2i(x, 0))
            queue.append(Vector2i(x, height - 1))
        for y in range(height):
            queue.append(Vector2i(0, y))
            queue.append(Vector2i(width - 1, y))
        var head := 0
        while head < queue.size():
            var point := queue[head]
            head += 1
            var key := point.y * width + point.x
            if visited[key] != 0:
                continue
            visited[key] = 1
            var color := image.get_pixelv(point)
            var background := false
            for corner in corners:
                if _difference(color, corner) <= background_tolerance:
                    background = true
                    break
            if not background:
                continue
            color.a = 0.0
            image.set_pixelv(point, color)
            for shift in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var next: Vector2i = point + shift
                if next.x >= 0 and next.y >= 0 and next.x < width and next.y < height \
                        and visited[next.y * width + next.x] == 0:
                    queue.append(next)
        # A tight, fully opaque crop may have foreground in every corner.
        # Refuse to erase it just because it shares the sampled border color.
        if not image.get_used_rect().has_area():
            image = opaque_backup
    # Remove weak Alpha halos, then tiny disconnected islands; keep larger detached weapons.
    for y in range(height):
        for x in range(width):
            var color := image.get_pixel(x, y)
            if color.a <= alpha_cutoff:
                image.set_pixel(x, y, Color.TRANSPARENT)
    if min_island_area <= 0:
        return image
    var visited := PackedByteArray()
    visited.resize(width * height)
    for y in range(height):
        for x in range(width):
            var index := y * width + x
            if visited[index] != 0 or image.get_pixel(x, y).a == 0.0:
                continue
            var component: Array[Vector2i] = []
            var queue: Array[Vector2i] = [Vector2i(x, y)]
            visited[index] = 1
            var head := 0
            while head < queue.size():
                var point := queue[head]
                head += 1
                component.append(point)
                for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                    var next: Vector2i = point + offset
                    if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
                        continue
                    var ni: int = next.y * width + next.x
                    if visited[ni] != 0 or image.get_pixelv(next).a == 0.0:
                        continue
                    visited[ni] = 1
                    queue.append(next)
            if component.size() < min_island_area:
                for point in component:
                    image.set_pixelv(point, Color.TRANSPARENT)
    return image


static func crop_frame(frame: Dictionary) -> Dictionary:
    var source: Image = frame.get("image")
    var region: Rect2i = frame.get("rect", Rect2i(Vector2i.ZERO, source.get_size()))
    if source == null or not region.has_area() or not Rect2i(Vector2i.ZERO,
            source.get_size()).encloses(region):
        return {"error": "裁切范围超出源图"}
    var cropped := source.get_region(region)
    var polygon: PackedVector2Array = frame.get("polygon", PackedVector2Array())
    if polygon.size() >= 3:
        var masked := preload("res://addons/wuxia_art_importer/sprite_assembly.gd").mask_frame(
            cropped, region, polygon)
        if not str(masked.get("error", "")).is_empty():
            return masked
        cropped = masked["image"]
    var before_cleanup := cropped.duplicate() as Image
    if bool(frame.get("cleanup", true)):
        cropped = clean_edges(cropped, float(frame.get("alpha_cutoff", 0.07)),
            float(frame.get("bg_tolerance", 0.12)), int(frame.get("min_island_area", 8)))
    for stroke in frame.get("strokes", []):
        var points: PackedVector2Array = stroke.get("points", PackedVector2Array())
        var radius := clampi(int(stroke.get("radius", 8)), 1, 64)
        var restoring := bool(stroke.get("restore", false))
        for n in range(points.size()):
            var previous: Vector2 = points[maxi(n - 1, 0)] - Vector2(region.position)
            var current: Vector2 = points[n] - Vector2(region.position)
            var steps := maxi(1, ceili(previous.distance_to(current)))
            for t in range(steps + 1):
                var center := previous.lerp(current, float(t) / steps)
                for py in range(maxi(0, floori(center.y) - radius),
                        mini(cropped.get_height(), ceili(center.y) + radius + 1)):
                    for px in range(maxi(0, floori(center.x) - radius),
                            mini(cropped.get_width(), ceili(center.x) + radius + 1)):
                        var distance := Vector2(px + 0.5, py + 0.5).distance_to(center)
                        if distance > radius:
                            continue
                        var strength := clampf(float(radius) - distance, 0.0, 1.0)
                        var old := cropped.get_pixel(px, py)
                        var replacement := before_cleanup.get_pixel(px, py) if restoring else Color.TRANSPARENT
                        cropped.set_pixel(px, py, old.lerp(replacement, strength))
    return {"error": "", "image": cropped, "rect": region}


static func render_frame(frame: Dictionary, cell: Vector2i, strict: bool = true) -> Dictionary:
    var extracted := crop_frame(frame)
    if not str(extracted.get("error", "")).is_empty():
        return extracted
    var image: Image = extracted["image"]
    var used := image.get_used_rect()
    if not used.has_area():
        return {"error": "抠图结果为空，请减小过滤强度或修正选区"}
    var scale := float(frame.get("scale", 1.0))
    if not is_finite(scale) or scale <= 0.0 or scale > 8.0:
        return {"error": "缩放倍率必须大于零且不超过 8"}
    var scaled := image.get_region(used)
    var dimensions := Vector2i(roundi(used.size.x * scale), roundi(used.size.y * scale)).max(Vector2i.ONE)
    if dimensions != scaled.get_size():
        scaled.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
    var anchor: Variant = frame.get("anchor")
    var source_anchor := Vector2(used.position.x + used.size.x * 0.5,
        used.position.y + used.size.y) if not anchor is Vector2 else Vector2(anchor) - Vector2(extracted["rect"].position)
    var destination_anchor := Vector2(cell.x * 0.5, cell.y - 16) + Vector2(frame.get("offset", Vector2.ZERO))
    var dest := Vector2i((destination_anchor - (source_anchor - Vector2(used.position)) * scale).round())
    var output := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
    output.fill(Color.TRANSPARENT)
    var canvas := Rect2i(Vector2i.ZERO, cell)
    var placed := Rect2i(dest, dimensions)
    if strict and not canvas.encloses(placed):
        return {"error": "角色或武器超出画布，请缩小或移动当前帧"}
    output.blit_rect(scaled, Rect2i(Vector2i.ZERO, dimensions), dest)
    var bounds := output.get_used_rect()
    if strict and (not bounds.has_area() or bounds.position.x < MARGIN or bounds.position.y < MARGIN or \
            bounds.end.x > cell.x - MARGIN or bounds.end.y > cell.y - MARGIN):
        return {"error": "标准化后四边必须保留至少 8px 透明边距"}
    return {"error": "", "image": output}


static func build(frames: Array, cell: Vector2i, action: String, fps: float,
        looping: bool) -> Dictionary:
    if action not in ACTIONS or frames.is_empty() or frames.size() > 256:
        return {"error": "请选择有效动作和 1..256 个编辑帧"}
    if not is_finite(fps) or fps <= 0.0 or fps > 60.0 or (action == "defeat" and looping):
        return {"error": "动作 FPS 或循环配置非法"}
    if cell not in [Vector2i(328, 256), Vector2i(384, 288)]:
        return {"error": "目标必须是普通档或高个档"}
    var count := frames.size()
    var columns := mini(5, count)
    var rows := int(ceili(float(count) / float(columns)))
    var atlas := Image.create(columns * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
    atlas.fill(Color.TRANSPARENT)
    var durations: PackedFloat32Array = PackedFloat32Array()
    for index in range(count):
        var result := render_frame(frames[index], cell)
        if not str(result.get("error", "")).is_empty():
            return {"error": "第 %d 帧：%s" % [index + 1, result["error"]]}
        var picture: Image = result["image"]
        atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, cell),
            Vector2i(index % columns, index / columns) * cell)
        var ms := int(frames[index].get("duration_ms", roundi(1000.0 / fps)))
        if ms <= 0:
            return {"error": "第 %d 帧时长必须大于零" % [index + 1]}
        durations.append(float(ms) / 1000.0)
    var bytes := atlas.save_png_to_buffer()
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    return {"error": "", "bytes": bytes, "sha256": hash.finish().hex_encode(),
        "image": atlas, "columns": columns, "rows": rows, "cell": cell,
        "count": count, "durations": durations, "fps": fps, "loop": looping, "action": action}


static func make_frames(existing: SpriteFrames, built: Dictionary, atlas: Texture2D) -> SpriteFrames:
    var frames := existing.duplicate(true) as SpriteFrames if existing != null else SpriteFrames.new()
    var action: String = built["action"]
    if frames.has_animation(action):
        frames.remove_animation(action)
    frames.add_animation(action)
    frames.set_animation_speed(action, float(built["fps"]))
    frames.set_animation_loop(action, bool(built["loop"]))
    for index in range(int(built["count"])):
        var region := AtlasTexture.new()
        region.atlas = atlas
        region.region = Rect2(Vector2(index % int(built["columns"]),
            index / int(built["columns"])) * Vector2(built["cell"]), Vector2(built["cell"]))
        frames.add_frame(action, region, float(built["durations"][index]) * float(built["fps"]))
    if frames.has_animation("default") and frames.get_frame_count("default") == 0:
        frames.remove_animation("default")
    return frames


static func prepare(target: String, built: Dictionary) -> Dictionary:
    if not str(built.get("error", "")).is_empty():
        return built
    var actor := ResourceLoader.load(target) as WuxiaCharacterDefinition
    if actor == null or target != "res://data/native/characters/" + actor.content_id + ".tres":
        return {"error": "请选择有效角色 Resource"}
    var profile: WuxiaActorAnimationProfile = actor.animation_profile
    if profile == null:
        return {"error": "角色没有可编辑的 AnimationProfile"}
    if profile.native_frames == null and (not profile.clips.is_empty() or \
            profile.atlas != null or str(built["action"]) != "idle"):
        return {"error": "此角色仍使用旧 Atlas/Clip，先在 Godot 完成原生 SpriteFrames 迁移；拒绝隐式丢弃旧动作"}
    var existing: SpriteFrames = profile.native_frames
    var hash: String = built["sha256"]
    var id: String = actor.content_id
    var picture_path := "res://assets/imported/characters/%s/sprites/%s/atlas__%s.png" % [
        id, built["action"], hash.substr(0, 12)]
    if FileAccess.file_exists(picture_path) and FileAccess.get_sha256(picture_path) != hash:
        return {"error": "导入目标存在图片哈希冲突"}
    # Include old binding identity in the version key: preserve user-edited SpriteFrames.
    var original_path := profile.native_frames.resource_path if profile.native_frames != null else ""
    var original_hash := FileAccess.get_sha256(original_path) if not original_path.is_empty() else ""
    var version := (hash + "|" + str(built["action"]) + "|" + str(built["durations"]) +
        "|" + str(built["fps"]) + "|" + str(built["loop"]) + "|" + original_hash).sha256_text()
    var frames_path := "res://data/native/animations/%s_frames__%s.tres" % [id, version.substr(0, 12)]
    if FileAccess.file_exists(frames_path):
        return {"error": "同版本 SpriteFrames 已存在；为保护 Godot 原生修改，拒绝覆盖：" + frames_path}
    var profile_path := "res://data/native/animations/" + id + ".tres"
    if not FileAccess.file_exists(profile_path) or profile.resource_path != profile_path:
        return {"error": "角色缺少独立 AnimationProfile 文件，拒绝创建可能覆盖其他资源的绑定"}
    var plan := {"error": "", "mode": "workbench", "target": target,
        "target_sha256": FileAccess.get_sha256(target),
        "profile_sha256": FileAccess.get_sha256(profile_path),
        "profile_path": profile_path,
        "native_frames_path": frames_path,
        "files": {"atlas": {"destination": picture_path, "sha256": hash,
            "generated_bytes": built["bytes"]}}, "built": built}
    var check: String = Transaction.validate([plan])
    if not check.is_empty():
        return {"error": check}
    return plan


static func apply(plan: Dictionary) -> Dictionary:
    var fresh := prepare(str(plan.get("target", "")), plan.get("built", {}))
    if not str(fresh.get("error", "")).is_empty():
        return fresh
    if fresh["native_frames_path"] != plan.get("native_frames_path") or \
            fresh["target_sha256"] != plan.get("target_sha256") or \
            fresh["profile_sha256"] != plan.get("profile_sha256"):
        return {"error": "预览后角色资源或动作发生变化，请重新检查"}
    var started := Transaction.begin([plan])
    if not str(started.get("error", "")).is_empty():
        return started
    var journal: String = started["journal"]
    var item: Dictionary = plan["files"]["atlas"]
    var path: String = item["destination"]
    var failure := ""
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir()) != OK:
        failure = "无法创建图片目录"
    elif not FileAccess.file_exists(path):
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            failure = "无法写入生成帧图"
        else:
            file.store_buffer(item["generated_bytes"])
            file.close()
    if failure.is_empty() and FileAccess.get_sha256(path) != str(item["sha256"]):
        failure = "生成图与预检哈希不一致"
    if failure.is_empty():
        var actor := ResourceLoader.load(str(plan["target"])) as WuxiaCharacterDefinition
        var staged := actor.animation_profile.duplicate(true) as WuxiaActorAnimationProfile
        var generated := ImageTexture.create_from_image(plan["built"]["image"] as Image)
        # Use the real imported PNG whenever available; the in-memory texture is a
        # lossless editor fallback until Godot finishes scanning the new image.
        var atlas := ResourceLoader.load(path, "Texture2D") as Texture2D if \
            ResourceLoader.exists(path, "Texture2D") else generated
        var merged := make_frames(staged.native_frames, plan["built"], atlas)
        staged.native_frames = merged
        # Preserve old resource metadata and clips for audit/rollback, even
        # though the runtime prefers native_frames once bound.
        if not staged.valid_profile():
            failure = "原生动画校验失败：必须存在 idle，且动作帧和时长有效"
        elif DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
                str(plan["native_frames_path"])).get_base_dir()) != OK:
            failure = "无法创建 SpriteFrames 目录"
        elif ResourceSaver.save(merged, str(plan["native_frames_path"])) != OK:
            failure = "SpriteFrames 保存失败"
        else:
            staged.native_frames = ResourceLoader.load(str(plan["native_frames_path"]),
                "SpriteFrames", ResourceLoader.CACHE_MODE_REPLACE) as SpriteFrames
            if staged.native_frames == null or ResourceSaver.save(staged,
                    str(plan["profile_path"])) != OK:
                failure = "AnimationProfile 保存失败"
            else:
                var updated := actor.duplicate(true) as WuxiaCharacterDefinition
                updated.animation_profile = staged
                if ResourceSaver.save(updated, str(plan["target"])) != OK:
                    failure = "角色动画绑定失败"
    if failure.is_empty():
        failure = Transaction.commit(journal)
    if not failure.is_empty():
        var rollback := Transaction.rollback(journal, true)
        return {"error": failure + ("；回滚失败：" + rollback if not rollback.is_empty() else "")}
    # Invalidate the editor's previous in-memory binding so the next action
    # starts from the just-saved SpriteFrames and cannot drop this action.
    ResourceLoader.load(str(plan["profile_path"]), "", ResourceLoader.CACHE_MODE_REPLACE)
    ResourceLoader.load(str(plan["target"]), "", ResourceLoader.CACHE_MODE_REPLACE)
    return {"error": "", "journal": journal, "frames_path": plan["native_frames_path"]}
