extends RefCounted
## Draw-only ink and pixel presentation; authoritative events supply every combat cue.
const Pixel = preload("res://scripts/ink_pixel_art.gd")
const INK = Color("243b3c")
const JADE = Color("357e77")
const GOLD = Color("c19659")
const RED = Color("c26754")
const PAPER = Color("f2eedf")
var pixel = Pixel.new()
var _poses: Dictionary = {}

func _diamond(v: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	v.draw_rect(Rect2((center-Vector2(radius,radius)).round(),Vector2(radius*2,radius*2)),color)

func _corners(v: CanvasItem, rect: Rect2, color: Color, width: float = 2.0) -> void:
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var inward: Vector2=Vector2(1 if corner.x==rect.position.x else -1,1 if corner.y==rect.position.y else -1)
		v.draw_line(corner,corner+Vector2(inward.x*9,0),color,width)
		v.draw_line(corner,corner+Vector2(0,inward.y*9),color,width)

func backdrop(v: CanvasItem, t: float) -> void:
	pixel.landscape(v,Rect2(0,0,1600,1000),t)

func header(v: CanvasItem, _t: float) -> void:
	v.draw_line(Vector2(82,17),Vector2(1542,17),Color(GOLD,0.28),2)
	v.draw_line(Vector2(82,116),Vector2(1542,116),Color(GOLD,0.38),2)
	for x in [24,1564]:
		for i in range(4):
			v.draw_rect(Rect2(x,28+i*19,4,10),Color(GOLD,0.35))

func battlefield(v: CanvasItem, snap: Dictionary, t: float) -> void:
	pixel.panel(v,Rect2(24,206,1124,454),false,JADE)
	var origin: Vector2=Vector2(78,252)
	var tile: Vector2=Vector2(70,39)
	for cell in snap.get("terrain",{}):
		pixel.terrain(v,origin+Vector2(cell)*tile,tile,str(snap.terrain[cell]),int(cell.x)+int(cell.y)*15,t)
	_corners(v,Rect2(29,211,1114,444),Color(GOLD,0.75))

func combatant(v: CanvasItem, pos: Vector2, actor: Dictionary, t: float, active: bool, hit: bool, pose_override: String = "") -> void:
	var friendly: bool=int(actor.get("team_id",actor.get("id",0)))==0
	var accent: Color=JADE if friendly else RED
	var alive: bool=float(actor.get("hp",0))>0
	var tint: Color=Color.WHITE if alive else Color(0.55,0.58,0.55,0.58)
	var pose: String=pose_override if not pose_override.is_empty() else str(_poses.get(int(actor.get("id",0)),"idle"))
	if hit: pose="hurt"
	if not alive: pose="dead"
	v.draw_rect(Rect2((pos+Vector2(-20,7)).round(),Vector2(40,8)),Color(INK,0.18))
	v.draw_rect(Rect2((pos+Vector2(-23,12)).round(),Vector2(46,3)),accent)
	if active:
		_corners(v,Rect2(pos+Vector2(-31,-19),Vector2(62,43)),GOLD,3)
		v.draw_rect(Rect2(pos+Vector2(-3,19),Vector2(6,6)),GOLD)
	pixel.character(v,pos+Vector2(0,12),int(actor.get("id",0)),t,pose,3.0,not friendly,tint)
	# The caller places HP above the 48px sprite and names below its feet.
	pixel.panel(v,Rect2(pos+Vector2(-38,26),Vector2(76,20)),false,accent)

func card_frame(v: CanvasItem, rect: Rect2, _index: int, selected: bool, enabled: bool, card: Dictionary, t: float) -> void:
	var category: String=str(card.get("kind","reaction"))
	var accent: Color=RED if category=="attack" else (JADE if category=="move" else GOLD)
	v.draw_rect(Rect2(rect.position+Vector2(3,5),rect.size),Color(INK,0.12))
	pixel.panel(v,rect,false,accent)
	v.draw_rect(Rect2(rect.position,Vector2(5,rect.size.y)),accent)
	v.draw_rect(Rect2(rect.position+Vector2(9,8),rect.size-Vector2(18,16)),Color(accent,0.22),false,1)
	if not enabled: v.draw_rect(rect,Color(0.55,0.58,0.52,0.18))
	var badge: String="sword" if category=="attack" else ("move" if category=="move" else "guard")
	pixel.badge(v,Rect2(rect.end.x-38,rect.position.y+13,23,23),badge,accent)
	if bool(card.get("generated",false)):
		_diamond(v,rect.position+Vector2(rect.size.x-12,10),4,RED)
	if selected:
		v.draw_rect(rect.grow(3),Color(GOLD,0.6+0.25*sin(t*4.0)),false,2)
		_corners(v,rect.grow(5),GOLD,3)

func burst(v: CanvasItem, _snap: Dictionary, cues: Array, positions: Array, _t: float) -> void:
	# This legacy interface belongs to the two-slot duel view only.
	_poses.clear()
	for cue in cues:
		var total: float=float(cue.get("duration",0.65))
		var progress: float=clampf(1.0-float(cue.get("left",0.0))/maxf(0.01,total),0.0,1.0)
		var kind: String=str(cue.get("kind",""))
		var target: int=int(cue.get("target_id",-1))
		var source: int=int(cue.get("source_id",-1))
		if target<0 or target>=positions.size(): continue
		var pos: Vector2=positions[target]+Vector2(0,-12)
		if source>=0 and source<positions.size() and kind=="attack":
			var start: Vector2=positions[source]
			_poses[source]="attack"
			pixel.effect(v,start.lerp(pos,clampf(progress*2.2,0,1)),"attack",progress,0.9)
		elif kind in ["guard","damage"]:
			_poses[target]="guard" if kind=="guard" else "hurt"
		pixel.effect(v,pos,kind,progress,0.9)
