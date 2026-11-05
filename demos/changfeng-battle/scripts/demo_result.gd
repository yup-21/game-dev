extends Node2D
## Authored result UI: only chapter/game state changes Label/Button values.
const JADE = Color("37766e")
const LOSS = Color("a95d4c")

@onready var panel: Control = $ResultUI/ResultPanel

func _ready() -> void:
    if _session() == null:
        push_error("Demo result requires GameSession autoload")
        return
    panel.get_node("PrimaryAction").pressed.connect(_primary_action)
    panel.get_node("Retry").pressed.connect(_action.bind("retry"))
    panel.get_node("Menu").pressed.connect(_action.bind("menu"))
    _refresh_native()

func _session():
    return get_node_or_null("/root/GameSession")

func _go(path: String) -> void:
    var err: int = get_tree().change_scene_to_file(path)
    if err != OK:
        push_error("Scene change failed: " + path)

func _primary_action() -> void:
    var session = _session()
    if session == null:
        return
    _action("new" if session.phase == "complete" else
        ("continue" if session.can_advance_chapter() else "finish"))

func _action(id: String) -> void:
    var session = _session()
    if session == null:
        return
    match id:
        "retry":
            if session.retry_encounter():
                call_deferred("_go", session.scene_for("battle"))
        "menu":
            session.return_to_menu()
            call_deferred("_go", session.scene_for("menu"))
        "continue":
            if session.advance_chapter():
                call_deferred("_go", session.scene_for("story"))
        "finish":
            session.finish_demo()
            _refresh_native()
        "new":
            session.return_to_menu()
            call_deferred("_go", "res://opening.tscn")

func _refresh_native() -> void:
    var session = _session()
    if session == null:
        return
    var outcome: String = str(session.battle_outcome)
    var success: bool = outcome == "victory"
    var chapter: Dictionary = session.chapter_definition()
    panel.get_node("Chapter").text = str(chapter.get("scene", {}).get("title", "序章 · 雨夜残镖"))
    var outcome_label: Label = panel.get_node("Outcome")
    outcome_label.text = "江湖暂安 · 一战得脱" if success else \
        ("两败俱伤 · 血路未定" if outcome == "draw" else "追兵得势 · 退守破庙")
    outcome_label.add_theme_color_override("font_color", JADE if success else LOSS)
    panel.get_node("Clue").text = "剧情线索：《太虚引气残篇》" \
        if session.items.has("taixu_fragment") else "尚无残篇线索"
    panel.get_node("Decision").text = "你曾试着救治镖头。" \
        if bool(session.flags.get("helped_escort", false)) else "你曾追问劫镖真相。"
    panel.get_node("Equipment").text = ""
    var hero = session.character("shen_changfeng")
    if hero != null:
        var powders: int = int(hero.inventory.stacks.get("healing_powder", 0))
        var pills: int = int(hero.inventory.stacks.get("breath_pill", 0))
        var gear: String = "已装备" if hero.inventory.equipped.has("weapon") else "未装备"
        panel.get_node("Equipment").text = "随身药囊：金疮药 %d  /  回气丹 %d  /  长剑 %s" % [powders, pills, gear]
    var done: bool = session.phase == "complete"
    panel.get_node("Completion").visible = done
    panel.get_node("PrimaryAction").text = "返回主菜单" if done else \
        ("进入下一幕" if session.can_advance_chapter() else "结束试玩")
    panel.get_node("Retry").visible = not done
    panel.get_node("Menu").visible = not done

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _action("menu")
