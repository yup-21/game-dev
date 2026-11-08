@tool
extends RefCounted
## Editor-only sprite assembly from explicit source crops, masks and placement.
## All action/frame semantics come from explicit user mappings.

const ACTIONS := ["idle", "walk", "run", "attack1", "attack2", "attack3",
    "attack4", "skill", "evade", "guard", "hit", "defeat"]
const MARGIN := 8
const MAX_FRAME_SCALE := 8.0


static func parse_mapping(value: String, source_count: int) -> Dictionary:
    var result: Array[Dictionary] = []
    if value.strip_edges().is_empty():
        return {"error": "动作未指定帧", "frames": result}
    for part in value.split(",", false):
        var token := part.strip_edges().split(":")
        if token.size() != 2 or not token[0].strip_edges().is_valid_int():
            return {"error": "帧格式应为 源图编号:格号，例如 0:0-7,1:2", "frames": []}
        var source := int(token[0].strip_edges())
        if source < 0 or source >= source_count:
            return {"error": "源图编号超出已添加图集范围：" + str(source), "frames": []}
        var ends := token[1].strip_edges().split("-")
        if ends.size() < 1 or ends.size() > 2 or not ends[0].is_valid_int() or \
                (ends.size() == 2 and not ends[1].is_valid_int()):
            return {"error": "无效的格号范围：" + part, "frames": []}
        var first := int(ends[0])
        var last := int(ends[-1])
        if first < 0 or last < first or last > 4095:
            return {"error": "格号范围非法：" + part, "frames": []}
        for index in range(first, last + 1):
            result.append({"source": source, "cell": index})
    if result.size() > 256:
        return {"error": "单动作最多 256 帧", "frames": []}
    return {"error": "", "frames": result}


static func grid_rect(source: Dictionary, index: int) -> Rect2i:
    var cols := int(source.get("columns", 0))
    var rows := int(source.get("rows", 0))
    if cols <= 0 or rows <= 0 or index < 0 or index >= cols * rows:
        return Rect2i()
    var cell := Vector2i(int(source.get("cell_width", 0)), int(source.get("cell_height", 0)))
    var origin := Vector2i(int(source.get("origin_x", 0)), int(source.get("origin_y", 0)))
    var spacing := Vector2i(int(source.get("gap_x", 0)), int(source.get("gap_y", 0)))
    var offsets: Dictionary = source.get("offsets", {})
    var local: Vector2i = offsets.get(index, Vector2i.ZERO)
    return Rect2i(origin + Vector2i(index % cols, index / cols) * (cell + spacing) + local, cell)


static func cell_rect(source: Dictionary, index: int) -> Rect2i:
    var default_rect := grid_rect(source, index)
    if not default_rect.has_area():
        return default_rect
    return source.get("rects", {}).get(index, default_rect)


static func _validate_source(source: Dictionary) -> String:
    var texture: Texture2D = source.get("texture") as Texture2D
    var cols := int(source.get("columns", 0))
    var rows := int(source.get("rows", 0))
    var width := int(source.get("cell_width", 0))
    var height := int(source.get("cell_height", 0))
    if texture == null or cols < 1 or cols > 64 or rows < 1 or rows > 64 or \
            width < 1 or height < 1:
        return "图集纹理或切格几何配置无效"
    if texture.get_image().detect_alpha() == Image.ALPHA_NONE:
        return "角色动作源图缺少透明通道"
    for field in ["rects", "canvas_offsets", "masks"]:
        var overrides: Dictionary = source.get(field, {})
        for key in overrides:
            if not key is int or key < 0 or key >= cols * rows or \
                    (field == "rects" and not overrides[key] is Rect2i) or \
                    (field == "canvas_offsets" and not overrides[key] is Vector2i) or \
                    (field == "masks" and (not overrides[key] is PackedVector2Array or \
                        overrides[key].size() < 3)):
                return "逐帧裁切或输出偏移配置无效"
    for index in range(cols * rows):
        var rect := cell_rect(source, index)
        if not rect.has_area() or rect.position.x < 0 or rect.position.y < 0 or \
                rect.end.x > texture.get_width() or rect.end.y > texture.get_height():
            return "格 %d 超出源图：选区 %s，原图 %d×%d" % [
                index, str(rect), texture.get_width(), texture.get_height()]
    for field in ["scales", "anchors"]:
        var edits: Dictionary = source.get(field, {})
        for index in edits:
            if not index is int or index < 0 or index >= cols * rows:
                return "逐帧缩放或脚点格号无效：" + str(index)
            if field == "anchors" and not edits[index] is Vector2:
                return "格 %d：脚点坐标无效" % index
            var error := frame_edit_error(cell_rect(source, index),
                source.get("scales", {}).get(index, 1.0), source.get("anchors", {}).get(index))
            if not error.is_empty():
                return "格 %d：%s" % [index, error]
    return ""


