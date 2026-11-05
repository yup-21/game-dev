@tool
extends RefCounted
## Editor-only sprite assembly. A source cell is never resized or alpha-trimmed.
## All action/frame semantics come from explicit user mappings.

const ACTIONS := ["idle", "walk", "run", "attack1", "attack2", "attack3",
    "attack4", "skill", "evade", "guard", "hit", "defeat"]
const MARGIN := 8


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


static func cell_rect(source: Dictionary, index: int) -> Rect2i:
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
    for index in range(cols * rows):
        var rect := cell_rect(source, index)
        if rect.position.x < 0 or rect.position.y < 0 or \
                rect.end.x > texture.get_width() or rect.end.y > texture.get_height():
            return "格位超出源图：" + str(index)
    return ""


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
##            gap_x/y, offsets: {absolute_cell_index: Vector2i}}]
## mappings: {action_id: "source_number:cell[-cell],..."}
static func build(sources: Array, mappings: Dictionary, metadata: Dictionary,
        target_cell: Vector2i = Vector2i.ZERO) -> Dictionary:
    if sources.is_empty() or sources.size() > 32:
        return {"error": "请选择 1..32 张源图集"}
    var base_size := Vector2i.ZERO
    var source_images: Array[Image] = []
    for i in range(sources.size()):
        var source: Dictionary = sources[i]
        var failure := _validate_source(source)
        if not failure.is_empty():
            return {"error": "源图 %d：%s" % [i, failure]}
        var cell := Vector2i(int(source["cell_width"]), int(source["cell_height"]))
        if base_size == Vector2i.ZERO:
            base_size = cell
        elif base_size != cell:
            return {"error": "多图的单格像素尺寸必须一致；先按统一比例与透明补边标准化源图"}
        source_images.append((source["texture"] as Texture2D).get_image())

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
            var error := _validate_frame(source_images[source_index], rect,
                "%s 源图 %d 格 %d" % [action, source_index, index])
            if not error.is_empty():
                return {"error": error}
            frames.append(sequence.size())
            sequence.append({"source": source_index, "cell": index, "rect": rect})
        clips[action] = {"frames": frames, "fps": fps, "loop": looping,
            "durations": times["values"]}
    if sequence.size() > 512:
        return {"error": "单个装配 Atlas 最多 512 帧；请拆分角色图集"}

    if target_cell == Vector2i.ZERO:
        target_cell = base_size
    if target_cell.x < 16 or target_cell.y < 16 or target_cell.x > 4096 or target_cell.y > 4096:
        return {"error": "目标单格像素无效"}
    # One common isotropic factor for all sources and all frames, followed by
    # identical transparent padding. No per-frame alpha trim/centering/scaling.
    var factor := minf(float(target_cell.x) / float(base_size.x),
        float(target_cell.y) / float(base_size.y))
    var scaled_size := Vector2i(maxi(1, roundi(float(base_size.x) * factor)),
        maxi(1, roundi(float(base_size.y) * factor)))
    var padding := (target_cell - scaled_size) / 2
    var output_columns := mini(5 if sequence.size() <= 320 else 8, sequence.size())
    var output_rows := int(ceili(float(sequence.size()) / float(output_columns)))
    var output := Image.create(output_columns * target_cell.x, output_rows * target_cell.y,
        false, Image.FORMAT_RGBA8)
    output.fill(Color.TRANSPARENT)
    for n in range(sequence.size()):
        var part: Dictionary = sequence[n]
        var frame_image: Image = source_images[int(part["source"])].get_region(part["rect"])
        if scaled_size != base_size:
            frame_image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
        var dest := Vector2i(n % output_columns, n / output_columns) * target_cell + padding
        output.blit_rect(frame_image, Rect2i(Vector2i.ZERO, scaled_size), dest)
        var final_rect := Rect2i(Vector2i(n % output_columns, n / output_columns) * target_cell,
            target_cell)
        var final_error := _validate_frame(output, final_rect, "标准化后第 %d 帧" % n)
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
