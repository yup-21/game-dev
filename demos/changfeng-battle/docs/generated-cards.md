# Generated card / ability abstraction

This PR stacks on #1 (`feature/ability-technique-runtime`) and adds optional card-generation primitives without changing the default ten martial-school decks.

## What is registered

A card definition is identified by `id`, contains `usages`, and may declare `lifecycle: normal | exile_on_finish` and `relations: {parent, children, related}`. Definitions do **not** have to be listed in any initial deck. The registry validates duplicate IDs, relations, references and recursively declared `grant_card` targets before a battle begins. Registered definitions are immutable templates, not physical card instances.

An instance has a unique UID, owner, source UID, root UID, child UIDs, related UIDs and lifecycle. Create instances via `CardSystem.create_instance`; runtime `link_instances` relates two existing instances belonging to the same actor. `CardSystem.relations(uid)` queries both runtime relationships and definition-level relationships.

## Effects

```json
{
  "type": "grant_card",
  "card_id": "test_token",
  "destination": "hand",
  "count": 1
}
```

`grant_card` uses the same effect resolver as existing cards and can be used in `on_attack_hit` or other supported effect containers. Destinations: `hand`, `draw_pile` and `discard_pile`. Newly generated cards with `exile_on_finish` move to `exile_pile` after they are used or discarded and never join shuffle. Normal generated cards may enter the standard deck/discard cycle.

`CARD_GRANTED` semantics are represented by `CARDS_GRANTED`. Secret hand identities remain subject to the existing visibility system. Counts may grow beyond the initial 12; future invariants must check all five zones, not a fixed count.

## Example registration

`model.reset(seed, first, "tingfeng", {"card_definitions": my_card_definitions})` registers extra definitions before creating the actors' default 12-card decks. A generated-only definition is NOT dealt initially. For details and targeted test data, see `checks/fixtures/generated_cards.json`.

## Stage abilities and UI

The prior PR #1 `USE_ABILITY` uses a virtual available action, **not** a card in the hand. The correct UI is a separate technique / skill area listing legal `USE_ABILITY` actions (such as a stage icon), driven by the same legal-action query. This PR does not implement that UI. Generated stage cards instead appear as real hand cards with their own UIDs.

## Boundaries

- The result of `grant_card` is not a physical card until the effect resolves. Validation must remain server-authoritative.
- This slice adds generation, provenance, linking and exile; it does not yet support arbitrary mid-battle card-definition registration, card transformation, or advanced per-card hand retention (special cards expire when played or discarded).
- No complete Godot run was possible in the authoring environment. Execute the targeted and existing regression suites before merging.