static func frame_edit_error(rect: Rect2i, multiplier: Variant, anchor: Variant) -> String:
    if not (multiplier is float or multiplier is int) or not is_finite(float(multiplier)) \
            or float(multiplier) <= 0.0 or float(multiplier) > MAX_FRAME_SCALE:
        return "帧缩放倍率必须大于 0 且不超过 8"
    if anchor != null:
        if not anchor is Vector2 or not anchor.is_finite() \
                or not Rect2(rect).has_point(anchor):
            return "脚点必须位于当前帧裁切矩形内，请重新点选"
    return ""


static func _base_size(sources: Array) -> Vector2i:
    var result := Vector2i.ZERO
    for source in sources:
        result = result.max(Vector2i(int(source["cell_width"]), int(source["cell_height"])))
        for rect in source.get("rects", {}).values():
            result = result.max(rect.size)
    return result


static func _frame_layout(base: Vector2i, target: Vector2i) -> Dictionary:
    var factor := minf(float(target.x) / base.x, float(target.y) / base.y)
    var scaled := Vector2i(roundi(base.x * factor), roundi(base.y * factor)).max(Vector2i.ONE)
    return {"factor": factor, "padding": (target - scaled) / 2}


static func _place_frame(image: Image, source: Dictionary, index: int, rect: Rect2i,
        base: Vector2i, target: Vector2i, layout: Dictionary) -> Dictionary:
    var multiplier: Variant = source.get("scales", {}).get(index, 1.0)
    var anchor: Variant = source.get("anchors", {}).get(index)
    var problem := frame_edit_error(rect, multiplier, anchor)
    if not problem.is_empty():
        return {"error": problem}
    var factor: float = layout["factor"]
    var scale := factor * float(multiplier)
    var normal_size := Vector2i(roundi(rect.size.x * factor), roundi(rect.size.y * factor)).max(Vector2i.ONE)
    var frame_size := Vector2i(roundi(rect.size.x * scale), roundi(rect.size.y * scale)).max(Vector2i.ONE)
    var raster_scale := Vector2(frame_size) / Vector2(rect.size)
    var nudge: Vector2i = source.get("canvas_offsets", {}).get(index, Vector2i.ZERO)
    var canvas_position := (base - rect.size) / 2 + nudge
    var padding: Vector2i = layout["padding"]
    var dest := padding + Vector2i((Vector2(canvas_position) * factor).round()) \
        + (normal_size - frame_size) / 2
    if anchor != null:
        var output_anchor := Vector2(target.x * 0.5, target.y - 16)
        # Match the actual integer-sized resample when projecting the source point.
        dest = Vector2i((output_anchor - (Vector2(anchor) - Vector2(rect.position)) * raster_scale \
            + Vector2(nudge) * factor).round())
    var output_rect := Rect2i(Vector2i.ZERO, target)
    var overflow := {"error": "缩放定位后的帧内容超出输出画布 %s，请调整倍率、脚点或偏移" % str(target)}
    if not output_rect.encloses(Rect2i(dest, frame_size)):
        if anchor == null and float(multiplier) == 1.0:
            return overflow
        # Discard excess transparent padding while preserving the source point projection.
        var content := image.get_used_rect()
        var start := dest + Vector2i((Vector2(content.position) * raster_scale).round())
        var end := dest + Vector2i((Vector2(content.end) * raster_scale).round())
        if not content.has_area() or not output_rect.encloses(Rect2i(start, (end - start).max(Vector2i.ONE))):
            return overflow
        var sample := content.grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
        start = dest + Vector2i((Vector2(sample.position) * raster_scale).round())
        end = dest + Vector2i((Vector2(sample.end) * raster_scale).round())
        dest = start
        frame_size = (end - start).max(Vector2i.ONE)
        image = image.get_region(sample)
    if frame_size != image.get_size():
        image.resize(frame_size.x, frame_size.y, Image.INTERPOLATE_LANCZOS)
    if not output_rect.encloses(Rect2i(dest, frame_size)):
        var used := image.get_used_rect()
        if not output_rect.encloses(Rect2i(dest + used.position, used.size)):
            return overflow
        var visible := output_rect.intersection(Rect2i(dest, frame_size))
        image = image.get_region(Rect2i(visible.position - dest, visible.size))
        dest = visible.position
    return {"error": "", "position": dest, "image": image}


