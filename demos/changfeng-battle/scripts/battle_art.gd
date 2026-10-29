extends RefCounted
## Original procedural ink-and-paper artwork. Draw-only: never reads or mutates game rules.
const INK = Color("243b3c")
const JADE = Color("357e77")
const GOLD = Color("c19659")
const RED = Color("c26754")
const PAPER = Color("f2eedf")

# Kenney CC0 originals: assets/kenney/ (see docs/asset-licenses.md).
# Draw-only presentation cache; simulation data and RNG are never changed.
var _textures: Dictionary={}

func _asset(relative_path: String) -> Texture2D:
	if not _textures.has(relative_path):
		var path: String="res://assets/kenney/"+relative_path
		_textures[relative_path]=load(path) as Texture2D
	return _textures[relative_path] as Texture2D

func _surface(v: CanvasItem,relative_path: String,rect: Rect2,alpha: float=1.0) -> void:
	var texture: Texture2D=_asset(relative_path)
	if texture!=null:
		v.draw_texture_rect(texture,rect,false,Color(1,1,1,alpha))


func _poly(v: CanvasItem, points: Array, color: Color) -> void:
	v.draw_colored_polygon(PackedVector2Array(points), color)

func _diamond(v: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	_poly(v, [center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)],color)

func backdrop(v: CanvasItem, t: float) -> void:
	# Layered dusk sky and distant ink ridges, painted without imported textures.
	v.draw_rect(Rect2(0,0,1600,1000),Color("e9e6d9"))
	v.draw_rect(Rect2(0,122,1600,72),Color("d9e1d6"))
	v.draw_rect(Rect2(0,194,1600,480),Color("eef0e5"))
	v.draw_circle(Vector2(1050,188),61,Color("f1d8a6"))
	v.draw_circle(Vector2(1050,188),79,Color(0.85,0.68,0.40,0.11))
	for layer in range(3):
		var ridge: Array=[Vector2(0,410+layer*55)]
		for i in range(18):
			var x: float=float(i)*96.0
			var y: float=315.0+layer*61.0+sin(float(i)*1.66+float(layer)*0.7)*34.0+cos(float(i)*0.7)*13.0
			ridge.append(Vector2(x,y))
		ridge.append(Vector2(1600,650))
		ridge.append(Vector2(0,650))
		_poly(v,ridge,Color(0.21,0.38,0.36,0.055+float(layer)*0.025))
	# Hairline paper grain is deterministic and independent of the simulation RNG.
	for i in range(95):
		var x: float=float((i*137+19)%1600)
		var y: float=float((i*71+203)%1000)
		v.draw_line(Vector2(x,y),Vector2(x+9+(i%4)*5,y),Color(0.18,0.27,0.23,0.025),1.0)

func header(v: CanvasItem, t: float) -> void:
	for i in range(7):
		var x: float=18+float(i)*11.0
		v.draw_line(Vector2(x,15),Vector2(x+24,105),Color(0.83,0.69,0.43,0.13),1)
	for i in range(7):
		var x: float=1570-float(i)*11.0
		v.draw_line(Vector2(x,15),Vector2(x-24,105),Color(0.83,0.69,0.43,0.13),1)
	v.draw_line(Vector2(82,17),Vector2(1542,17),Color(0.88,0.76,0.51,0.20),1)
	v.draw_line(Vector2(82,116),Vector2(1542,116),Color(0.88,0.76,0.51,0.26),1)
	# A seal-like monogram (abstract original mark) near the title.
	v.draw_rect(Rect2(35,37,42,49),Color(0.83,0.35,0.28,0.50),false,2)
	v.draw_line(Vector2(43,48),Vector2(68,72),Color(1,0.93,0.75,0.30),2)
	v.draw_line(Vector2(67,48),Vector2(43,73),Color(1,0.93,0.75,0.30),2)

