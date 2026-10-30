extends SceneTree
## Scene integration regression: all actions enter through Godot's input pipeline.
## Run with --script res://checks/test_hd2d_interactions.gd (headless is supported).
## Omit --headless and append -- --capture to also save rendered acceptance PNGs.
const SCENE_PATH := "res://battle_hd2d.tscn"
const CELL_SIZE := 1.5
var scene: Node3D
var failures := 0
var checks := 0
var observed_tickets: Dictionary = {}
var ticket_violations: Array[String] = []
var previous: Dictionary = {}
var previous_animation_remaining := 0.0
var previous_delta := 0.0
var max_semantic_stages := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> bool:
    checks += 1
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)
    return ok

func _view() -> Dictionary:
    return scene.get("model").snapshot(0)

func _owner(view: Dictionary) -> int:
    return int(view.get("clash", {}).get("priority_actor_id", -1)) if view.phase == "CLASH" else int(view.active_id)

func _actor(view: Dictionary, id: int) -> Dictionary:
    for actor in view.actors:
        if int(actor.id) == id:
            return actor
    return {}

func _shape(view: Dictionary) -> Dictionary:
    var actors: Array = []
    var hand: Array = []
    for actor in view.actors:
        actors.append([actor.id, actor.cell, actor.hp, actor.qi])
    for card in view.hand:
        hand.append(card.get("definition_id", card.get("name", "")))
    return {"actors": actors, "hand": hand, "phase": view.phase, "active_id": view.active_id, "tick": view.global_tick}

func _sample() -> void:
    var current := _view()
    if current.animation_pending:
        observed_tickets[int(current.ticket)] = true
        if int(scene.get("animation_ticket")) != int(current.ticket):
            ticket_violations.append("presenter/model ticket mismatch")
    if not previous.is_empty() and previous.animation_pending:
        if int(current.revision) != int(previous.revision) or int(current.ticket) != int(previous.ticket):
            ticket_violations.append("request accepted before the current ticket was acknowledged")
        # acknowledge -> _accept -> events([]) clears the queue. Compare the
        # preceding frame instead of trusting its already-cleared value.
        if not current.animation_pending and previous_animation_remaining > previous_delta + 0.004:
            ticket_violations.append("ticket acknowledged with %.4fs of animation remaining after a %.4fs frame" % [previous_animation_remaining, previous_delta])
    previous = current
    previous_animation_remaining = float(scene.get("animation_driver").remaining_seconds())
    previous_delta = scene.get_process_delta_time()
    if previous_animation_remaining > 0.0:
        max_semantic_stages = maxi(max_semantic_stages, scene.get("animation_driver").get("timeline").size() + 1)

func _frames(count: int = 2) -> void:
    for _frame in range(count):
        await process_frame
        _sample()

func _mouse(position: Vector2) -> void:
    # Graphical windows poll the OS cursor for get_mouse_position(); keep it
    # aligned with the injected event before testing the scene's ray projection.
    if DisplayServer.get_name() != "headless":
        root.warp_mouse(position)
    var motion := InputEventMouseMotion.new()
    # Input.parse_input_event receives window pixels, while GUI/projected positions
    # use the stretched viewport. This also handles the 64x64 headless window.
    motion.position = root.get_final_transform() * position
    motion.global_position = motion.position
    Input.parse_input_event(motion)
    await _frames()

func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
    await _mouse(position)
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = root.get_final_transform() * position
        event.global_position = event.position
        event.button_index = button
        event.button_mask = button if pressed else 0
        event.pressed = pressed
        Input.parse_input_event(event)
        await _frames()

func _key(code: Key) -> void:
    for pressed in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.physical_keycode = code
        event.pressed = pressed
        Input.parse_input_event(event)
        await _frames()

func _screen(cell: Vector2i) -> Vector2:
    return scene.get("illustrated_map").point_for_cell(cell)

func _visible_rect(control: Control) -> Rect2:
    var visible := control.get_global_rect().intersection(root.get_visible_rect())
    var ancestor := control.get_parent()
    while ancestor != null:
        if ancestor is Control and ancestor.clip_contents:
            visible = visible.intersection(ancestor.get_global_rect())
        ancestor = ancestor.get_parent()
    return visible

func _card_button(action: Dictionary) -> Button:
    var card_uid := str(action.get("card_uid", action.get("card_id", "")))
    var usage_id := str(action.get("usage_id", ""))
    for child in scene.get("card_actions").get_children():
        if child is Button and child.has_meta("card_uid") and child.has_meta("usage_id") \
                and str(child.get_meta("card_uid")) == card_uid \
                and str(child.get_meta("usage_id")) == usage_id:
            return child
    return null

