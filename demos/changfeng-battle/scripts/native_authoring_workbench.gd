extends Node2D
## F6 scene-only QA: edit real instances and inspect sprite feet, collision,
## UI and interaction without entering the opening/game session.
const MOVE_SPEED := 200.0

@onready var actor: Node2D = $BattleActor
@onready var npc: Node2D = $StoryNPC
@onready var item: Area2D = $InteractionPoint
@onready var hint: Label = $WorkbenchUI/Hint

func _ready() -> void:
    item.interaction_requested.connect(_on_interaction)
    if not npc.configure_npc("escort_elder", "workbench_npc", "与镖头交谈"):
        push_error("Native workbench NPC could not load the registered art")
    hint.text = "原生编辑测试 · 方向键移动角色 / E 测试道具 / F6 运行场景"

func _process(delta: float) -> void:
    var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if motion.is_zero_approx():
        return
    actor.position += motion * MOVE_SPEED * delta
    actor.position = actor.position.clamp(Vector2(120, 320), Vector2(1470, 920))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        if actor.position.distance_to(item.position) <= 110.0:
            item.request_interaction()
        else:
            hint.text = "先靠近互动标记（E）"

func _on_interaction(interaction_id: StringName) -> void:
    hint.text = "已触发交互：%s · 此处不执行任何剧情/战斗规则" % interaction_id
