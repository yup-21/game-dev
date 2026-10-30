extends SceneTree
## Ensure the visible battle HUD switch actually changes the authoritative
## spatial rule set without resetting or losing the selected character.
const Battle=preload("res://battle_hd2d.tscn")
var checks:=0
var failures:=0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("DUAL_MODE_UI: "+label)

func _key(view: Node,code: Key) -> void:
    var event:=InputEventKey.new()
    event.keycode=code
    event.pressed=true
    view.call("_unhandled_input",event)

func _run() -> void:
    var view=Battle.instantiate()
    root.add_child(view)
    await process_frame
    var model=view.get("model")
    var control: Button=view.get("spatial_mode_button") as Button
    _check(control!=null and control.is_visible_in_tree(),
        "spatial mode switch is visible in actual painted battlefield")
    _check(model.state.spatial_mode=="GRID" and control.text.contains("网格"),
        "initial live battle preserves legacy grid mode")
    var rev: int=model.state.revision
    var qi: int=model.state.get_actor(model.state.active_id).qi_u
    var action: int=model.state.action_no
    _key(view,KEY_M)
    _check(model.state.spatial_mode=="FREE" and model.state.revision==rev+1,
        "M key commits versioned FREE mode, not a visual-only toggle")
    _check(control.text.contains("无网格") and model.state.action_no==action
        and model.state.get_actor(model.state.active_id).qi_u==qi,
        "mode switch updates HUD without spending CTB or Qi")
    _check(view.get("continuous_preview_enabled"),
        "free mode enables arbitrary-point path preview")
    view.call("_process",0.5)
    _check(int(view.get("animation_ticket"))==-1,
        "mode change presentation ticket acknowledges without hanging")
    _key(view,KEY_M)
    _check(model.state.spatial_mode=="GRID" and control.text.contains("网格"),
        "second M key safely returns to grid geometry")
    _check(not view.get("continuous_preview_enabled"),
        "grid mode disables continuous preview and restores grid selection")
    view.call("_process",0.5)
    var first_phase: String=model.state.phase
    _key(view,KEY_R)
    _check(model.state.spatial_mode=="GRID" and model.state.phase==first_phase,
        "quick restart retains selected combat geometry")
    _key(view,KEY_M)
    view.call("_process",0.5)
    _key(view,KEY_R)
    _check(model.state.spatial_mode=="FREE",
        "user preference survives a fresh battle restart")
    var session=root.get_node_or_null("GameSession")
    if session!=null:
        _check(str(session.get("battle_spatial_mode"))=="FREE",
            "GameSession propagates selected mode to later story encounters")
    view.queue_free()
    await process_frame
    print("DUAL_MODE_UI_PASS checks=%d failures=%d"%[checks,failures])
    quit(1 if failures else 0)
