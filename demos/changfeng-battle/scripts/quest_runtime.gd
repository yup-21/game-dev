extends RefCounted
## Multi-objective quests are projections of committed story/session facts.
## They never duplicate reward state or mutate GameSession/BattleModel.
const Native = preload("res://scripts/content/content_registry.gd")
const Events = preload("res://scripts/story_event_executor.gd")
var definitions: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = Native.DEFAULT_MANIFEST) -> void:
    var native = Native.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for quest in native.entries("quest").values():
        var id: String = str(quest.get("id",""))
        var goals: Variant = quest.get("objectives")
        if id.is_empty() or not goals is Array or goals.is_empty() or goals.size() > 32:
            load_error = "Invalid quest objectives: " + id
            return
        var seen: Dictionary = {}
        for goal in goals:
            if not goal is Dictionary or not goal.get("id") is String or seen.has(goal.id) or \
                    str(goal.get("ref","")).is_empty() or str(goal.get("type","")) not in ["flag","clue","encounter"]:
                load_error = "Invalid quest objective: " + id
                return
            var required: int = int(goal.get("required",0))
            if required < 1 or required > 999 or \
                    (goal.type != "clue" and required != 1):
                load_error = "Invalid quest target: " + id
                return
            seen[goal.id] = true
        var gates: Variant = quest.get("requirements", [])
        if not gates is Array:
            load_error = "Invalid quest gate list: " + id
            return
        for gate in gates:
            if not gate is Dictionary or not gate.get("flag") is String or not gate.get("equals") is bool:
                load_error = "Invalid quest gate: " + id
                return
        definitions[id] = quest.duplicate(true)

func status(id: String, flags: Dictionary, clues: Dictionary,
        cleared_encounters: Dictionary) -> Dictionary:
    if not definitions.has(id):
        return {}
    var quest: Dictionary = definitions[id]
    var unlocked: bool = Events.meets(quest.get("requirements",[]),flags)
    var objectives: Array = []
    var complete: bool = unlocked
    for goal in quest.objectives:
        var achieved: int = 0
        match str(goal.type):
            "flag":
                achieved = 1 if bool(flags.get(str(goal.ref),false)) == bool(goal.get("equals",true)) else 0
            "clue":
                achieved = maxi(0,int(clues.get(str(goal.ref),0)))
            "encounter":
                achieved = 1 if bool(cleared_encounters.get(str(goal.ref),false)) else 0
        var required: int = int(goal.required)
        var done: bool = achieved >= required
        if not done: complete = false
        objectives.append({"id":goal.id,"label":goal.get("label",""),
            "current":mini(achieved,required),"required":required,"complete":done})
    return {"id":id,"title":quest.get("title",""),"unlocked":unlocked,
        "complete":complete,"objectives":objectives}
