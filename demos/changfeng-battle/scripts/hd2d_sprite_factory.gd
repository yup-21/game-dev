extends RefCounted
## Deterministic, original 6x4 pixel-art atlas. No dependency on external art.
## Every 96x80 cell is truly transparent outside the figure; rows: idle,
## run, attack, guard/hit/evade/skill. One character palette per team.
const WIDTH := 96
const HEIGHT := 80
const FRAMES := 6
const ROWS := 4

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    for yy in range(maxi(0, y), mini(img.get_height(), y + h)):
        for xx in range(maxi(0, x), mini(img.get_width(), x + w)):
            img.set_pixel(xx, yy, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, thickness: int = 1) -> void:
    var dx: int = absi(x1 - x0)
    var dy: int = -absi(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx + dy
    while true:
        _rect(img, x0 - (thickness >> 1), y0 - (thickness >> 1), thickness, thickness, c)
        if x0 == x1 and y0 == y1:
            break
        var e2: int = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy

static func _draw_frame(img: Image, ox: int, oy: int, row: int, frame: int, enemy: bool) -> void:
    var outline := Color("1c2628")
    var hair := Color("172328")
    var skin := Color("d7ab83")
    var coat := Color("8d4f3c") if enemy else Color("2c7771")
    var coat_light := Color("b47750") if enemy else Color("4b9d91")
    var sash := Color("d0a567")
    var cream := Color("e9d8b5")
    var steel := Color("cfe2dc")
    var blade_dark := Color("728e8d")
    var sway: int = 0 if row != 0 else (1 if frame in [2, 3] else 0)
    var stride: int = ((frame % 3) - 1) * 3 if row == 1 else 0
    var lean: int = 4 if row == 2 and frame in [2, 3] else (-4 if row == 3 and frame == 2 else 0)
    var px: int = ox + 31 + lean
    var py: int = oy + 28 + sway

    # Boots/legs alternate in the walk cycle.
    _rect(img, px - 11 + stride, oy + 63, 9, 9, outline)
    _rect(img, px + 3 - stride, oy + 63, 9, 9, outline)
    _rect(img, px - 10 + stride, oy + 55, 8, 10, Color("3b3d3b"))
    _rect(img, px + 3 - stride, oy + 55, 8, 10, Color("3b3d3b"))
    # Flowing robe with contrasting hem.
    for y in range(29):
        var half: int = 11 + (y >> 2)
        _rect(img, px - half, py + y, half * 2, 1, outline)
        _rect(img, px - half + 2, py + y, half * 2 - 4, 1, coat)
    _rect(img, px - 4, py + 15, 9, 34, cream)
    _rect(img, px - 2, py + 15, 3, 32, coat_light)
    _rect(img, px - 14, py + 11, 29, 5, sash)
    # Layered robe folds, embroidered hems and asymmetric cloak tails.
    _line(img, px - 13, py + 19, px - 17 - stride, py + 52, coat_light, 2)
    _line(img, px + 11, py + 18, px + 18 + stride, py + 53, outline, 2)
    _line(img, px - 6, py + 20, px - 8, py + 49, coat_light, 1)
    _line(img, px + 8, py + 21, px + 10, py + 48, coat_light, 1)
    _rect(img, px - 13, py + 52, 31, 3, sash)
    _rect(img, px - 7, py + 10, 15, 7, outline)
    _rect(img, px - 6, py + 11, 13, 5, sash)
    _rect(img, px, py + 11, 3, 5, Color("e5c791"))
    var ribbon_sway: int = 3 + frame % 3
    _line(img, px - 12, py + 13, px - 20 - ribbon_sway, py + 33, sash, 2)
    # Fine embroidery follows the coat rather than introducing non-pixel gradients.
    for jewel in range(3):
        _rect(img, px - 9 + jewel * 7, py + 22, 2, 2, Color("8cc1aa") if not enemy else Color("e4b07a"))
    # Arms and sleeves.
    var raised: bool = row == 2 and frame < 3 or row == 3 and frame in [0, 4]
    var arm_y: int = py - 7 if raised else py + 5
    _rect(img, px - 18, arm_y, 8, 18, outline)
    _rect(img, px - 17, arm_y + 1, 6, 15, coat_light)
    _rect(img, px + 10, arm_y, 9, 18, outline)
    _rect(img, px + 11, arm_y + 1, 7, 15, coat)
    # Neck, face, hair and topknot.
    _rect(img, px - 2, py - 11, 7, 8, skin)
    _rect(img, px - 7, py - 28, 16, 19, outline)
    _rect(img, px - 6, py - 26, 13, 16, skin)
    _rect(img, px - 7, py - 30, 17, 8, hair)
    _rect(img, px + 2, py - 36, 6, 7, hair)
    _rect(img, px + 1, py - 38, 9, 3, hair)
    _rect(img, px + 5, py - 20, 2, 2, outline)
    _rect(img, px - 3, py - 15, 4, 2, Color("b67f61"))
    if enemy:
        _rect(img, px - 3, py - 11, 12, 4, hair)
        _line(img, px + 4, py - 12, px + 7, py - 7, hair, 2)
    else:
        _rect(img, px + 1, py - 36, 3, 2, Color("76bead"))
    _line(img, px + 8, py - 22, px + 11 + frame % 2, py - 13, hair, 3)
    # Blade direction and reach encode the attack phases.
    var grip_x: int = px + 17
    var grip_y: int = arm_y + 9
    var tip_x: int = grip_x + 13
    var tip_y: int = grip_y + 13
    if row == 2:
        tip_x = [grip_x + 3, grip_x + 8, grip_x + 26, grip_x + 28, grip_x + 23, grip_x + 14][frame]
        tip_y = [grip_y - 21, grip_y - 27, grip_y - 14, grip_y, grip_y + 8, grip_y + 12][frame]
    elif row == 3 and frame in [0, 4]:
        tip_x = grip_x + 2
        tip_y = grip_y - 26
    elif row == 3 and frame in [2, 3]:
        tip_x = grip_x + 21
        tip_y = grip_y + 4
    _line(img, grip_x, grip_y, tip_x, tip_y, blade_dark, 4)
    _line(img, grip_x, grip_y, tip_x, tip_y, steel, 2)
    _line(img, grip_x - 4, grip_y - 3, grip_x + 3, grip_y + 4, sash, 3)

static func make_sheet(enemy: bool = false) -> ImageTexture:
    var image := Image.create(WIDTH * FRAMES, HEIGHT * ROWS, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    for row in range(ROWS):
        for frame in range(FRAMES):
            _draw_frame(image, frame * WIDTH, row * HEIGHT, row, frame, enemy)
    return ImageTexture.create_from_image(image)
