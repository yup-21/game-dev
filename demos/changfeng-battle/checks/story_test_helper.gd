extends RefCounted
## Integration fixture: traverse the authored prologue, applying only emitted events.
## Never manually reproduce its flags or rewards in test code.
const Story = preload("res://scripts/opening_story.gd")

static func finish_prologue(session: Node, selected_choice: int = 0) -> bool:
    if session == null or session.phase != "story":
        return false
    var definition: Dictionary = session.chapter_definition()
    var story = Story.new(str(definition.get("story_path","")))
    if not story.load_error.is_empty():
        return false
    story.begin()
    story.skip_cinematic()
    if not story.interact():
        return false
    var chosen: bool = false
    for _step in range(64):
        var events: Array = story.take_events()
        if not events.is_empty() and not session.apply_story_events(events):
            return false
        if story.phase != "dialogue":
            break
        var node: Dictionary = story.current_dialogue()
        var choices: Array = story.available_choices(session.flags)
        if not choices.is_empty():
            if chosen or selected_choice < 0 or selected_choice >= choices.size():
                return false
            chosen = true
            if not story.choose(selected_choice,session.flags):
                return false
            session.record_choice(str(node.get("id","")),selected_choice)
        elif not story.advance_dialogue(session.flags):
            return false
    var final_events: Array = story.take_events()
    if not final_events.is_empty() and not session.apply_story_events(final_events):
        return false
    return chosen and story.phase == "complete"