static func preview_frame(sources: Array, source_index: int, cell_index: int,
        target_cell: Vector2i) -> Dictionary:
    if source_index < 0 or source_index >= sources.size() or target_cell.x <= 0 or target_cell.y <= 0:
        return {"error": "缺少预览源图或输出画布"}
    var source: Dictionary = sources[source_index]
    var texture := source.get("texture") as Texture2D
    var rect := cell_rect(source, cell_index)
    if texture == null or not rect.has_area() or not Rect2i(Vector2i.ZERO,
            Vector2i(texture.get_size())).encloses(rect):
        return {"error": "当前帧裁切超出源图"}
    var cropped := texture.get_image().get_region(rect)
    var points: PackedVector2Array = source.get("masks", {}).get(cell_index, PackedVector2Array())
    if not points.is_empty():
        var masked := mask_frame(cropped, rect, points)
        if not str(masked["error"]).is_empty():
            return masked
        cropped = masked["image"]
    var base := _base_size(sources)
    var placed := _place_frame(cropped, source, cell_index, rect, base, target_cell,
        _frame_layout(base, target_cell))
    if not str(placed["error"]).is_empty():
        return placed
    var canvas := Image.create(target_cell.x, target_cell.y, false, Image.FORMAT_RGBA8)
    canvas.fill(Color.TRANSPARENT)
    var rendered: Image = placed["image"]
    canvas.blit_rect(rendered, Rect2i(Vector2i.ZERO, rendered.get_size()), placed["position"])
    return {"error": "", "texture": ImageTexture.create_from_image(canvas)}


## Even-odd scanline fill. Preserve original Alpha inside the hand-drawn
## outline, set RGBA to transparent outside it. No texture modifications occur
## outside the returned cropped image.
static func mask_frame(frame_image: Image, rect: Rect2i, points: PackedVector2Array) -> Dictionary:
    if points.size() < 3 or points.size() > 2048:
        return {"error": "描边蒙版需要 3..2048 个点"}
    var polygon := PackedVector2Array()
    for point in points:
        if not is_finite(point.x) or not is_finite(point.y) or \
                point.x < rect.position.x or point.y < rect.position.y or \
                point.x > rect.end.x or point.y > rect.end.y:
            return {"error": "描边点超出当前矩形裁切范围"}
        polygon.append(point - Vector2(rect.position))
    var rgba: Image = frame_image.duplicate()
    rgba.convert(Image.FORMAT_RGBA8)
    var data: PackedByteArray = rgba.get_data()
    for y in range(rgba.get_height()):
        var scan_y := float(y) + 0.5
        var crossings: Array[float] = []
        for p in range(polygon.size()):
            var a := polygon[p]
            var b := polygon[(p + 1) % polygon.size()]
            if (a.y <= scan_y and b.y > scan_y) or (b.y <= scan_y and a.y > scan_y):
                crossings.append(a.x + (scan_y - a.y) * (b.x - a.x) / (b.y - a.y))
        crossings.sort()
        var span := 0
        for x in range(rgba.get_width()):
            var scan_x := float(x) + 0.5
            while span < crossings.size() and scan_x >= crossings[span]:
                span += 1
            if span % 2 == 0:
                var offset: int = (y * rgba.get_width() + x) * 4
                data[offset] = 0
                data[offset + 1] = 0
                data[offset + 2] = 0
                data[offset + 3] = 0
    return {"error": "", "image": Image.create_from_data(
        rgba.get_width(), rgba.get_height(), false, Image.FORMAT_RGBA8, data)}


static func _validate_frame(image: Image, rect: Rect2i, label: String) -> String:
    var bounds := image.get_region(rect).get_used_rect()
    if not bounds.has_area():
        return label + " 没有有效像素"
    if bounds.position.x < MARGIN or bounds.position.y < MARGIN or \
            bounds.end.x > rect.size.x - MARGIN or bounds.end.y > rect.size.y - MARGIN:
        return label + " 四边需要至少 8px 真透明留白；请调整切格或返工源图"
    return ""


static func _durations(value: String, count: int) -> Dictionary:
    var result := PackedFloat32Array()
    if value.strip_edges().is_empty():
        return {"error": "", "values": result}
    for token in value.split(",", false):
        var trimmed := token.strip_edges()
        if not trimmed.is_valid_float() or float(trimmed) <= 0.0 or not is_finite(float(trimmed)):
            return {"error": "逐帧时长必须是正秒数", "values": result}
        result.append(float(trimmed))
    if result.size() != count:
        return {"error": "逐帧时长数量与绑定帧数不一致", "values": result}
    return {"error": "", "values": result}


