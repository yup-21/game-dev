# Twelve-action animation and skill VFX bindings

The runtime supports `idle`, `walk`, `run`, `attack1`–`attack4`,
`skill`, `evade`, `guard`, `hit` and `defeat`, plus custom
`WuxiaActorAnimationClip.action` IDs. Clips belong to each character's
`WuxiaActorAnimationProfile`.

## Single authoring contract

A skill usage, rule usage or technique stage has exactly three presentation fields:

- `animation_action: String` — the **one** chosen action ID, such as `attack3`
  or `skill`. Leave empty to use the semantic event's action. A nonempty
  action must be defined by the applicable character's animation profile.
- `vfx_slot: WuxiaVFXDefinition` — optional, typed reference to a native
  VFX `.tres` Resource (for example
  `res://data/native/assets/shen_sword_thrust.tres`). The Resource has
  one stable `content_id`, which is serialized for the battle runtime.
  **Do not** type an asset ID, file path or PackedScene on the usage.
- `vfx_trigger: String` — the named semantic action-timeline cue (for
  example `strike_active`). Required whenever `vfx_slot` is bound;
  a trigger without an explicit VFX Resource may still time ordinary\n  procedural event visuals.

There is no second `animation_id` or `vfx_scene` authoring field,
no `vfx_path` runtime shortcut and no `ACTION_PRESENTATION` event.
Configured effects fire **only when the queued animation reaches their cue**.
Missing actions, cues or assets fail validation rather than silently
choosing another configured action or effect. Combat timing and damage
remain independent of visual playback.

## VFX Resource formats

`WuxiaVFXDefinition` extends the existing imported-asset Resource:
`content_id`, ownership, provenance and status stay in one place.

- **Texture2D atlas:** set `resource` to the imported texture, then author
  `columns`, `rows` and optional `frame_indices`. The VFX uses the
  authored frame order at the cue; no extra wrapping Resource is required.
- **PackedScene:** set `resource` to a scene whose root is `Node2D`.
  Scene effects are instantiated at the same authored cue, and cleaned
  up after their visual lifetime. Scene VFX have a 1×1 grid and no atlas
  frame indices. Native VFX scenes live under `res://scenes/` or
  `res://assets/imported/`.

The imported VFX asset card is declared once in the native content
manifest. Skill, card and technique Resources point directly to that
card. Asset loading validates the referenced file and media type.

A missing optional VFX binding permits ordinary generic event visuals.
It **never** substitutes a generic effect for a nonempty invalid binding.

## Animation resources

Modern profiles may author all twelve actions and arbitrary additional
ones. Earlier nine-action profiles remain legal. Compatibility remaps
must be **explicitly authored** in `action_fallbacks`, with a direct
existing clip as target—there is no hard-coded alias table.

An individual clip can use its own Sprite Sheet, dimensions,
per-frame `frame_durations` and visual-only `root_offsets`.
Non-loop clips normalize their frame beats to semantic presentation
windows; `defeat` holds its final pose. Visual root motion never
modifies battle state or hitboxes.

## Regression checks

```sh
godot --headless --path demos/changfeng-battle --script res://checks/test_twelve_action_binding.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_actor_animation_actions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_shen_martial_vfx.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_presentation_references.gd
```

The scene VFX check uses a neutral marker scene under
`res://scenes/vfx/`; it is a mechanical test fixture, not a replacement
for approved production artwork.
