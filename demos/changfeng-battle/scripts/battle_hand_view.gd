extends RefCounted
## The physical hand is rendered from snapshot.hand, NOT legal_actions.
## Valid usages drive clickability, but drawn cards never vanish due to range.
const CardUI = preload("res://scripts/hd2d_card_ui.gd")

static func render_physical_hand(hand: Array, available: bool, pass_only: bool,
        find_actions: Callable, can_approach: Callable, can_free_step: Callable,
        add_card: Callable) -> Dictionary:
    var shown := 0
    var playable := 0
    for card in hand:
        var uid := str(card.get("uid", card.get("card_id", "")))
        var displayed := false
        if available and not pass_only:
            for usage in card.get("usages", []):
                var usage_id := str(usage.get("id", ""))
                if (find_actions.call(uid, usage_id).is_empty()
                        and not can_approach.call(uid, usage_id)
                        and not can_free_step.call(uid, usage_id)):
                    continue
                add_card.call(card, usage, true)
                playable += 1
                displayed = true
        if not displayed:
            var choices: Array = card.get("usages", [])
            if choices.is_empty():
                continue
            var fallback: Dictionary = choices[0]
            for usage in choices:
                if str(usage.get("timing", "")) == "ACTION":
                    fallback = usage
                    break
            add_card.call(card, fallback, false)
        shown += 1
    return {"displayed_count": shown, "playable_count": playable}

static func make_physical_card(card: Dictionary, usage: Dictionary,
        playable: bool, selected: bool) -> Button:
    var uid := str(card.get("uid", card.get("card_id", "")))
    return CardUI.make_card(uid, str(card.get("definition_id", "")),
        str(card.get("name", "招式")), str(usage.get("name", usage.get("id", ""))),
        usage.get("quoted_cost", {}), playable and selected)

static func layout_fan(container: HBoxContainer, selected: Callable) -> void:
    if container == null or not is_instance_valid(container):
        return
    var cards: Array[Button] = []
    for child in container.get_children():
        if child is Button and not child.is_queued_for_deletion():
            cards.append(child)
    var midpoint := (float(cards.size()) - 1.0) * 0.5
    for i in range(cards.size()):
        var card := cards[i]
        var spread := float(i) - midpoint
        card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
        card.rotation_degrees = clampf(spread * 5.2, -11.5, 11.5)
        card.position.y = absf(spread) * 5.0 - (15.0 if selected.call(card) else 0.0)
        card.set_meta("fan_angle", card.rotation_degrees)
