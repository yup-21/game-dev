extends SceneTree

const CandidatePath := "res://data/candidates/characters/black_blade/animation_profile.tres"
const ActivePath := "res://data/native/characters/black_blade.tres"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var candidate := load(CandidatePath) as WuxiaActorAnimationProfile
    var active := load(ActivePath) as WuxiaCharacterDefinition
    if candidate == null or active == null or not candidate.valid_profile():
        push_error("BLACK_BLADE_CANDIDATE: missing or invalid native Resource")
        quit(1)
        return
    if active.animation_profile == candidate or active.animation_profile == null:
        push_error("BLACK_BLADE_CANDIDATE: replaced active animation Profile")
        quit(1)
        return
    var expected_actions := WuxiaActorAnimationProfile.MODERN_REQUIRED_ACTIONS
    for action in expected_actions:
        var clip := candidate.clip_for(action)
        if clip == null or clip.effective_atlas(candidate.atlas) != candidate.atlas:
            push_error("BLACK_BLADE_CANDIDATE: missing staged Clip: " + action)
            quit(1)
            return
    if candidate.atlas.resource_path != active.animation_profile.atlas.resource_path:
        push_error("BLACK_BLADE_CANDIDATE: unvalidated sheet reached staged Profile")
        quit(1)
        return
    if candidate.resolved_clip_for("attack") != candidate.clip_for("attack1") or \
            candidate.resolved_clip_for("combo") != candidate.clip_for("attack4"):
        push_error("BLACK_BLADE_CANDIDATE: explicit compatibility mappings missing")
        quit(1)
        return
    print("BLACK_BLADE_CANDIDATE_PASS actions=%d source=legacy_in_use" % expected_actions.size())
    quit(0)