## sources: [{texture, columns, rows, cell_width, cell_height, origin_x/y,
##            gap_x/y, offsets, rects: {index: Rect2i},
##            canvas_offsets: {index: Vector2i}, masks: {index: PackedVector2Array},
##            scales: {index: float}, anchors: {index: Vector2}}]
## mappings: {action_id: "source_number:cell[-cell],..."}
static func build(sources: Array, mappings: Dictionary, metadata: Dictionary,
        target_cell: Vector2i = Vector2i.ZERO) -> Dictionary:
    if sources.is_empty() or sources.size() > 32:
        return {"error": "请选择 1..32 张源图集"}
    var source_images: Array[Image] = []
    for i in range(sources.size()):
        var source: Dictionary = sources[i]
        var failure := _validate_source(source)
        if not failure.is_empty():
            return {"error": "源图 %d：%s" % [i, failure]}
        source_images.append((source["texture"] as Texture2D).get_image())
    var base_size := _base_size(sources)

    var sequence: Array[Dictionary] = []
    var clips: Dictionary = {}
    for action in ACTIONS:
        var parsed := parse_mapping(str(mappings.get(action, "")), sources.size())
        if not str(parsed["error"]).is_empty():
            return {"error": action + "：" + str(parsed["error"])}
        var mapping: Array = parsed["frames"]
        var config: Dictionary = metadata.get(action, {})
        var fps := float(config.get("fps", 12.0))
        var looping := bool(config.get("loop", action in ["idle", "walk", "run"]))
        if not is_finite(fps) or fps < 1.0 or fps > 60.0 or (action == "defeat" and looping):
            return {"error": action + "：循环与 FPS 配置无效"}
        var times := _durations(str(config.get("durations", "")), mapping.size())
        if not str(times["error"]).is_empty():
            return {"error": action + "：" + str(times["error"])}
        var frames := PackedInt32Array()
        for ref in mapping:
            var index := int(ref["cell"])
            var source_index := int(ref["source"])
            var source: Dictionary = sources[source_index]
            var rect := cell_rect(source, index)
            if not rect.has_area():
                return {"error": "%s：源图 %d 不存在格 %d" % [action, source_index, index]}
            var cropped := source_images[source_index].get_region(rect)
            var points: PackedVector2Array = source.get("masks", {}).get(index, PackedVector2Array())
            if not points.is_empty():
                var masked := mask_frame(cropped, rect, points)
                if not str(masked.get("error", "")).is_empty():
                    return {"error": "%s 源图 %d 格 %d：%s" % [action, source_index,
                        index, masked["error"]]}
                cropped = masked["image"]
            var error := _validate_frame(cropped, Rect2i(Vector2i.ZERO, rect.size),
                "%s 源图 %d 格 %d" % [action, source_index, index])
            if not error.is_empty():
                return {"error": error}
            frames.append(sequence.size())
            sequence.append({"source": source_index, "cell": index, "rect": rect,
                "image": cropped})
        clips[action] = {"frames": frames, "fps": fps, "loop": looping,
            "durations": times["values"]}
    if sequence.size() > 512:
        return {"error": "单个装配 Atlas 最多 512 帧；请拆分角色图集"}

    if target_cell == Vector2i.ZERO:
        target_cell = base_size
    if target_cell.x < 16 or target_cell.y < 16 or target_cell.x > 4096 or target_cell.y > 4096:
        return {"error": "目标单格像素无效"}
    # Unedited frames use the common scale and center the authored crop canvas.
    # Explicit frame edits can refine that scale and place a picked foot point.
    var layout := _frame_layout(base_size, target_cell)
    var factor: float = layout["factor"]
    var output_columns := mini(5 if sequence.size() <= 320 else 8, sequence.size())
    var output_rows := int(ceili(float(sequence.size()) / float(output_columns)))
    var output := Image.create(output_columns * target_cell.x, output_rows * target_cell.y,
        false, Image.FORMAT_RGBA8)
    output.fill(Color.TRANSPARENT)
    for n in range(sequence.size()):
        var part: Dictionary = sequence[n]
        var frame_image: Image = part["image"]
        var rect: Rect2i = part["rect"]
        var source: Dictionary = sources[int(part["source"])]
        var placed := _place_frame(frame_image, source, int(part["cell"]), rect, base_size,
            target_cell, layout)
        if not str(placed["error"]).is_empty():
            return {"error": "第 %d 帧：%s" % [n, placed["error"]]}
        var bounds := Rect2i(Vector2i(n % output_columns, n / output_columns) * target_cell,
            target_cell)
        var rendered: Image = placed["image"]
        output.blit_rect(rendered, Rect2i(Vector2i.ZERO, rendered.get_size()),
            bounds.position + Vector2i(placed["position"]))
        var final_error := _validate_frame(output, bounds, "标准化后第 %d 帧" % n)
        if not final_error.is_empty():
            return {"error": final_error}
    var bytes := output.save_png_to_buffer()
    if bytes.is_empty():
        return {"error": "无法编码装配后的 PNG"}
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    return {"error": "", "bytes": bytes, "sha256": hash.finish().hex_encode(),
        "texture": ImageTexture.create_from_image(output), "columns": output_columns,
        "rows": output_rows, "cell": target_cell, "source_cell": base_size,
        "scale_factor": factor, "clips": clips, "count": sequence.size()}
