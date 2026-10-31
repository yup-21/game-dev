extends RefCounted
## Stable-ID factory for Inspector-authored story graphs.
const Native = preload("res://scripts/content/content_registry.gd")
const Story = preload("res://scripts/opening_story.gd")
var definitions: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = Native.DEFAULT_MANIFEST) -> void:
    var native = Native.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    definitions = native.entries("story")

func create(story_id: String):
    var record: Dictionary = definitions.get(story_id,{})
    var path: String = str(record.get("resource_path",""))
    if path.is_empty(): return null
    var story = Story.new(path)
    return story if story.load_error.is_empty() else null
