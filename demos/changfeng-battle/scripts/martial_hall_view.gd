extends Node2D
## Scroll-free 1600×1000 martial encyclopedia, progression, breakthroughs and branches.
const Martial=preload("res://scripts/martial_progression.gd")
const BG=Color("eae5d6")
const PAPER=Color("f8f4e8")
const INK=Color("2b4540")
const JADE=Color("3a7e73")
const GOLD=Color("bd9658")
const RED=Color("a85b4d")
var font: SystemFont
var martial=Martial.new()
var selected: String="taixu"
var buttons: Array=[]
var skill_icons: Texture2D
const SKILL_ICONS_PATH="res://assets/third_party/oga_cc0/rpg_skill_tree_icons.png"
var message: String=""

func _ready() -> void:
	if ResourceLoader.exists(SKILL_ICONS_PATH):
		skill_icons=load(SKILL_ICONS_PATH) as Texture2D
	font=SystemFont.new()
	font.font_names=PackedStringArray(["KaiTi","Noto Sans CJK SC","Microsoft YaHei"])
	var session=_session()
	if session!=null and not session.martial_records.get(0,{}).has(selected):
		for id in session.martial_records.get(0,{}):
			if martial.catalog.has(id): selected=str(id); break

func _session():
	return get_node_or_null("/root/GameSession")

func _go(path: String) -> void:
	var err: int=get_tree().change_scene_to_file(path)
	if err!=OK: message="场景无法打开："+path

func _act(action: String) -> void:
	var session=_session()
	if session==null: return
	if action=="back":
		call_deferred("_go",session.return_from_management())
	elif action=="inventory":
		session.open_management("res://martial_hall.tscn")
		call_deferred("_go","res://inventory.tscn")
	elif action=="save":
		session.open_management("res://martial_hall.tscn")
		call_deferred("_go","res://save_slots.tscn")
	elif action.begins_with("select:"):
		selected=action.substr(7)
	elif action=="breakthrough":
		message="突破成功，武学境界提升" if session.breakthrough_martial(selected) else "熟练度不足、已至化境，或暂不可突破"
	elif action.begins_with("trait:"):
		message="武意分支已领悟" if session.choose_martial_trait(selected,action.substr(6)) else "尚未达到大成境界或已选择武意"
	elif action.begins_with("train:"):
		var attr: String=action.substr(6)
		message=attr+" 修炼成功" if session.allocate_training_point(attr) else "暂无可用属性点或未在结算阶段"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: _act("back")
		if event.keycode==KEY_F5: _act("save")
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for entry in buttons:
			if entry.rect.has_point(event.position):
				_act(str(entry.action))
				return