func battlefield(v: CanvasItem, snap: Dictionary, t: float) -> void:
	# Vignette, low-contrast terrain contours, fine river ripples, and bridge inlay.
	var rect: Rect2=Rect2(24,206,1124,454)
	v.draw_rect(rect,Color("344c43"),false,2)
	v.draw_rect(Rect2(29,211,1114,444),Color(0.97,0.91,0.75,0.18),false,1)
	var origin: Vector2=Vector2(78,252)
	var tile: Vector2=Vector2(70,39)
	# Terrain decals sit over the existing authoritative board, under its overlays
	# and units. Every colored tactical/legal-target highlight remains visible.
	for cell in snap.get("terrain",{}):
		var terrain: String=str(snap.terrain[cell])
		if terrain=="water": continue
		var id: String="tile_0000.png"
		match terrain:
			"bridge": id="tile_0040.png"
			"ford": id="tile_0024.png"
			"rock": id="tile_0050.png"
			"bamboo": id="tile_0001.png"
			_: id="tile_0001.png" if (int(cell.x)+int(cell.y)*3)%7==0 else "tile_0000.png"
		var center: Vector2=origin+Vector2(cell)*tile
		_surface(v,"terrain/"+id,Rect2(center-tile*0.5+Vector2(2,2),tile-Vector2(4,4)),0.45)
		if terrain=="bamboo":
			_surface(v,"terrain/tile_0016.png",Rect2(center+Vector2(-21,-57),Vector2(42,52)),0.90)

	for i in range(13):
		var y: float=217+float(i)*36
		var points: PackedVector2Array=PackedVector2Array()
		for k in range(28):
			var x: float=39+float(k)*40
			points.append(Vector2(x,y+sin(float(k)*0.7+float(i)*0.6)*10))
		v.draw_polyline(points,Color(0.15,0.33,0.29,0.065),1.0,true)
	for row in range(10):
		var pos: Vector2=origin+Vector2(7,row)*tile
		for j in range(3):
			var y: float=pos.y-12+float(j)*11
			var drift: float=sin(t*0.8+float(row)*1.1+float(j)*1.7)*5
			v.draw_arc(Vector2(pos.x+drift,y),18,0.15,PI-0.15,16,Color(0.86,0.94,0.88,0.25),1.1,true)
	for row in [4,8]:
		var pos: Vector2=origin+Vector2(7,row)*tile
		var bridge: bool=row==4
		if bridge:
			for j in range(3):
				v.draw_line(pos+Vector2(-26,-13+j*13),pos+Vector2(26,-13+j*13),Color(0.35,0.31,0.23,0.27),1)
			for j in [-1,1]:
				v.draw_circle(pos+Vector2(float(j)*24,-16),3.5,GOLD)
				v.draw_line(pos+Vector2(float(j)*24,-16),pos+Vector2(float(j)*24,14),Color(0.40,0.28,0.17,0.36),1.3)
		else:
			for i in range(4):
				_diamond(v,pos+Vector2(float(i-2)*13,sin(float(i)*2)*6),4,Color(0.81,0.82,0.71,0.55))
	# Reeds along the banks.
	for row in range(10):
		for side in [6,8]:
			if row in [4,8]: continue
			var anchor: Vector2=origin+Vector2(side,row)*tile+Vector2(27 if side==6 else -27,10)
			for j in range(2):
				var tip: Vector2=anchor+Vector2((j-0.5)*10+sin(t*0.6+row+j)*1.5,-14-j*6)
				v.draw_line(anchor+Vector2(j*6,0),tip,Color(0.30,0.44,0.32,0.46),1.4,true)
				v.draw_line(tip,tip+Vector2(4,-4),Color(0.48,0.55,0.35,0.47),1.2,true)

