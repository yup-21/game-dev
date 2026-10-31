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
    var battle: Node2D = packed.instantiate() as Node2D
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
    var overlay: Control = battle.get("character_card") as Control
    if overlay == null or not bool(overlay.call("open_actor", battle.get("model"),0)):
        push_error("HUD_CAPTURE: cannot open real character dossier")
        quit(1)
        return
    await process_frame
    await process_frame
    if not await _capture("03-character-dossier"):
        quit(1)
        return
    overlay.call("close_card")
    var painted = battle.get("illustrated_map")
    if painted == null or painted.debug_grid == null:
        push_error("HUD_CAPTURE: baked map visual inspector missing")
        quit(1)
        return
    painted.set_debug_grid(true)
    await process_frame
    if not await _capture("04-baked-grid"):
        quit(1)
        return
    painted.set_debug_grid(false)
    battle.queue_free()
    await process_frame

    # Reuse the actual prologue encounter rather than painting a mock 3v3.
    var session = root.get_node_or_null("GameSession")
    if session == null:
        push_error("HUD_CAPTURE: GameSession autoload unavailable")
        quit(1)
        return
    session.start_new_game()
    session.record_story_event("obtain_fragment")
    if not session.begin_encounter():
        push_error("HUD_CAPTURE: cannot enter real six-actor prologue")
        quit(1)
        return
    var encounter: Node2D = packed.instantiate() as Node2D
    root.add_child(encounter)
    await process_frame
    var squad: Dictionary = encounter.get("snap")
    if squad.get("actors", []).size() != 6:
        push_error("HUD_CAPTURE: expected six actual combatants")
        quit(1)
        return
    encounter.set("intro_remaining", 0.0)
    var story_title: Label = encounter.get("intro_title") as Label
    var story_subtitle: Label = encounter.get("intro_subtitle") as Label
    story_title.visible = false
    story_subtitle.visible = false
    await process_frame
    if not await _capture("05-prologue-3v3"):
        quit(1)
        return
    print("HUD_CAPTURE_PASS board + card + dossier + grid + real 3v3")
    encounter.queue_free()
    await process_frame
    quit(0)
