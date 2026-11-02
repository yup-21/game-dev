extends RefCounted
## Shared presentation-only sizing: normalize actual opaque silhouette, not
## atlas-cell dimensions. A uniform display height keeps characters consistent
## even when artists leave different transparent margins in their PNG frames.
const TARGET_HEIGHT := 200.0
const ALPHA_THRESHOLD := 0.20
static var _bounds_cache: Dictionary = {}

static func _opaque_bounds(texture: Texture2D, columns: int, rows: int,
        reference_frame: int = 0) -> Rect2i:
    if texture == null or columns < 1 or rows < 1 or reference_frame < 0 or reference_frame >= columns * rows:
        return Rect2i()
    var key := "%d:%d:%d:%d" % [texture.get_instance_id(), columns, rows, reference_frame]
    if _bounds_cache.has(key):
        return _bounds_cache[key]
    var image := texture.get_image()
    if image == null or image.is_empty():
        return Rect2i()
    var fw: int = image.get_width() / columns
    var fh: int = image.get_height() / rows
    if fw <= 0 or fh <= 0:
        return Rect2i()
    var min_x := fw
    var min_y := fh
    var max_x := -1
    var max_y := -1
    # Measure the EXACT authored idle pose (side-facing in battle), not
    # an arbitrary atlas frame. This prevents pose-dependent foot drift.
    # Subsample large static poses for predictable loading cost.
    var stride: int = maxi(1, ceili(float(maxi(fw, fh)) / 256.0))
    var frame_x: int = (reference_frame % columns) * fw
    var frame_y: int = (reference_frame / columns) * fh
    for y in range(0, fh, stride):
        for x in range(0, fw, stride):
            if image.get_pixel(frame_x + x, frame_y + y).a < ALPHA_THRESHOLD:
                continue
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    var visible := Rect2i()
    if max_x >= min_x and max_y >= min_y:
        visible = Rect2i(min_x, min_y,
            maxi(1, max_x - min_x + stride), maxi(1, max_y - min_y + stride))
    _bounds_cache[key] = visible
    return visible

static func fit(sprite: Sprite2D, fallback_scale: Vector2 = Vector2.ONE,
        target_height: float = TARGET_HEIGHT,
        feet_adjust: Vector2 = Vector2.ZERO,
        reference_frame: int = 0) -> bool:
    if sprite == null or sprite.texture == null:
        return false
    var columns: int = maxi(1, sprite.hframes)
    var rows: int = maxi(1, sprite.vframes)
    var rect: Rect2i = _opaque_bounds(sprite.texture, columns, rows, reference_frame)
    var frame_size := Vector2(sprite.texture.get_width() / columns,
        sprite.texture.get_height() / rows)
    # An opaque full-frame matte cannot provide a reliable silhouette.
    # Preserve the authored profile in that exceptional case.
    if rect.size.y < 16 or rect.size.y >= int(frame_size.y * 0.96):
        sprite.scale = fallback_scale
        # Respect the authored foot anchor on opaque/non-sprite images.
        sprite.offset += Vector2(feet_adjust.x / maxf(fallback_scale.x, 0.001),
            feet_adjust.y / maxf(fallback_scale.y, 0.001))
        return false
    var factor: float = target_height / float(rect.size.y)
    sprite.scale = Vector2.ONE * factor
    # Keep the atlas frame's X-centre as the pivot. Centering the alpha
    # bounding box would shift the actor when a sword/cape changes sides.
    # The foot remains exactly on the Node2D origin (unless nudged).
    sprite.offset = Vector2(0.0, frame_size.y * 0.5 - float(rect.end.y)) + feet_adjust / factor
    return true
