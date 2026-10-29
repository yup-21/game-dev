extends Node2D
## Wuxia equipment and backpack UI. Only GameSession mutates the authoritative inventory.
const Inventory=preload("res://scripts/inventory_system.gd")
const BG=Color("ede7d7")
const PAPER=Color("f9f4e7")
const INK=Color("2b403c")
const JADE=Color("34796f")
const GOLD=Color("b59258")
const SLOTS={"weapon":"兵刃","offhand":"副手","head":"头冠","body":"衣甲","hands":"护腕","waist":"腰带","feet":"鞋履","accessory_1":"饰品一","accessory_2":"饰品二"}
var catalog=Inventory.new()
var font: SystemFont
var buttons: Array=[]
var selected_id: String=""
var tab: String="all"
var page: int=0
var notice: String=""

func _ready() -> void:
	font=SystemFont.new()
	font.font_names=PackedStringArray(["KaiTi","Noto Sans CJK SC","Microsoft YaHei"])

func _session():
	return get_node_or_null("/root/GameSession")

func _record() -> Dictionary:
	var session=_session()
	return session.inventories.get(0,{}) if session!=null else {}

func _go(path: String) -> void:
	var err: int=get_tree().change_scene_to_file(path)
	if err!=OK: notice="无法打开场景："+path

func _rows() -> Array:
	var filtered: Array=[]
	for row in _record().get("stacks",[]):
		var item: Dictionary=catalog.item(str(row.id))
		if tab=="all" or str(item.get("kind",""))==tab:
			filtered.append(row.duplicate(true))
	filtered.sort_custom(func(a,b): return str(a.id)<str(b.id))
	return filtered

func _act(action: String) -> void:
	var session=_session()
	if session==null: return
	if action=="martial":
		session.open_management("res://inventory.tscn")
		call_deferred("_go","res://martial_hall.tscn")
		return
	if action=="back":
		call_deferred("_go",session.return_from_management())
		return
	if action=="save":
		session.open_management("res://inventory.tscn")
		call_deferred("_go","res://save_slots.tscn")
		return
	if action=="next":
		page+=1
	elif action=="prev":
		page=maxi(0,page-1)
	elif action.begins_with("tab:"):
		tab=action.substr(4)
		page=0
		selected_id=""
	elif action.begins_with("select:"):
		selected_id=action.substr(7)
	elif action.begins_with("unequip:"):
		var slot: String=action.substr(8)
		notice="卸下成功" if session.unequip_item(0,slot) else "包裹已满或部位为空"
	elif action=="equip":
		var item: Dictionary=catalog.item(selected_id)
		var slot: String=str(item.get("slot",""))
		if slot=="accessory":
			var equipped: Dictionary=_record().get("equipment",{})
			slot="accessory_1" if str(equipped.get("accessory_1","")).is_empty() else "accessory_2"
		notice="装备成功" if session.equip_item(0,selected_id,slot) else "无法装备：部位冲突、容量不足或物品不存在"
	elif action=="use":
		notice="使用成功" if session.use_field_item(0,selected_id) else "当前不能在战斗外使用该物品"
	page=clampi(page,0,maxi(0,ceili(_rows().size()/18.0)-1))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: _act("back")
		if event.keycode==KEY_F5: _act("save")
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				_act(str(button.action))
				return

