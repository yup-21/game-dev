extends RefCounted
## Presentation-only pixel artwork. All pattern offsets are deterministic; no gameplay RNG.
const INK = Color("243f40")
const PAPER = Color("eee9da")
const JADE = Color("4d8176")
const GOLD = Color("b9935d")
const RED = Color("a95b50")
const SHEETS = [
	preload("res://assets/ninja_adventure/characters/changfeng.png"),
	preload("res://assets/ninja_adventure/characters/interceptor.png"),
	preload("res://assets/ninja_adventure/characters/qingshuang.png"),
	preload("res://assets/ninja_adventure/characters/scholar.png"),
	preload("res://assets/ninja_adventure/characters/guard.png"),
	preload("res://assets/ninja_adventure/characters/assassin.png")
]
const GROUND = preload("res://assets/ninja_adventure/environment/ground.png")
const PANEL = preload("res://assets/ninja_adventure/ui/panel.png")
const PORTRAITS = [
	preload("res://assets/ninja_adventure/portraits/changfeng.png"),
	preload("res://assets/ninja_adventure/portraits/interceptor.png"),
	preload("res://assets/ninja_adventure/portraits/qingshuang.png"),
	preload("res://assets/ninja_adventure/portraits/scholar.png"),
	preload("res://assets/ninja_adventure/portraits/guard.png"),
	preload("res://assets/ninja_adventure/portraits/assassin.png")
]
static var palettes: Dictionary = {}

func _sheet(variant: int) -> Texture2D:
	var key: int=posmod(variant,6)
	if palettes.has(key): return palettes[key]
	var source: int=key
	var accent: Color=[JADE,RED,Color("718a89"),Color("8b8962"),Color("8a6070"),Color("b37b57")][key]
	var image: Image=SHEETS[source].get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color=image.get_pixel(x,y)
			if c.a<0.01: continue
			var light: float=c.get_luminance()
			var mapped: Color
			if c.r>c.g*1.12 and c.g>c.b*1.12 and light>0.29:
				mapped=Color("bd9374").lerp(Color("ead7ad"),clampf(light,0,1))
			elif light<0.12:
				mapped=INK.darkened(0.32)
			elif c.s>0.18:
				mapped=accent.darkened(0.45).lerp(accent.lightened(0.4),clampf(light*1.3,0,1))
			else:
				mapped=INK.lerp(PAPER,clampf(light*1.1,0,1))
			mapped.a=c.a
			image.set_pixel(x,y,mapped)
	var texture: ImageTexture=ImageTexture.create_from_image(image)
	palettes[key]=texture
	return texture

func character(v: CanvasItem, foot: Vector2, variant: int, t: float, pose: String="idle", scale_factor: float=3.0, flip: bool=false, tint: Color=Color.WHITE, facing: int=-1) -> void:
	var row: int=0
	match pose:
		"walk": row=posmod(int(t*7),4)
		"attack", "guard": row=4
		"hurt": row=5
		"dead": row=6
	var direction: int=2 if flip else 3
	if pose in ["idle","hurt","dead"]: direction=0
	if facing>=0 and pose!="dead": direction=clampi(facing,0,3)
	var anchor: Vector2=foot.round()
	var step: float=2.0 if pose=="walk" and row%2==1 else 0.0
	var s: float=maxf(1.0,roundf(scale_factor))
	v.draw_rect(Rect2(anchor+Vector2(-7*s,-s),Vector2(14*s,2*s)),Color(INK,0.17*tint.a))
	v.draw_rect(Rect2(anchor+Vector2(-5*s,-2*s),Vector2(10*s,4*s)),Color(INK,0.08*tint.a))
	var destination: Rect2=Rect2(anchor-Vector2(8*s,15*s+step),Vector2(16*s,16*s))
	v.draw_texture_rect_region(_sheet(variant),destination,Rect2(direction*16,row*16,16,16),tint)
	# The source has one attack pose. A stepped blade and sleeve motion supply its timing.
	if pose=="attack":
		var sign_x: float=-1.0 if flip else 1.0
		var start: Vector2=anchor+Vector2(sign_x*5*s,-7*s)
		for i in range(6):
			var blade: Vector2=start+Vector2(sign_x*float(i)*s,-float(i)*s)
			v.draw_rect(Rect2(blade,Vector2(s*2,s)),Color(PAPER,tint.a))
		v.draw_rect(Rect2(start-Vector2(s,s),Vector2(s*3,s*2)),Color(GOLD,tint.a))

func portrait(v: CanvasItem, rect: Rect2, variant: int) -> void:
	v.draw_texture_rect(PORTRAITS[posmod(variant,6)],rect,false,Color("cbd0b8"))

