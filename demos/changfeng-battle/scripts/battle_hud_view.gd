extends RefCounted
## R8: owns UI projections and child-control binding, not combat decisions.
## A later art pass can replace the bound controls without changing the model.
const Hand = preload("res://scripts/battle_hand_view.gd")
const Status = preload("res://scripts/battle_hud_status.gd")
var controls: Dictionary = {}

func bind_controls(bound_controls: Dictionary) -> void:
    controls = bound_controls

func show_status(snapshot: Dictionary, owner_id: int, priority: Variant,
        story_encounter: bool, auto_battle: bool, spatial_mode: String,
        has_free_space: bool, player_decision: bool, ticket: int) -> void:
    Status.render(snapshot, owner_id, priority, story_encounter, auto_battle,
        spatial_mode, has_free_space, player_decision, ticket, controls)

func show_hand(hand: Array, available: bool, pass_only: bool,
        find_actions: Callable, can_approach: Callable, can_free_step: Callable,
        add_card: Callable) -> Dictionary:
    return Hand.render_physical_hand(hand, available, pass_only,
        find_actions, can_approach, can_free_step, add_card)

func layout_hand(container: HBoxContainer, selected: Callable) -> void:
    Hand.layout_fan(container, selected)