func _wait_player(timeout_seconds: float = 12.0) -> bool:
    var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
    while Time.get_ticks_msec() < deadline:
        await _frames(1)
        var view := _view()
        if not view.animation_pending and _owner(view) == 0:
            return true
        if view.outcome != "playing":
            return false
    return false

func _restart(initial: Dictionary) -> void:
    # Reset is itself a user input, including when the previous input focused a button.
    previous = {}
    await _key(KEY_R)
    check(_shape(_view()) == initial, "R restores seeded hand, actors, resources and initial timeline")
    check(not _view().animation_pending and int(scene.get("animation_ticket")) == -1, "R clears the model and presenter animation ticket")

func _capture(name: String) -> void:
    if not OS.get_cmdline_user_args().has("--capture"):
        return
    if DisplayServer.get_name() == "headless":
        check(false, "--capture requires a graphical display")
        return
    await RenderingServer.frame_post_draw
    var path := "res://captures/hd2d-validation/" + name + ".png"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    var image := root.get_texture().get_image()
    check(image != null and not image.is_empty() and image.save_png(path) == OK, "rendered acceptance image saved: " + name)
    print("HD2D_CAPTURE ", ProjectSettings.globalize_path(path))

func _run() -> void:
    var packed := load(SCENE_PATH) as PackedScene
    if not check(packed != null, "HD2D PackedScene loads"):
        quit(1)
        return
    scene = packed.instantiate() as Node3D
    root.add_child(scene)
    await _frames(4)
    var initial := _shape(_view())
    check(_view().actors.size() == 2 and _owner(_view()) == 0, "real scene initializes the playable duel")
    print("HD2D_VIEWPORT size=", root.get_visible_rect().size, " window=", root.size, " transform=", root.get_final_transform())
    for field in ["status_label", "phase_label", "selection_label", "card_actions"]:
        var control: Control = scene.get(field)
        check(control != null and control.is_visible_in_tree() and _visible_rect(control).has_area(), field + " has visible viewport area")
        if field != "card_actions" and control != null:
            check(root.get_visible_rect().encloses(control.get_global_rect()), field + " fits fully inside the viewport")
    var buttons := 0
    for child in scene.get("card_actions").get_children():
        if child is Button and _visible_rect(child).size.y >= 20.0:
            buttons += 1
    check(buttons > 0, "at least one martial action button is reachable inside the command tray")
    if OS.get_cmdline_user_args().has("--capture"):
        var reveal_deadline := Time.get_ticks_msec() + 5000
        while bool(scene.get("intro_title").visible) and Time.get_ticks_msec() < reveal_deadline:
            await _frames(1)
    await _capture("01-board")

    # These cells are visibly on the board but cannot be moved into.
    var before := _view()
    for cell in [Vector2i(7, 3), Vector2i(8, 4)]:
        await _mouse(_screen(cell))
        print("GRID_INPUT_PROBE wanted=",cell," map=",
            scene.get("illustrated_map").cell_from_screen(root.get_mouse_position(),
                scene.get("model").state.terrain)," viewport_mouse=",root.get_mouse_position(),
            " hovered=",scene.get("hovered"))
        await _click(_screen(cell))
        check(int(_view().revision) == int(before.revision) and _actor(_view(), 0).cell == _actor(before, 0).cell, "mouse rejects water/occupied cell " + str(cell))
    await _mouse(_screen(Vector2i(7, 4)))
    check(scene.get("hovered") == Vector2i(7, 4), "mouse motion and painterly 2D projection resolve the bridge cell")
    check(bool(scene.get("illustrated_map").selection.visible), "legal bridge move displays the 2D cursor")
    await _click(_screen(Vector2i(7, 4)))
    var moved := _view()
    check(_actor(moved, 0).cell == Vector2i(7, 4) and int(moved.revision) == int(before.revision) + 1, "left click submits exactly one legal MOVE through scene input")
    check(moved.animation_pending and int(scene.get("animation_ticket")) == int(moved.ticket), "MOVE opens a matching presentation ticket")
    await _key(KEY_G)
    await _click(_screen(Vector2i(6, 4)))
    check(int(_view().revision) == int(moved.revision), "keyboard and mouse cannot submit again while MOVE is animating")
    check(await _wait_player(), "MOVE animation acknowledges and restores player input")
    var actor_node: Node3D = scene.get("actor_nodes")[0]
    check(actor_node.position.distance_to(Vector3(0.0, 0.0, -0.75)) < 0.04, "visible actor finishes travelling to the submitted cell")

    # Pick an actual targeted card in the seeded scene, then click its real GUI button.
    var card_action: Dictionary = {}
    for action in scene.get("model").legal_actions(0):
        if action.kind == "PLAY_CARD" and action.has("target_id") and int(action.target_id) == 1:
            card_action = action
            break
    if check(not card_action.is_empty(), "seeded adjacent duel exposes an enemy-targeted card"):
        var button := _card_button(card_action)
        if check(button != null and _visible_rect(button).has_area(), "targeted card has a visible GUI button"):
            var point := _visible_rect(button).get_center()
            var revision := int(_view().revision)
            await _click(point)
            check(str(scene.get("selected_kind")) == "PLAY_CARD" and int(_view().revision) == revision, "GUI mouse click selects a card without prematurely submitting")
            await _capture("02-card-selection")
            await _click(_screen(Vector2i(7, 3)))
            check(int(_view().revision) == revision and str(scene.get("selected_kind")) == "PLAY_CARD", "selected card ignores an illegal target and remains selected")
            await _click(_screen(Vector2i(7, 4)), MOUSE_BUTTON_RIGHT)
            check(str(scene.get("selected_kind")).is_empty() and int(_view().revision) == revision, "right click cancels card selection without changing battle state")
            # Right-click rebuilds the actual controls; locate the replacement button.
            button = _card_button(card_action)
            await _click(_visible_rect(button).get_center())
            var target: Vector2i = _actor(_view(), 1).cell
            await _click(_screen(target))
            check(int(_view().revision) == revision + 1 and _view().animation_pending, "selected card submits once when its legal actor target is clicked")
            check(str(scene.get("selected_kind")).is_empty(), "accepted card clears the selection")
            check(await _wait_player(), "card animation and AI response return to a player decision")

    await _restart(initial)
    var end_revision := int(_view().revision)
    await _key(KEY_SPACE)
    var ended := _view()
    check(int(ended.revision) == end_revision + 1 and ended.animation_pending, "Space ends the action through keyboard input")
    check(await _wait_player(), "end-action ticket and automatic AI decisions return control")
    check(int(_view().revision) > int(ended.revision), "AI submitted at least one action after the player ended")
    if check(_view().phase == "CLASH", "seeded AI action opens a player clash response window"):
        var hp_before := float(_actor(_view(), 0).hp) + float(_actor(_view(), 1).hp)
        await _capture("03-clash")
        for _response in range(6):
            if _view().phase != "CLASH":
                break
            var response_revision := int(_view().revision)
            await _key(KEY_SPACE)
            check(int(_view().revision) == response_revision + 1 and _view().animation_pending, "Space submits PASS_REACTION in the real clash window")
            if not check(await _wait_player(), "PASS ticket and AI response finish naturally before the next input"):
                break
        check(_view().phase != "CLASH", "player passes and AI finish resolving the seeded clash")
        var hp_after := float(_actor(_view(), 0).hp) + float(_actor(_view(), 1).hp)
        check(hp_after < hp_before, "real clash resolution applies damage before returning player input")
        print("HD2D_CLASH_DAMAGE total_hp=", hp_before, " -> ", hp_after)
        await _capture("04-clash-resolved")

    await _restart(initial)
    var guard_revision := int(_view().revision)
    await _key(KEY_G)
    check(int(_view().revision) == guard_revision + 1 and _view().animation_pending, "G submits BASIC_GUARD through keyboard input")
    await _restart(initial)
    var reset_revision := int(_view().revision)
    var reset_deadline := Time.get_ticks_msec() + 800
    while Time.get_ticks_msec() < reset_deadline:
        await _frames(1)
    check(int(_view().revision) == reset_revision and not _view().animation_pending, "restart during animation leaves no delayed ticket or stale AI action")
    check(float(scene.get("animation_driver").remaining_seconds()) <= 0.0, "restart clears the semantic animation queue")
    check(observed_tickets.size() >= 4, "several real player and AI presentation tickets were observed")
    check(max_semantic_stages >= 2, "a real event batch exercises multiple semantic animation stages")
    check(ticket_violations.is_empty(), "ticket ordering remains valid: " + str(ticket_violations))
    print("HD2D_INTERACTIONS_RESULT checks=", checks, " failures=", failures, " tickets=", observed_tickets.size(), " max_semantic_stages=", max_semantic_stages)
    if failures == 0:
        print("HD2D_INTERACTIONS_PASS checks=", checks, " tickets=", observed_tickets.size())
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