func landscape(v: CanvasItem, rect: Rect2, t: float, night: bool=false) -> void:
	var sky: Color=Color("cbd5c8") if not night else Color("a1b4ad")
	v.draw_rect(rect,sky)
	# Render only the world on a coarse grid; the UI text keeps its native resolution.
	for layer in range(4):
		var shade: Color=Color("7d9c90").lerp(INK,float(layer)/4.4)
		shade.a=0.24+float(layer)*0.12
		var base: float=rect.position.y+rect.size.y*(0.33+float(layer)*0.12)
		for x in range(0,int(rect.size.x)+12,12):
			var world_x: float=float(x)+rect.position.x
			var wave: float=sin(float(x)*0.008+float(layer)*2.7)*rect.size.y*0.13+cos(float(x)*0.017+float(layer))*rect.size.y*0.045
			var top: float=snappedf(base+wave,8.0)
			v.draw_rect(Rect2(world_x,top,12,rect.end.y-top),shade)
	var moon: Vector2=rect.position+rect.size*Vector2(0.79,0.18)
	for y in range(-8,9):
		var half_width: float=floor(sqrt(maxf(0,64.0-float(y*y))))*6
		v.draw_rect(Rect2(moon+Vector2(-half_width,y*6),Vector2(half_width*2,6)),Color("e1d1a1") if not night else Color("d5d1b1"))
	for i in range(13):
		var x: float=rect.position.x+float((i*137)%maxi(1,int(rect.size.x)))
		var y: float=rect.position.y+rect.size.y*(0.48+float(i%4)*0.11)
		var drift: float=snappedf(sin(t*0.15+float(i))*14.0,2.0)
		v.draw_rect(Rect2(x+drift,y,100+float(i%3)*44,4),Color(PAPER,0.12))

func terrain(v: CanvasItem, center: Vector2, cell_size: Vector2, kind: String, seed: int, t: float) -> void:
	var rect: Rect2=Rect2((center-cell_size*0.5).round(),cell_size.round())
	match kind:
		"water":
			v.draw_rect(rect,Color("7caaa5"))
			for line in range(3):
				var shift: float=float(posmod(seed*7+line*13+int(t*3),int(maxf(1,cell_size.x-20))))
				v.draw_rect(Rect2(rect.position+Vector2(shift,8+line*12),Vector2(13+line*3,2)),Color("b5d0bc"))
				v.draw_rect(Rect2(rect.position+Vector2(shift+8,11+line*12),Vector2(6,2)),Color("648f8e"))
		"bridge":
			v.draw_rect(rect,Color("ae9c7a"))
			for x in range(3,int(cell_size.x),10):
				v.draw_rect(Rect2(rect.position+Vector2(x,2),Vector2(7,cell_size.y-4)),Color("c5b18a") if x%3==0 else Color("bbaa86"))
			v.draw_rect(Rect2(rect.position+Vector2(0,2),Vector2(cell_size.x,3)),Color("796d56"))
			v.draw_rect(Rect2(rect.end-Vector2(cell_size.x,5),Vector2(cell_size.x,3)),Color("796d56"))
		"ford":
			terrain(v,center,cell_size,"water",seed,t)
			for i in range(3):
				var p: Vector2=center+Vector2((i-1)*18,((i+seed)%2)*6-3)
				v.draw_rect(Rect2(p-Vector2(7,4),Vector2(14,8)),Color("aeb8a4"))
				v.draw_rect(Rect2(p-Vector2(5,4),Vector2(10,2)),Color("d3d2b6"))
		_:
			v.draw_rect(rect,Color("c6ccb3") if seed%3==0 else Color("cfd1b8"))
			# The muted CC0 ground tile lends texture without obscuring legal-cell outlines.
			v.draw_texture_rect_region(GROUND,rect,Rect2(112,112,16,16),Color(0.73,0.81,0.67,0.19))
			for i in range(4):
				var x: float=float(posmod(seed*17+i*19,int(maxf(1,cell_size.x-8))))
				var y: float=float(posmod(seed*11+i*7,int(maxf(1,cell_size.y-6))))
				v.draw_rect(Rect2(rect.position+Vector2(x+3,y+3),Vector2(4,2)),Color("99ad90"))
			if kind=="rock":
				v.draw_rect(Rect2(center+Vector2(-23,4),Vector2(46,10)),Color(INK,0.17))
				v.draw_rect(Rect2(center+Vector2(-23,-8),Vector2(46,19)),Color("7b9083"))
				v.draw_rect(Rect2(center+Vector2(-15,-18),Vector2(31,28)),Color("8fa295"))
				v.draw_rect(Rect2(center+Vector2(-12,-18),Vector2(23,5)),Color("b6bfaa"))
				v.draw_rect(Rect2(center+Vector2(5,-10),Vector2(4,18)),Color("6e8278"))
				v.draw_rect(Rect2(center+Vector2(-19,7),Vector2(14,4)),Color("708b62"))
			elif kind=="bamboo":
				for i in range(3):
					var p: Vector2=center+Vector2((i-1)*9,10)
					v.draw_rect(Rect2(p-Vector2(2,28+i*3),Vector2(4,28+i*3)),Color("54796a"))
					for j in range(3):
						v.draw_rect(Rect2(p+Vector2(-8 if j%2==0 else 0,-12-j*7),Vector2(10,3)),Color("6d9174"))
	v.draw_rect(rect,Color(INK,0.1),false,1.0)

