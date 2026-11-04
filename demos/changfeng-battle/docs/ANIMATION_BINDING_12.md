# 12-action animation binding and optional skill VFX

The Godot runtime supports twelve semantic base actions while continuing to
load the existing nine-action atlases. The twelve native action IDs are:

`idle`, `walk`, `run`, `attack1`, `attack2`, `attack3`, `attack4`,
`skill`, `evade`, `guard`, `hit`, and `defeat`.

An animation profile may contain further character-specific IDs such as
`skill_mist_cut`. Any ID must be a valid Godot identifier, unique within the
profile, and associated with a nonempty list of valid atlas frame indices.

## Authoring

1. Author a `WuxiaActorAnimationProfile` containing all twelve base clips.
   `attack1`–`attack4` represent four independent attacks; their poses and
   weapon techniques are chosen per character, not globally fixed to swords.
2. Record each `WuxiaActorAnimationClip.action`, frame order, loop flag and
   FPS. `idle`, `walk` and `run` may loop; defeat stays at the final pose.
3. Each usage in `WuxiaSkillUsageDefinition`, `WuxiaRuleUsageDefinition`
   and each technique node in `WuxiaTechniqueNodeDefinition` can configure
   **one** `animation_id`. Choose any existing action ID including `attack1`
   through `attack4` or an additional actor-specific clip. An empty ID
   means use the usual presentation action.
4. Set the optional **single** `vfx_scene: PackedScene` slot to a saved
   `.tscn` scene. Its path is forwarded to the visual event and instantiated
   in the 2D battle world; it is disposed of after 1.5 seconds if the scene
   does not free itself. This slot does not alter combat damage, duration,
   action legality or invulnerability.
5. A skill that declares an attack carries its visual selection on the
   `ATTACK_DECLARED` event. Other skills emit a presentation-only
   `ACTION_PRESENTATION` event. This keeps animation selection separate
   from the rules engine and allows the same action to be shared by skills.

## Compatibility and limitations

- Existing nine-action profiles remain valid and render through aliases:
  `walk/run -> move`, `attack1..4 -> attack`. Until a full twelve-action
  artwork profile is imported, these aliases **reuse the original frames**;
  they do not generate new animation art.
- Character profiles still use one packed atlas (`atlas`, `columns`,
  `rows`). Separate source Sprite Sheets should be repacked into that
  atlas by the art workflow before import.
- `attack1` is the default for an unbound attack; the original `attack`
  and `combo` names remain playable as compatibility aliases.
- Additional skill animations can be registered without editing any
  animation-name enumeration. Missing animation IDs fall back to the
  semantic action and emit a warning.
- Individual attack timing phases currently share the semantic `attack`
  ActionTimeline. The animation itself is cosmetic. Per-frame duration
  tables and root-motion tracks are not added by this change.
- `run` can be selected with a movement event's `run=true` flag. Normal
  movements use `walk`. Movement physics remains authoritative elsewhere.
- When HP reaches zero, `defeat` is played and held; the battlefield no
  longer hides defeated sprites immediately.

Run the smoke test with:

```sh
godot --headless --path demos/changfeng-battle --script res://checks/test_twelve_action_binding.gd
```

The fixture profile uses an existing generic atlas for mechanical validation;
it is not production art and does not replace an in-use character profile.
