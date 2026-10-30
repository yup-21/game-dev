extends RefCounted
## Pure pointer-intent mapping: UI selection takes priority, whereas the
## authoritative rules decide whether the resulting destination is legal.
## This controller never reads or mutates BattleState.
static func world_click(spatial_mode: String, illustrated: bool,
        player_decision: bool, selection_kind: String, free_step_card: bool,
        card_uid: String, usage_id: String, enemy_id: int,
        screen_point: Vector2, grid_move: Dictionary) -> Dictionary:
    if selection_kind == "PLAY_CARD" and free_step_card:
        return {"kind": "PLAY_CARD_FREE_MOVE",
            "params": {"card_uid": card_uid, "usage_id": usage_id,
                "target_position": screen_point}}
    if not selection_kind.is_empty():
        return {}
    if spatial_mode == "FREE" and illustrated and player_decision:
        if enemy_id >= 0:
            return {"kind": "MOVE_AND_ATTACK",
                "params": {"attack_kind": "BASIC_ATTACK", "target_id": enemy_id}}
        return {"kind": "MOVE_FREE", "params": {"target_position": screen_point}}
    if grid_move.has("target_cell"):
        return {"kind": "MOVE", "params": {"target_cell": grid_move.target_cell}}
    return {}