func panel(v: CanvasItem, rect: Rect2, dark: bool=false, accent: Color=GOLD) -> void:
	v.draw_rect(Rect2(rect.position+Vector2(4,5),rect.size),Color(INK,0.12))
	v.draw_rect(rect,Color("254849") if dark else Color("f0ecdd"))
	v.draw_rect(rect,accent,false,2)
	v.draw_rect(rect.grow(-5),Color(accent,0.2),false,1)
	# CC0 pixel corner ornament, with native-size pixels enlarged to 2x.
	for corner in [Vector2.ZERO,Vector2(rect.size.x-8,0),Vector2(0,rect.size.y-8),rect.size-Vector2(8,8)]:
		v.draw_texture_rect_region(PANEL,Rect2(rect.position+corner,Vector2(8,8)),Rect2(0,0,4,4),Color(0.77,0.78,0.57,0.58))
	for i in range(int(rect.size.x/35.0)):
		var x: float=rect.position.x+12+float(i)*35
		v.draw_rect(Rect2(x,rect.end.y-9,7,1),Color(PAPER if dark else INK,0.04))

func badge(v: CanvasItem, rect: Rect2, kind: String, accent: Color) -> void:
	var c: Vector2=rect.get_center().round()
	var block: float=maxf(2.0,floorf(minf(rect.size.x,rect.size.y)/12.0))
	if kind in ["move","evade"]:
		for i in range(4): v.draw_rect(Rect2(c+Vector2((i-2)*block,-i*block),Vector2(block*3,block)),accent)
	elif kind in ["guard","reaction","defend"]:
		v.draw_rect(Rect2(c-Vector2(block*3,block*4),Vector2(block*6,block*6)),accent)
		v.draw_rect(Rect2(c+Vector2(-block*2,block*2),Vector2(block*4,block)),accent)
		v.draw_rect(Rect2(c+Vector2(-block,block*3),Vector2(block*2,block)),accent)
		v.draw_rect(Rect2(c-Vector2(block,block*3),Vector2(block,block*5)),PAPER)
	else:
		for i in range(7): v.draw_rect(Rect2(c+Vector2((i-3)*block,(2-i)*block),Vector2(block*2,block)),accent)
		v.draw_rect(Rect2(c+Vector2(-block*4,block),Vector2(block*5,block)),GOLD)

func effect(v: CanvasItem, center: Vector2, kind: String, progress: float, scale_factor: float=1.0) -> void:
	var p: float=clampf(progress,0,1)
	var alpha: float=1.0-p
	var accent: Color=GOLD if kind in ["attack","combo"] else (RED if kind in ["damage","hurt"] else JADE)
	var unit: float=maxf(2,roundf(3*scale_factor))
	if kind=="guard":
		for i in range(12):
			var angle: float=PI+float(i)*PI/11.0
			var offset: Vector2=Vector2(cos(angle),sin(angle))*(25+p*16)*scale_factor
			v.draw_rect(Rect2((center+offset).snapped(Vector2(unit,unit)),Vector2(unit*2,unit)),Color(accent,alpha))
	elif kind=="evade":
		for i in range(4):
			v.draw_rect(Rect2(center+Vector2(-38-i*7-p*20,-18+i*7),Vector2(19,unit)),Color(INK,alpha*(0.5-float(i)*0.08)))
	else:
		for i in range(13):
			var phase: float=float(i)/12.0
			var offset: Vector2=Vector2(-34+phase*68,21-phase*53+sin(phase*PI)*12)*scale_factor
			v.draw_rect(Rect2((center+offset).snapped(Vector2(unit,unit)),Vector2(unit*3,unit*(1.0+sin(phase*PI)*2))),Color(accent,alpha))
			v.draw_rect(Rect2((center+offset+Vector2(0,-unit)).snapped(Vector2(unit,unit)),Vector2(unit*2,unit)),Color(PAPER,alpha*0.9))
		for i in range(9):
			var theta: float=float(i)*TAU/9.0+0.4
			var offset: Vector2=Vector2(cos(theta),sin(theta))*(16+p*(27+float(i%3)*8))*scale_factor
			v.draw_rect(Rect2((center+offset).snapped(Vector2(unit,unit)),Vector2(unit,unit)),Color(accent,alpha))
