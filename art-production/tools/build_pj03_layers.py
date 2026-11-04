#!/usr/bin/env python3
"""Build original, coordinate-aligned PJ-03 vector layers (not raster splits).

The concept WebP remains a candidate reference. These authored shapes are
separate drawable layers with transparent pixels outside their own geometry.
"""
from pathlib import Path
import html

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "demos/changfeng-battle/assets/imported/scenes/pingjiang_riverside_market"
SIZE = (4800, 1000)


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="4800" height="1000" '
            'viewBox="0 0 4800 1000">\n' + body + '\n</svg>\n')


def rect(x, y, w, h, fill, extra=''):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" {extra}/>'


def path(d, fill, extra=''):
    return f'<path d="{d}" fill="{fill}" {extra}/>'


def text(x, y, label, size=42, color='#49392f'):
    return (f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" '
            'font-family="serif" text-anchor="middle">' + html.escape(label) + '</text>')


def shop(x, width, name, accent):
    y = 275
    parts = [rect(x, y + 68, width, 255, '#eee4cc'),
             rect(x + 20, y + 99, width - 40, 212, '#c7b598'),
             rect(x + 34, y + 111, width - 68, 197, '#685044'),
             rect(x + 45, y + 128, width - 90, 166, '#8b6b4e'),
             path(f'M{x-25} {y+82} L{x+width/2} {y-50} L{x+width+25} {y+82} Z', '#333b3a'),
             path(f'M{x-9} {y+77} L{x+width/2} {y-28} L{x+width+9} {y+77} Z', '#495350'),
             rect(x - 20, y + 76, width + 40, 19, '#293b3b'),
             rect(x + width * .22, y + 123, width * .56, 58, accent),
             text(x + width/2, y + 168, name, 39, '#fff0cf')]
    for px in [x + 58, x + width - 58]:
        parts.extend([rect(px, y + 180, 14, 132, '#392c26'),
                      rect(px - 12, y + 189, 38, 9, '#d8bd83')])
    for px in range(x + 55, x + width - 30, 81):
        parts.append(path(f'M{px} {y+208} l35 0 l-10 74 l-25 0 Z', '#b99a72', 'opacity=".6"'))
    return '\n'.join(parts)


def background():
    p = ['<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#d4d7c8"/>'
         '<stop offset="1" stop-color="#efdfbd"/></linearGradient></defs>',
         rect(0, 0, 4800, 1000, '#d5cbb5'), rect(0, 0, 4800, 335, 'url(#sky)')]
    # Distinct stepped city skyline; water sits beyond the road, never under it.
    for i in range(0, 4800, 155):
        roof = 260 + (i * 7 % 53)
        p.extend([rect(i, roof, 170, 205, '#b8b2a2'),
                  path(f'M{i-13} {roof+14} l98 -52 l100 52 Z', '#62716b')])
    p.extend([rect(0, 465, 4800, 116, '#62827e'),
              rect(0, 520, 4800, 49, '#719493'),
              path('M0 570 Q800 550 1600 570 T3200 570 T4800 570 L4800 596 L0 596Z', '#aaad91'),
              rect(0, 564, 4800, 19, '#a9a28b')])
    # Bankside structures sit above the walkable street band.
    p.extend([shop(240, 400, '河埠', '#6c584b'), shop(780, 370, '水闸', '#587074'),
              shop(1730, 390, '淬锋堂', '#8e573c'), shop(2510, 390, '百草堂', '#657a58'),
              shop(3400, 390, '水市茶棚', '#997a47'), shop(3980, 410, '杂货行', '#826248')])
    # Tethered boats and timber pier are scenery and never walkable.
    for x in [60, 1260, 3070, 4490]:
        p.extend([path(f'M{x} 493 q130 44 280 0 l-45 59 l-195 0 Z', '#473e34'),
                  path(f'M{x+130} 486 l0 -114 l100 100 Z', '#dfcaa8'),
                  rect(x + 120, 375, 7, 119, '#443d33')])
    for x in [100, 1450, 3180, 4610]:
        p.extend([rect(x, 490, 14, 95, '#5d5344'), rect(x - 24, 486, 61, 12, '#8e795a')])
    return '\n'.join(p)


def ground():
    p = ['<defs><linearGradient id="road" x2="0" y2="1"><stop stop-color="#a6a69a"/>'
         '<stop offset="1" stop-color="#b8ae98"/></linearGradient></defs>',
         rect(0, 585, 4800, 355, 'url(#road)'),
         rect(0, 584, 4800, 13, '#6d766b'),
         rect(0, 933, 4800, 18, '#7d8273')]
    # Continuous paving coordinates across x=1600 and x=3200.
    for y in range(606, 940, 39):
        p.append(rect(0, y, 4800, 2, '#747b72', 'opacity=".36"'))
        offset = 0 if (y // 39) % 2 else 49
        for x in range(-offset, 4800, 98):
            p.append(rect(x, y + 2, 2, 37, '#70776f', 'opacity=".23"'))
    for x in [480, 1520, 2250, 2810, 3630, 4350]:
        p.append(path(f'M{x-85} 595 l170 0 l30 29 l-230 0 Z', '#b6aa91'))
    # South branch at middle is a navigable route, not an actual art swap.
    p.extend([rect(2260, 897, 280, 46, '#b9b2a1', 'opacity=".48"'),
              path('M2255 926 l280 0', 'none', 'stroke="#696d62" stroke-width="4"')])
    return '\n'.join(p)


def foreground():
    p = []
    # Separate transparent hanging eaves/lanterns, raised at z=110 to occlude actor.
    for x in [550, 1020, 1990, 2730, 3650, 4210]:
        p.extend([rect(x - 94, 507, 188, 21, '#3a4846'),
                  path(f'M{x-116} 507 q116 -67 232 0 Z', '#485652'),
                  rect(x - 4, 524, 8, 61, '#5e4b3d'),
                  path(f'M{x-22} 586 q22 -14 44 0 l-5 50 q-17 17 -34 0 Z', '#b46e44'),
                  rect(x - 24, 580, 48, 9, '#d4a469')])
    # Low riverside rails below the walk plane; this overlays character feet
    # only when actor moves near the southern edge.
    for x in range(0, 4800, 200):
        p.append(rect(x, 944, 15, 56, '#514d43'))
    p.append(rect(0, 960, 4800, 12, '#726a58'))
    return '\n'.join(p)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for layer, builder in [('background', background), ('ground', ground),
                           ('foreground', foreground)]:
        (OUT / (layer + '.svg')).write_text(svg(builder()), encoding='utf-8')
    print(f'Created 3 original, 4800x1000 aligned SVG layers in {OUT}')


if __name__ == '__main__':
    main()