func _txt(pos: Vector2,s: String,size: int=18,color: Color=INK) -> void:
	draw_string(font,pos,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _button(rect: Rect2,label: String,action: String,enabled: bool=true) -> void:
	draw_rect(rect,JADE if enabled else Color("a7aea5"))
	draw_rect(rect,GOLD,false,2)
	_txt(rect.position+Vector2(13,rect.size.y/2+7),label,17,PAPER)
	if enabled: buttons.append({"rect":rect,"action":action})

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color("304740"))
	draw_rect(Rect2(45,44,1510,913),BG)
	draw_rect(Rect2(59,60,1482,885),GOLD,false,2)
	_txt(Vector2(101,131),"武学演武堂 · 参悟与突破",42,INK)
	var session=_session()
	if session==null: return
	var records: Dictionary=session.martial_records.get(0,{})
	var entries: Array=martial.catalog.keys()
	entries.sort()
	draw_rect(Rect2(82,191,294,657),PAPER)
	_txt(Vector2(106,237),"武学图鉴",28,JADE)
	for index in range(entries.size()):
		var id: String=str(entries[index])
		var definition: Dictionary=martial.discipline(id)
		var has_skill: bool=records.has(id)
		var rect: Rect2=Rect2(102,266+index*102,254,85)
		_button(rect,("◆ " if selected==id else "")+str(definition.name),"select:"+id)
		_txt(rect.position+Vector2(15,73),"已习得" if has_skill else "尚未习得",14,GOLD if has_skill else RED)
	draw_rect(Rect2(399,191,760,657),PAPER)
	var definition: Dictionary=martial.discipline(selected)
	if definition.is_empty(): return
	var record: Dictionary=records.get(selected,{})
	var rank: int=int(record.get("rank",0))
	var xp: int=int(record.get("xp",0))
	_txt(Vector2(434,244),str(definition.name),35,JADE)
	_txt(Vector2(435,281),str(definition.school)+" · "+("尚未习得" if rank==0 else "当前 %d 重 · %s" % [rank,str(definition.tiers[rank-1].title)]),20,INK)
	_txt(Vector2(435,316),str(definition.intro).substr(0,33),16,INK)
	# Full five-rank roadmap with threshold and effective bonuses.
	for index in range(mini(5,definition.tiers.size())):
		var tier: Dictionary=definition.tiers[index]
		var x: float=432+index*143.0
		var rect: Rect2=Rect2(x,359,134,115)
		draw_rect(rect,Color("d0e0d2") if rank>=index+1 else Color("e8e5d9"))
		if skill_icons!=null:
			var region: Rect2=Rect2(float(index%4)*16.0,0,16,16)
			draw_texture_rect_region(skill_icons,Rect2(x+52,446,28,28),region,Color.WHITE if rank>=index+1 else Color(0.67,0.67,0.67,0.8))
		draw_rect(rect,GOLD if rank==index+1 else Color("b6b7a9"),false,2)
		_txt(Vector2(x+9,384),"%d · %s" % [index+1,str(tier.title)],18,INK)
		_txt(Vector2(x+9,408),"已领悟" if rank>=index+1 else "未突破",15,JADE if rank>=index+1 else RED)
		_txt(Vector2(x+9,441),"门槛 %d XP" % (0 if index==0 else int(Martial.RANK_THRESHOLDS[index])),13,INK)
	_txt(Vector2(436,519),"修炼熟练度：%d XP" % xp,23,INK)
	var required: int=int(Martial.RANK_THRESHOLDS[rank]) if rank>0 and rank<5 else 0
	draw_rect(Rect2(439,535,665,20),Color("c6c6ba"))
	draw_rect(Rect2(439,535,665*clampf(float(xp)/maxf(1.0,float(required)),0,1),20),JADE)
	if rank>0 and rank<5:
		_txt(Vector2(435,592),"下一重突破需要 %d XP" % required,20,INK)
		_button(Rect2(798,564,299,50),"突破至第%d重" % (rank+1),"breakthrough",xp>=required)
	elif rank>=5: _txt(Vector2(436,590),"武学已臻化境",22,GOLD)
	else: _txt(Vector2(436,590),"此武学尚待江湖机缘领悟",20,RED)
	_txt(Vector2(436,642),"招式与效果",26,JADE)
	for index in range(mini(3,definition.techniques.size())):
		var node: Dictionary=definition.techniques[index]
		_txt(Vector2(437,683+index*48),str(node.name)+" · "+str(node.text).substr(0,26),18,INK)
	# Right sidebar offers breakthrough branches and actual training actions.
	draw_rect(Rect2(1184,191,331,657),PAPER)
	_txt(Vector2(1205,240),"武意抉择",29,JADE)
	var chosen: Array=record.get("traits",[])
	var y: int=271
	for trait_entry in definition.get("traits",[]):
		draw_rect(Rect2(1203,y,292,132),Color("e7e4d6"))
		_txt(Vector2(1214,y+29),str(trait_entry.name),21,INK)
		_txt(Vector2(1214,y+56),str(trait_entry.description),16,INK)
		if chosen.has(str(trait_entry.id)):
			_txt(Vector2(1214,y+103),"已选择此武意",18,JADE)
		else:
			_button(Rect2(1212,y+72,267,41),"领悟 · 第%d重" % int(trait_entry.required_rank),"trait:"+str(trait_entry.id),rank>=int(trait_entry.required_rank) and chosen.is_empty())
		y+=146
	_txt(Vector2(1209,617),"永久属性修炼",25,JADE)
	var attr_record: Dictionary=session.character_records.get(0,{})
	_txt(Vector2(1210,650),"可分配点数：%d" % int(attr_record.get("unspent_points",0)),18,INK)
	var labels: Array=[["STR","力道"],["AGI","身法"],["CON","根骨"],["MND","心神"]]
	for index in range(labels.size()):
		var x: float=1201+index%2*151
		var yy: float=671+int(index/2)*64
		_button(Rect2(x,yy,139,49),str(labels[index][1])+" +1","train:"+str(labels[index][0]),int(attr_record.get("unspent_points",0))>0)
	if not message.is_empty(): _txt(Vector2(100,887),message.substr(0,42),18,GOLD)
	_button(Rect2(103,904,283,42),"行囊装备","inventory")
	_button(Rect2(1196,904,144,42),"存档 F5","save")
	_button(Rect2(1350,904,148,42),"返回 Esc","back")
