extends RefCounted
## Shared UI-only escape/pause overlay for the duel and party battle scenes.
static func back_to_menu(tree: SceneTree) -> void:
	var session=tree.root.get_node_or_null("GameSession")
	if session!=null: session.return_to_menu()
	var error: int=tree.change_scene_to_file("res://opening.tscn")
	if error!=OK: push_error("Return to menu failed")

static func draw_pause(canvas: CanvasItem, font: Font) -> void:
	canvas.draw_rect(Rect2(0,0,1600,1000),Color(0.04,0.10,0.09,0.80))
	canvas.draw_rect(Rect2(395,295,810,378),Color("efeade"))
	canvas.draw_rect(Rect2(395,295,810,378),Color("b18f59"),false,3)
	canvas.draw_string(font,Vector2(579,400),"江湖暂歇",HORIZONTAL_ALIGNMENT_LEFT,-1,44,Color("28433d"))
	canvas.draw_string(font,Vector2(488,485),"P · 继续战斗",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("28433d"))
	canvas.draw_string(font,Vector2(488,538),"F10 · 返回主菜单",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("28433d"))
	canvas.draw_string(font,Vector2(488,592),"暂停不会消耗集气、内息或回合。",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("81735d"))
