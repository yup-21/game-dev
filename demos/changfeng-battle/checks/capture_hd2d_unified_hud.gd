extends SceneTree
## Graphical acceptance snapshots only; interaction correctness is verified
## by the separate headless input test, avoiding software-renderer frame timing.
const OUTPUT := "res://captures/hd2d-validation/"

func _initialize() -> void:
    call_deferred("_run")

func _capture(name: String) -> bool:
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("HUD_CAPTURE: empty viewport image")
        return false
    var target := OUTPUT + name + ".png"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    var err: Error = img.save_png(target)
    if err != OK:
        push_error("HUD_CAPTURE: save failed: " + target)
        return false
    print("HUD_CAPTURE ", ProjectSettings.globalize_path(target))
    return true

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("HUD_CAPTURE: requires a graphical display")
        quit(1)
        return
    var packed: PackedScene = load("res://battle_hd2d.tscn") as PackedScene
    if packed == null:
        push_error("HUD_CAPTURE: missing battle scene")
        quit(1)
        return
    var battle: Node3D = packed.instantiate() as Node3D
    root.add_child(battle)
    await process_frame
    # Only dismiss the title animation; no model actions are submitted.
    battle.set("intro_remaining", 0.0)
    var title: Label = battle.get("intro_title") as Label
    var subtitle: Label = battle.get("intro_subtitle") as Label
    title.visible = false
    subtitle.visible = false
    await process_frame
    if not await _capture("01-board"):
        quit(1)
        return

    var hand: HBoxContainer = battle.get("card_actions") as HBoxContainer
    var selected: Button
    for child in hand.get_children():
        if child is Button and child.has_meta("card_uid") and child.has_meta("usage_id"):
            selected = child
            break
    if selected == null:
        push_error("HUD_CAPTURE: cannot find an illustrated hand card")
        quit(1)
        return
    # Visual selection fixture: never bypass legal action validation or
    # mutate the authoritative BattleModel.
    battle.set("selected_card_uid", str(selected.get_meta("card_uid")))
    battle.set("selected_usage_id", str(selected.get_meta("usage_id")))
    battle.call("_paint_selection")
    await process_frame
    if not await _capture("02-card-selection"):
        quit(1)
        return
    print("HUD_CAPTURE_PASS battle + card highlight, model untouched")
    battle.queue_free()
    await process_frame
    quit(0)
