extends SceneTree
## Smoke test that genuine vendored images are importable and usable by Godot.
var failures: int=0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,message: String) -> void:
	if ok: print("PASS "+message)
	else:
		failures+=1
		push_error("FAIL "+message)

func _run() -> void:
	for item in [
		["res://assets/third_party/oga_cc0/open_tileset.png",160],
		["res://assets/third_party/oga_cc0/rpg_skill_tree_icons.png",16],
		["res://assets/third_party/oga_cc0/misc_icons.png",16]
	]:
		var path: String=str(item[0])
		check(FileAccess.file_exists(path),"PNG present: "+path)
		var tex: Texture2D=load(path) as Texture2D
		check(tex!=null and tex.get_width()>=int(item[1]) and tex.get_height()>=16,"texture imports: "+path)
	var art=load("res://scripts/battle_art.gd").new()
	check(art.oga_terrain!=null,"battlefield references imported CC0 terrain")
	check(load("res://martial_hall.tscn")!=null,"martial hall still parses")
	print("OGA CC0 ASSETS: ",failures," failures")
	quit(1 if failures>0 else 0)
