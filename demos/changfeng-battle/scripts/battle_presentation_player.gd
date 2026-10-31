extends RefCounted
## R8: event/ticket presentation orchestration without any rule-side writes.
## Only the scene may acknowledge a ticket through BattleModel.
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var animator: Variant
var coordinator: Variant
var effects: Variant
var action_cues: Array = []

func _init(animation_driver: Variant, presentation_coordinator: Variant) -> void:
    animator = animation_driver
    coordinator = presentation_coordinator

func attach(painted_world: Node2D) -> void:
    effects = VFX.new(painted_world)

func consume(events: Array, actor_nodes: Dictionary) -> void:
    animator.events(events)
    if effects != null:
        effects.handle_events(events, actor_nodes)

func begin(ticket: int, pending: bool) -> void:
    if pending:
        coordinator.begin(ticket, animator.remaining_seconds())
    else:
        coordinator.cancel()

func tick(delta: float, moving: Dictionary, paths_pending: bool) -> int:
    animator.update(delta, moving)
    action_cues.append_array(animator.drain_action_cues())
    while action_cues.size() > 64:
        action_cues.pop_front()
    if effects != null:
        effects.update(delta)
    return coordinator.advance(delta, animator.remaining_seconds(), paths_pending)

func skip() -> int:
    animator.reset()
    action_cues.clear()
    if effects != null:
        effects.clear()
    return coordinator.skip()

func reset_battle() -> void:
    animator.reset()
    action_cues.clear()
    if effects != null:
        effects.clear()
    coordinator.reset_battle()

## Presentation-time metadata only; an Action Timeline does not create
## new legal inputs or change HP, Qi, chain stacks or CTB by itself.
func phase() -> String:
    return animator.action_phase()

func visual_window_open(kind: String) -> bool:
    return animator.visual_window_open(kind)

func take_action_cues() -> Array:
    var result: Array = action_cues.duplicate(true)
    action_cues.clear()
    return result
