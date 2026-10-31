extends SceneTree
## Verify imported CC0 textures are real Godot-readable image assets.
const ROOT="res://assets/kenney/"
const UI=["panel_brown.png","panel_brown_dark.png","panel_border_brown.png","button_brown.png","progress_red.png","progress_green.png"]
const CHARACTERS=["tile_0082.png","tile_0084.png","tile_0086.png","tile_0088.png","tile_0096.png","tile_0100.png"]
const TERRAIN=["tile_0000.png","tile_0001.png","tile_0016.png","tile_0024.png","tile_0040.png","tile_0050.png"]
var errors: int=0

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	for group in [{"path":"ui/","files":UI},{"path":"characters/","files":CHARACTERS},{"path":"terrain/","files":TERRAIN}]:
		for name in group.files:
			var path: String=ROOT+str(group.path)+str(name)
			var texture: Texture2D=load(path) as Texture2D
			if texture==null or texture.get_width()<1 or texture.get_height()<1:
				errors+=1
				push_error("ASSET_IMPORT_FAILED "+path)
	for scene in ["res://opening.tscn","res://battle_hd2d.tscn"]:
		if load(scene)==null:
			errors+=1
			push_error("SCENE_IMPORT_FAILED "+scene)
	print("KENNEY_CC0_ASSETS: ",18-errors," loaded, ",errors," failures")
	quit(1 if errors>0 else 0)
