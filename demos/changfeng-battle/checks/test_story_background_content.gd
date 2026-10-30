extends SceneTree
## The first-act image must contain real painted scenery, not merely exist as
## a white opaque placeholder in an imported WebP resource.
const OpeningScene = preload("res://opening.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("STORY_BACKGROUND: " + label)

func _run() -> void:
    var view = OpeningScene.instantiate()
    root.add_child(view)
    await process_frame
    var texture: Texture2D = view.temple_backdrop
    _check(texture!=null, "exploration has a scenery texture")
    if texture!=null:
        _check(view._painted_content(texture),"chosen first-act texture has nonblank painted content")
        _check(texture.get_width()>=1024 and texture.get_height()>=600,
            "first-act painting has enough resolution for full-screen use")
    view._enter_new_game()
    view.story.skip_cinematic()
    _check(view.story.phase=="explore","first act reaches real exploration phase")
    _check(view._temple_background(),"backdrop is available in exploration/draw helper")
    print("STORY_BACKGROUND_PASS checks=%d failures=%d fallback=%s" % [
        checks,failures,str(view.temple_uses_fallback)])
    quit(1 if failures else 0)
