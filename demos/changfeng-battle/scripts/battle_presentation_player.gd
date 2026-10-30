extends RefCounted
## R8: event/ticket presentation orchestration without any rule-side writes.
## Only the scene may acknowledge a ticket through BattleModel.
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var animator: Variant
var coordinator: Variant
var effects: Variant

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
    if effects != null:
        effects.update(delta)
    return coordinator.advance(delta, animator.remaining_seconds(), paths_pending)

func skip() -> int:
    animator.reset()
    if effects != null:
        effects.clear()
    return coordinator.skip()

func reset_battle() -> void:
    animator.reset()
    if effects != null:
        effects.clear()
    coordinator.reset_battle()
