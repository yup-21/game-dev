extends RefCounted
## Fail-fast checks for presentation Resource cross-references.
## Empty optional fields are permitted; nonempty bindings must resolve.
## Explicit placeholder textures are ordinary authored Resource references.

static func validate(definitions: Dictionary, resources: Dictionary, strict_bindings: bool = true) -> String:
    var characters: Dictionary = resources.get("character", {})
    var active_profiles: Array = []
    for character_id in characters:
        var card: WuxiaCharacterDefinition = characters[character_id] as WuxiaCharacterDefinition
        if card == null:
            return "Character Resource has wrong type: " + str(character_id)
        for field in ["portrait", "sprite_sheet", "static_pose", "battle_scene", "animation_profile"]:
            var assigned: Resource = card.get(field) as Resource
            if assigned != null and not _resource_exists(assigned):
                return "Character " + str(character_id) + " has missing " + field + " Resource"
        if card.animation_profile != null and not card.animation_profile.valid_profile():
            return "Character " + str(character_id) + " has invalid animation profile"
        if card.battle_actor_id >= 0:
            if card.portrait == null:
                return "Battle character " + str(character_id) + " has no portrait Resource"
            if card.animation_profile == null and card.sprite_sheet == null and card.battle_scene == null:
                return "Battle character " + str(character_id) + " has no animation or actor scene"
            if card.animation_profile != null:
                var schools: Array = []
                for school_id in card.learned_schools:
                    schools.append(str(school_id))
                if not card.school_id.is_empty() and card.school_id not in schools:
                    schools.append(card.school_id)
                active_profiles.append({"profile": card.animation_profile, "schools": schools})
        elif card.portrait == null and card.sprite_sheet == null and card.static_pose == null and card.battle_scene == null:
            return "Story character " + str(character_id) + " has no presentation Resource"

    for map_id in resources.get("map", {}):
        var map_card: Resource = resources["map"][map_id]
        var background: Texture2D = map_card.get("background") as Texture2D
        if not _resource_exists(background):
            return "Map " + str(map_id) + " has no usable background Resource"
        var layers: WuxiaSceneArtProfile = map_card.get("scene_art") as WuxiaSceneArtProfile
        if layers != null and (not _resource_exists(layers) or not layers.valid_for(map_card.get("viewport_size"))):
            return "Map " + str(map_id) + " has invalid authored scene layers"

    var timeline_cues: Dictionary = {}
    for timeline_id in resources.get("action_timeline", {}):
        var timeline: WuxiaActionTimelineDefinition = resources["action_timeline"][timeline_id] as WuxiaActionTimelineDefinition
        if timeline == null or timeline.schema_version != 1:
            return "Invalid action timeline Resource: " + str(timeline_id)
        var clip_ids: Dictionary = {}
        var cues: Dictionary = {}
        for entry in timeline.clips:
            var clip: WuxiaActionClipDefinition = entry as WuxiaActionClipDefinition
            if clip == null or not clip.valid_clip() or clip_ids.has(clip.clip_id):
                return "Invalid or duplicate timeline clip in " + str(timeline_id)
            clip_ids[clip.clip_id] = true
            cues[clip.clip_id] = {}
            for cue_entry in clip.cues:
                var cue: WuxiaActionCueDefinition = cue_entry as WuxiaActionCueDefinition
                cues[clip.clip_id][cue.cue_name] = true
        for binding_entry in timeline.event_bindings:
            var event_binding: WuxiaActionEventBinding = binding_entry as WuxiaActionEventBinding
            if event_binding == null or event_binding.event_type.is_empty() or not clip_ids.has(event_binding.clip_id):
                return "Action timeline event references a missing clip: " + str(timeline_id)
        if str(timeline_id) == "r32_default_action_timeline":
            timeline_cues = cues

    # Partial authoring/example manifests can borrow rules, clips and VFX from
    # the production library; their local art is still validated above.
    if not strict_bindings:
        return ""
    var assets: Dictionary = definitions.get("asset", {})
    for kind in ["skill", "technique", "rule_catalog"]:
        for definition_id in definitions.get(kind, {}):
            var record: Dictionary = definitions[kind][definition_id]
            var entries: Array = []
            if kind == "skill":
                for usage in record.get("usages", []):
                    entries.append({"data": usage, "school": str(record.get("school_id", ""))})
            elif kind == "technique":
                for node in record.get("nodes", []):
                    entries.append({"data": node, "school": ""})
            else:
                var data: Dictionary = record.get("data", {})
                for card in data.get("cards", []):
                    for usage in card.get("usages", []):
                        entries.append({"data": usage, "school": str(card.get("school_id", ""))})
            for entry in entries:
                var binding: Dictionary = entry.data
                var location: String = kind + " " + str(definition_id) + ":" + str(binding.get("id", ""))
                var action: String = str(binding.get("animation_action", ""))
                var slot: String = str(binding.get("vfx_slot", ""))
                var trigger: String = str(binding.get("vfx_trigger", ""))
                if not slot.is_empty() and trigger.is_empty():
                    return location + " has a VFX Resource without a cue trigger"
                if not action.is_empty() and timeline_cues.is_empty():
                    return location + " requires a missing action timeline Resource"
                if not action.is_empty() and not _action_exists(action, str(entry.school), active_profiles):
                    return location + " references unknown animation action: " + action
                if not slot.is_empty() and not _vfx_exists(slot, assets):
                    return location + " references unknown VFX slot: " + slot
                if not trigger.is_empty():
                    var semantic: String = _semantic_for(action)
                    if action.is_empty():
                        var found := false
                        for clip_cues in timeline_cues.values():
                            if clip_cues.has(trigger):
                                found = true
                                break
                        if not found:
                            return location + " references unknown timeline cue: " + trigger
                    elif not timeline_cues.get(semantic, {}).has(trigger):
                        return location + " references unknown timeline cue " + semantic + ":" + trigger
    return ""

static func _resource_exists(resource: Resource) -> bool:
    return resource != null and resource.resource_path.begins_with("res://") and ResourceLoader.exists(resource.resource_path)

static func _action_exists(action: String, school: String, profiles: Array) -> bool:
    var relevant: Array = []
    if not school.is_empty():
        for item in profiles:
            if school in item.schools:
                relevant.append(item.profile)
    if relevant.is_empty():
        for item in profiles:
            relevant.append(item.profile)
    if relevant.is_empty():
        return false
    for profile in relevant:
        if profile.resolved_clip_for(action) == null:
            return false
    return true

static func _vfx_exists(slot: String, assets: Dictionary) -> bool:
    var direct: Dictionary = assets.get(slot, {})
    if str(direct.get("kind", "")) == "vfx":
        return true
    for asset in assets.values():
        if str(asset.get("kind", "")) == "vfx" and str(asset.get("event_kind", "")) == slot:
            return true
    return false

static func _semantic_for(action: String) -> String:
    if action in ["walk", "run", "move"]:
        return "move"
    if action.begins_with("attack"):
        return "attack"
    if action in ["idle", "guard", "hit", "evade", "defeat", "skill", "combo"]:
        return action
    return "skill"
