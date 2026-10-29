extends SceneTree
## Export deterministic original atlases for art review.
## Run: godot --headless --path demos/changfeng-battle --script res://checks/export_hd2d_sprites.gd
const Factory = preload("res://scripts/hd2d_sprite_factory.gd")

func _initialize() -> void:
    call_deferred("_export")

func _export() -> void:
    var hero: ImageTexture = Factory.make_sheet(false)
    var rival: ImageTexture = Factory.make_sheet(true)
    var folder: String = ProjectSettings.globalize_path("user://")
    var hero_path: String = folder.path_join("wuxia_swordsman_6x4.png")
    var rival_path: String = folder.path_join("wuxia_saber_6x4.png")
    var err1: Error = hero.get_image().save_png(hero_path)
    var err2: Error = rival.get_image().save_png(rival_path)
    if err1 != OK or err2 != OK:
        push_error("HD2D_ATLAS_EXPORT_FAIL ", err1, " ", err2)
        quit(1)
        return
    print("HD2D_ATLAS_EXPORT_PASS ", hero_path, " ", rival_path)
    quit(0)
