extends RefCounted
## Original painterly/vector wuxia characters, 6x4 transparent illustrated atlas.
## Keeps the same animation indices as the former pixel prototype.
const FRAME_W := 160
const FRAME_H := 200
const COLS := 6
const ROWS := 4
const PixelFallback = preload("res://scripts/hd2d_sprite_factory.gd")
static var _cached: Dictionary = {}

static func _frame_svg(enemy: bool, row: int, frame: int) -> String:
    var robe: String = "#a0604a" if enemy else "#266f73"
    var robe_light: String = "#d39b77" if enemy else "#69b3b1"
    var robe_dark: String = "#543832" if enemy else "#173f4e"
    var trim: String = "#dcad6e"
    var swing: float = sin(float(frame) * TAU / 6.0)
    var stride: float = swing * 7.0 if row == 1 else 0.0
    var lean: float = 7.0 if row == 2 and frame in [2, 3] else (-5.0 if row == 3 and frame == 2 else 0.0)
    var weapon_angle: float = 15.0
    if row == 2:
        weapon_angle = [-80.0, -55.0, -18.0, 30.0, 58.0, 20.0][frame]
    elif row == 3:
        weapon_angle = [-78.0, 55.0, 30.0, 55.0, -45.0, 22.0][frame]
    var suffix: String = "s" if not enemy else "d"
    var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="200" viewBox="0 0 160 200">'
    svg += '<defs>'
    svg += '<linearGradient id="cloth' + suffix + '" x1="0" y1="0" x2="1" y2="1"><stop stop-color="' + robe_light + '"/><stop offset="0.48" stop-color="' + robe + '"/><stop offset="1" stop-color="' + robe_dark + '"/></linearGradient>'
    svg += '<linearGradient id="skin" x1="0" y1="0" x2="0.9" y2="1"><stop stop-color="#f3d3ac"/><stop offset="1" stop-color="#bb8061"/></linearGradient>'
    svg += '<linearGradient id="steel" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#6e8890"/><stop offset="0.4" stop-color="#f0f3ec"/><stop offset="1" stop-color="#899da5"/></linearGradient>'
    svg += '</defs>'
    svg += '<ellipse cx="80" cy="184" rx="30" ry="6" fill="#0d1b20" opacity=".20"/>'
    svg += '<g transform="translate(' + str(lean) + ' 0)">'
    # Flowing hair, contrasting boots and moving lower robe.
    svg += '<path d="M81 34 C108 32 111 57 119 80 C102 81 97 69 85 64 Z" fill="#19262d"/>'
    svg += '<path d="M65 155 L60 181 L77 184 L85 156Z" fill="#303538"/>'
    svg += '<path d="M85 156 L' + str(96.0 + stride) + ' 181 L111 181 L100 145Z" fill="#292f34"/>'
    svg += '<path d="M60 79 Q43 103 43 149 Q39 165 28 174 Q60 185 80 163 Q105 189 131 175 Q111 130 110 90Z" fill="url(#cloth' + suffix + ')" stroke="' + robe_dark + '" stroke-width="2.4"/>'
    svg += '<path d="M68 87 Q69 121 71 162 Q81 176 91 165 L90 89Z" fill="#e4d8c5" opacity=".90"/>'
    svg += '<path d="M64 108 Q48 151 44 169 M103 107 Q119 145 122 169" fill="none" stroke="' + robe_light + '" stroke-width="2" opacity=".76"/>'
    svg += '<path d="M59 91 Q79 80 101 91 L107 119 Q79 132 54 117Z" fill="url(#cloth' + suffix + ')" stroke="' + robe_dark + '" stroke-width="2"/>'
    svg += '<path d="M58 119 Q80 126 105 119" fill="none" stroke="' + trim + '" stroke-width="7"/>'
    svg += '<path d="M81 118 L88 147" stroke="' + trim + '" stroke-width="5"/>'
    svg += '<circle cx="83" cy="120" r="5" fill="#e6c487" stroke="#775e43" stroke-width="1.5"/>'
    # Head: graphic-novel inspired smooth shading and highlighted hair strands.
    svg += '<path d="M71 65 L71 90 L88 91 L91 69Z" fill="url(#skin)"/>'
    svg += '<ellipse cx="81" cy="50" rx="19" ry="25" fill="url(#skin)" stroke="#8c5845" stroke-width="1.5"/>'
    svg += '<path d="M61 47 Q59 18 82 21 Q102 21 101 48 Q95 38 90 34 Q76 41 61 47Z" fill="#202a30"/>'
    svg += '<path d="M88 24 L90 13 Q98 7 105 16 L101 29" fill="#202a30"/>'
    svg += '<path d="M67 47 Q85 43 97 33" fill="none" stroke="#53626a" stroke-width="2" opacity=".52"/>'
    svg += '<path d="M82 55 L88 54" stroke="#283138" stroke-width="2.4" stroke-linecap="round"/>'
    svg += '<path d="M86 66 Q91 68 96 64" stroke="#9c624d" stroke-width="1.2" fill="none"/>'
    if enemy:
        svg += '<path d="M80 68 Q92 82 101 66 Q99 82 88 88 Q82 82 80 68Z" fill="#302b2b"/>'
    # Folded sleeves and sword hand; attack angle controls painted blade direction.
    svg += '<path d="M57 89 Q39 92 37 120 L51 128 L64 101Z" fill="url(#cloth' + suffix + ')" stroke="' + robe_dark + '" stroke-width="2"/>'
    svg += '<path d="M102 90 Q117 96 121 113 L112 130 L96 103Z" fill="url(#cloth' + suffix + ')" stroke="' + robe_dark + '" stroke-width="2"/>'
    svg += '<ellipse cx="114" cy="126" rx="7" ry="9" fill="url(#skin)"/>'
    svg += '<g transform="translate(114 127) rotate(' + str(weapon_angle) + ')">'
    svg += '<path d="M-6 1 L2 -1 L8 13 L1 16Z" fill="#453a32" stroke="' + trim + '" stroke-width="1"/>'
    svg += '<path d="M-12 -3 L12 1" stroke="' + trim + '" stroke-width="5" stroke-linecap="round"/>'
    svg += '<path d="M-3 0 Q-6 -40 -5 -68 L0 -81 Q7 -43 5 0Z" fill="url(#steel)" stroke="#576770" stroke-width="1"/>'
    svg += '</g></g></svg>'
    return svg

static func make_sheet(enemy: bool = false) -> Texture2D:
    var key: String = "enemy" if enemy else "hero"
    if _cached.has(key):
        return _cached[key]
    var atlas := Image.create(FRAME_W * COLS, FRAME_H * ROWS, false, Image.FORMAT_RGBA8)
    atlas.fill(Color(0, 0, 0, 0))
    for row in range(ROWS):
        for frame in range(COLS):
            var image := Image.new()
            var error: int = image.load_svg_from_string(_frame_svg(enemy, row, frame), 1.0)
            if error != OK or image.get_width() != FRAME_W or image.get_height() != FRAME_H:
                push_warning("Illustrated atlas SVG render failed; use transparent pixel fallback.")
                return PixelFallback.make_sheet(enemy)
            atlas.blit_rect(image, Rect2i(0, 0, FRAME_W, FRAME_H),
                Vector2i(frame * FRAME_W, row * FRAME_H))
    var texture: ImageTexture = ImageTexture.create_from_image(atlas)
    _cached[key] = texture
    return texture