func combatant(v: CanvasItem, pos: Vector2, actor: Dictionary, t: float, active: bool, hit: bool) -> void:
	var own: bool=int(actor.get("team_id",0))==0
	var direction: float=1.0 if own else -1.0
	var accent: Color=JADE if own else RED
	var cloth: Color=Color("31595c") if own else Color("704c48")
	var hem: Color=Color("6e9290") if own else Color("b57965")
	var breathe: float=sin(t*2.4+float(actor.id))*1.1
	var base: Vector2=pos+Vector2(0,breathe)
	v.draw_set_transform(pos+Vector2(0,9),0,Vector2(1.32,0.37))
	v.draw_circle(Vector2.ZERO,27,Color(0.09,0.17,0.14,0.23))
	v.draw_set_transform(Vector2.ZERO)
	v.draw_arc(pos,28,0,TAU,42,Color(accent,0.55),2,true)
	if active:
		v.draw_arc(pos,33,t*0.65,t*0.65+TAU*0.73,42,Color(GOLD,0.80),2.5,true)
		for i in range(4):
			var theta: float=t*0.6+float(i)*TAU/4.0
			_diamond(v,pos+Vector2(cos(theta),sin(theta))*34,3,Color(GOLD,0.65))
	if hit:
		v.draw_circle(base+Vector2(0,-14),29,Color(0.95,0.39,0.26,0.16))
	# A readable 16px character silhouette replaces the former procedural
	# identical robed figures. Keep the old drawing as a safe fallback.
	var sprite_ids: Array=[86,96,84,82,100,88]
	var sprite_id: int=int(sprite_ids[absi(int(actor.id))%sprite_ids.size()])
	var avatar: Texture2D=_asset("characters/tile_%04d.png" % sprite_id)
	if avatar!=null:
		v.draw_texture_rect(avatar,Rect2(base+Vector2(-29,-51),Vector2(58,66)),false)
		v.draw_rect(Rect2(pos+Vector2(-34,27),Vector2(68,18)),Color(0.92,0.91,0.84,0.88))
		v.draw_line(pos+Vector2(-33,26),pos+Vector2(33,26),Color(accent,0.70),1)
		return
	# Long hair and moving topknot.
	_poly(v,[base+Vector2(-7,-33),base+Vector2(6,-34),base+Vector2(8,-15),base+Vector2(-12,-7)],Color("263335"))
	_poly(v,[base+Vector2(-2,-34),base+Vector2(10,-36),base+Vector2(13,-5),base+Vector2(5,2)],Color("344347"))
	# Robe silhouette: narrow shoulders and split hems.
	_poly(v,[base+Vector2(-11,-24),base+Vector2(10,-26),base+Vector2(18,5),base+Vector2(7,17),base+Vector2(0,8),base+Vector2(-8,18),base+Vector2(-18,6)],cloth)
	_poly(v,[base+Vector2(-4,-24),base+Vector2(5,-24),base+Vector2(11,9),base+Vector2(1,16),base+Vector2(-9,10)],hem)
	_poly(v,[base+Vector2(-11,-21),base+Vector2(-24,-3),base+Vector2(-15,3),base+Vector2(-2,-10)],cloth.darkened(0.12))
	_poly(v,[base+Vector2(10,-21),base+Vector2(22,-7),base+Vector2(15,1),base+Vector2(1,-10)],cloth.lightened(0.18))
	v.draw_line(base+Vector2(-11,-5),base+Vector2(11,-7),Color("c4aa76"),3,true)
	v.draw_line(base+Vector2(-4,-20),base+Vector2(5,7),Color(0.94,0.90,0.74,0.67),1.5,true)
	# Face / forehead / hairline.
	v.draw_circle(base+Vector2(0,-30),9,Color("dfc09c"))
	_poly(v,[base+Vector2(-10,-33),base+Vector2(-7,-41),base+Vector2(4,-43),base+Vector2(9,-36),base+Vector2(5,-32),base+Vector2(-2,-36)],Color("253638"))
	v.draw_circle(base+Vector2(-2*direction,-29),1.1,Color("293e3b"))
	v.draw_line(base+Vector2(1,-43),base+Vector2(5*direction,-50),Color("263638"),3,true)
	# Sword: ink-black scabbard, gold guard and bright blade.
	var grip: Vector2=base+Vector2(9*direction,-16)
	var tip: Vector2=base+Vector2(37*direction,-38)
	v.draw_line(grip,tip,Color("2a4140"),5,true)
	v.draw_line(grip+Vector2(direction*6,-5),tip,Color("dfeae0"),2.5,true)
	v.draw_line(grip+Vector2(-5*direction,-4),grip+Vector2(5*direction,5),GOLD,3,true)
	v.draw_circle(grip,2,Color("e7ca86"))
	# Nameplate and hit points remain readable over the scene.
	v.draw_rect(Rect2(pos+Vector2(-34,27),Vector2(68,18)),Color(0.92,0.91,0.84,0.88))
	v.draw_line(pos+Vector2(-33,26),pos+Vector2(33,26),Color(accent,0.70),1)