func _txt(pos: Vector2,caption: String,size: int=19,color: Color=INK) -> void:
	draw_string(font,pos,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _button(rect: Rect2,caption: String,action: String,enabled: bool=true) -> void:
	draw_rect(rect,JADE if enabled else Color("a6b2a9"))
	draw_rect(rect,GOLD,false,1.5)
	_txt(rect.position+Vector2(12,rect.size.y/2.0+7),caption,18,PAPER)
	if enabled: buttons.append({"rect":rect,"action":action})

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color("30453e"))
	draw_rect(Rect2(40,50,1520,900),BG)
	draw_rect(Rect2(54,64,1492,873),GOLD,false,2)
	_txt(Vector2(89,132),"行箧 · 江湖包裹与装备",39,INK)
	var record: Dictionary=_record()
	if record.is_empty(): return
	_txt(Vector2(92,174),"包裹格 %d/%d · 负重 %.1f/%.1f" % [record.stacks.size(),int(record.capacity),catalog.weight(record),float(record.max_weight)],20,JADE)
	# Left inventory, 6 columns × 3 rows with categories and pagination.
	draw_rect(Rect2(77,204,920,647),PAPER)
	var tabs: Array=[["all","全部"],["equipment","装备"],["consumable","丹药"],["material","材料"],["quest","信物"]]
	for i in range(tabs.size()):
		var label: String=str(tabs[i][1])
		var key: String=str(tabs[i][0])
		var rect: Rect2=Rect2(96+i*174,225,157,43)
		_button(rect,("● " if tab==key else "")+label,"tab:"+key)
	var shown: Array=_rows()
	page=clampi(page,0,maxi(0,ceili(shown.size()/18.0)-1))
	for i in range(18):
		var index: int=page*18+i
		var col: int=i%6
		var row: int=i/6
		var rect: Rect2=Rect2(98+col*148,292+row*139,139,130)
		draw_rect(rect,Color("e5e5d8"))
		draw_rect(rect,GOLD if index<shown.size() and str(shown[index].id)==selected_id else Color("c1c7b7"),false,2)
		if index>=shown.size(): continue
		var entry: Dictionary=shown[index]
		var item: Dictionary=catalog.item(str(entry.id))
		_txt(rect.position+Vector2(9,28),str(item.get("name","未知")).substr(0,8),17,INK)
		_txt(rect.position+Vector2(9,56),"× %d" % int(entry.count),16,JADE)
		_txt(rect.position+Vector2(9,81),str(item.get("kind","")),13,INK)
		buttons.append({"rect":rect,"action":"select:"+str(entry.id)})
	_button(Rect2(114,750,169,46),"上一页","prev",page>0)
	_txt(Vector2(398,779),"%d / %d" % [page+1,maxi(1,ceili(shown.size()/18.0))],20,INK)
	_button(Rect2(542,750,169,46),"下一页","next",page*18+18<shown.size())
	# Full nine-slot paper doll: 3x3, drag-free deterministic equip/unequip.
	draw_rect(Rect2(1022,204,498,506),PAPER)
	_txt(Vector2(1054,249),"九部位装备栏",27,JADE)
	var order: Array=["head","accessory_1","accessory_2","weapon","body","offhand","hands","waist","feet"]
	for index in range(order.size()):
		var slot: String=str(order[index])
		var col: int=index%3
		var row: int=index/3
		var rect: Rect2=Rect2(1041+col*158,272+row*132,148,122)
		draw_rect(rect,Color("e5e6d8"))
		draw_rect(rect,GOLD,false,1.5)
		_txt(rect.position+Vector2(8,24),str(SLOTS[slot]),16,JADE)
		var id: String=str(record.equipment.get(slot,""))
		_txt(rect.position+Vector2(8,55),"（空）" if id.is_empty() else str(catalog.item(id).get("name","未知")).substr(0,7),16,INK)
		if not id.is_empty(): _button(Rect2(rect.position.x+7,rect.position.y+77,133,34),"卸下","unequip:"+slot)
	draw_rect(Rect2(1022,734,498,151),PAPER)
	var selected: Dictionary=catalog.item(selected_id)
	if not selected.is_empty():
		_txt(Vector2(1040,771),str(selected.name),23,INK)
		_txt(Vector2(1040,799),str(selected.get("description","")).substr(0,25),15,INK)
		_txt(Vector2(1040,827),"部位："+str(selected.get("slot","—"))+"  重量："+str(selected.weight),16,INK)
		if selected.kind=="equipment": _button(Rect2(1043,836,195,39),"装备物品","equip")
		if selected.kind=="consumable": _button(Rect2(1043,836,195,39),"战斗外使用","use")
	if not notice.is_empty(): _txt(Vector2(95,884),notice.substr(0,50),17,GOLD)
	_button(Rect2(893,895,180,42),"武学演武堂","martial")
	_button(Rect2(1098,895,188,42),"存档 F5","save")
	_button(Rect2(1315,895,187,42),"返回 Esc","back")
