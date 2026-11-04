# Twelve-action animation and skill VFX bindings

The runtime supports `idle`, `walk`, `run`, `attack1`–`attack4`,
`skill`, `evade`, `guard`, `hit` and `defeat`, plus custom
`WuxiaActorAnimationClip.action` IDs. Each clip is configured in the
character's `WuxiaActorAnimationProfile`.

## Authoring contract

- Set **one** `animation_action` in a skill/rule usage or technique stage.
  Earlier Resource cards may use `animation_id`; conflicting nonempty values
  are rejected. The named Clip must exist on the applicable character profile.
- For texture-based VFX, set `vfx_slot` to a registered native VFX asset ID or
  `event_kind` and `vfx_trigger` to an existing semantic ActionTimeline cue.
  Visual playback waits for its cue; combat rules and damage do not change.
- Alternatively, set `vfx_scene: PackedScene`. This explicit scene slot is
  loaded as a separate 2D effect and cleaned up after 1.5 seconds. **Do not**
  configure both `vfx_scene` and `vfx_slot` on the same usage.
- Every nonempty animation, cue, VFX asset or PackedScene reference is validated
  against actual Resources. Bad references fail validation or log an error;
  they never silently substitute `skill`, `idle` or procedural art.
- Empty optional binding fields retain the event's ordinary presentation
  action or unconfigured procedural effect. This does not authorize fallback
  for a nonempty, invalid reference.

## Animation resources

A modern profile may author all twelve actions and arbitrary additional ones.
The earlier nine-action profiles remain legal. Compatibility remaps must be
**explicitly authored** in `action_fallbacks`, with a direct existing Clip as
the target—there is no hard-coded alias table.

An individual clip may use its own Sprite Sheet, dimensions, per-frame
`frame_durations` and visual-only `root_offsets`. Non-loop clips normalize
their frame beats to semantic presentation windows; `defeat` holds the final
pose. Visual root motion never modifies battle state or hitboxes.

## Regression checks

```sh
godot --headless --path demos/changfeng-battle --script res://checks/test_twelve_action_binding.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_actor_animation_actions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_presentation_references.gd
```

The check fixture uses a neutral atlas and marker scene for mechanical
validation; neither replaces in-use production artwork.