func card_frame(v: CanvasItem, rect: Rect2, index: int, selected: bool, enabled: bool, card: Dictionary, t: float) -> void:
	var category: String=str(card.get("kind","reaction"))
	var accent: Color=RED if category=="attack" else (JADE if category=="move" else GOLD)
	var base: Color=Color("faf5e8") if enabled else Color("e4e5dc")
	v.draw_rect(Rect2(rect.position+Vector2(3,5),rect.size),Color(0.17,0.22,0.19,0.10))
	v.draw_rect(rect,base)
	_surface(v,"ui/panel_brown.png",rect,0.88 if enabled else 0.53)
	v.draw_rect(Rect2(rect.position,Vector2(6,rect.size.y)),accent)
	v.draw_rect(rect,Color("b4b7a2") if not selected else GOLD,false,2.5 if selected else 1.0)
	v.draw_rect(Rect2(rect.position+Vector2(9,8),rect.size-Vector2(18,16)),Color(0.67,0.60,0.42,0.21),false,1)
	# Corner fans / paper stamp.
	var corner: Vector2=rect.position+Vector2(rect.size.x-24,32)
	v.draw_arc(corner,13,0,TAU,22,Color(accent,0.25),1.3,true)
	_diamond(v,corner,7,Color(accent,0.26))
	for i in range(3):
		v.draw_line(rect.position+Vector2(14,128+i*3),rect.position+Vector2(rect.size.x-14,128+i*3),Color(accent,0.10),1)
	if bool(card.get("generated",false)):
		_diamond(v,rect.position+Vector2(rect.size.x-17,12),6,RED)
	if selected:
		var pulse: float=0.45+0.40*sin(t*4.0)
		v.draw_rect(rect.grow(3),Color(GOLD,pulse),false,2.0)
		for p in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			_diamond(v,p,3,GOLD)

func burst(v: CanvasItem, snap: Dictionary, cues: Array, positions: Array, t: float) -> void:
	for cue in cues:
		var total: float=float(cue.get("duration",0.7))
		var progress: float=clampf(1.0-float(cue.get("left",0.0))/maxf(0.01,total),0.0,1.0)
		var alpha: float=pow(1.0-progress,1.5)
		if alpha<=0: continue
		var kind: String=str(cue.get("kind",""))
		var target: int=int(cue.get("target_id",-1))
		var source: int=int(cue.get("source_id",-1))
		if target<0 or target>=positions.size(): continue
		var pos: Vector2=positions[target]+Vector2(0,-18)
		var warm: Color=RED if kind=="damage" else (GOLD if kind in ["attack","combo"] else JADE)
		if kind in ["damage","attack","combo"]:
			var size: float=23.0+progress*62.0
			v.draw_arc(pos,size*.52,-1.1+progress*1.1,1.8+progress*1.1,36,Color(warm,0.70*alpha),4.5*(1.0-progress)+0.6,true)
			v.draw_line(pos+Vector2(-size*.8,size*.38),pos+Vector2(size*.8,-size*.48),Color(0.99,0.91,0.68,0.80*alpha),5.5*(1-progress)+1.0,true)
			for i in range(9):
				var theta: float=float(i)*TAU/9.0+0.24
				var spread: float=14.0+progress*(35.0+float(i%3)*10.0)
				var p: Vector2=pos+Vector2(cos(theta),sin(theta))*spread
				_diamond(v,p,2.2+float(i%3),Color(warm,alpha*.8))
			if source>=0 and source<positions.size() and kind=="attack":
				var start: Vector2=positions[source]+Vector2(0,-22)
				var end: Vector2=start.lerp(pos,clampf(progress*1.5,0,1))
				v.draw_line(start,end,Color(0.96,0.78,0.50,0.65*alpha),3.0,true)
		elif kind=="guard":
			v.draw_arc(pos,29+progress*22,PI*1.12,PI*1.90,30,Color(JADE,0.75*alpha),4,true)
			v.draw_arc(pos,35+progress*18,PI*1.05,PI*1.95,30,Color(GOLD,0.45*alpha),1.4,true)
		elif kind=="evade":
			for i in range(3):
				var trail: float=14.0+float(i)*11.0+progress*22.0
				v.draw_line(pos+Vector2(-trail,-12+i*8),pos+Vector2(-trail+19,-12+i*8),Color(JADE,0.66*alpha),2.3,true)
