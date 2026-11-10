@tool
extends Window
## Preview the character's *bound* SpriteFrames with the presentation scale and
## foot anchor used by the native battle actor; never use the V3 edit buffer.
const ActorScene = preload("res://scenes/actors/battle_actor.tscn")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const Workbench = preload("res://addons/wuxia_art_importer/frame_workbench_service.gd")

var action_choice: OptionButton
var native_sprite: AnimatedSprite2D
var visual_sprite: Sprite2D
var info: Label
var raw_pixels: CheckBox
var actual_scale := Vector2.ONE
var actual_offset := Vector2.ZERO


func _ready() -> void:
    title = "实际动画预览 · 当前角色绑定"
    size = Vector2i(720, 590)
    min_size = Vector2i(520, 400)
    visible = false
    close_requested.connect(hide)

    var layout := VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(layout)
    var controls := HBoxContainer.new()
    layout.add_child(controls)
    action_choice = OptionButton.new()
    action_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_choice.item_selected.connect(func(_index: int): _play_selected())
    controls.add_child(action_choice)
    var play := Button.new()
    play.text = "播放"
    play.pressed.connect(func(): native_sprite.play(action_choice.get_item_text(action_choice.selected)))
    controls.add_child(play)
    var pause := Button.new()
    pause.text = "暂停"
    pause.pressed.connect(func(): native_sprite.pause())
    controls.add_child(pause)
    var previous := Button.new()
    previous.text = "上一帧"
    previous.pressed.connect(func(): _step(-1))
    controls.add_child(previous)
    var next := Button.new()
    next.text = "下一帧"
    next.pressed.connect(func(): _step(1))
    controls.add_child(next)

    raw_pixels = CheckBox.new()
    raw_pixels.text = "1:1 原始像素（关闭时采用游戏显示比例）"
    raw_pixels.toggled.connect(_toggle_raw_pixels)
    layout.add_child(raw_pixels)
    var viewport_container := SubViewportContainer.new()
    viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    viewport_container.stretch = true
    layout.add_child(viewport_container)
    var viewport := SubViewport.new()
    viewport.size = Vector2i(720, 465)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    viewport_container.add_child(viewport)
    var actor := ActorScene.instantiate() as Node2D
    actor.position = Vector2(360, 330)
    viewport.add_child(actor)
    visual_sprite = actor.get_node("ActionSprite") as Sprite2D
    native_sprite = actor.get_node("ActionSprite/NativeFrames") as AnimatedSprite2D
    var role_label := actor.get_node_or_null("RoleName") as Label
    if role_label != null:
        role_label.hide()
    info = Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(info)


func show_actor(target: String, preferred_action: String) -> String:
    var actor := ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_REPLACE) \
        as WuxiaCharacterDefinition
    if actor == null or actor.animation_profile == null:
        return "找不到角色的 AnimationProfile"
    var profile: WuxiaActorAnimationProfile = actor.animation_profile
    var frames: SpriteFrames = profile.native_frames
    if frames == null:
        return "角色尚未绑定 SpriteFrames，请先导入动作"
    var available: Array[String] = []
    for action in frames.get_animation_names():
        if frames.get_frame_count(action) > 0:
            available.append(action)
    if available.is_empty():
        return "绑定的 SpriteFrames 中没有动作"
    var has_idle := available.has("idle")
    var reference := "idle" if has_idle else available[0]
    visual_sprite.texture = frames.get_frame_texture(reference, 0)
    visual_sprite.hframes = 1
    visual_sprite.vframes = 1
    visual_sprite.offset = profile.feet_offset
    visual_sprite.scale = profile.actor_scale
    VisualScale.fit(visual_sprite, profile.actor_scale,
        CombatScale.actor_height_pixels(), profile.feet_adjust, 0,
        profile.auto_fit_height and has_idle)
    actual_scale = visual_sprite.scale
    actual_offset = visual_sprite.offset
    native_sprite.offset = actual_offset
    visual_sprite.texture = null
    native_sprite.sprite_frames = frames
    native_sprite.flip_h = profile.faces_left_unflipped
    raw_pixels.button_pressed = false
    _toggle_raw_pixels(false)
    action_choice.clear()
    for action in available:
        action_choice.add_item(action)
    var chosen := 0
    for index in range(action_choice.item_count):
        if action_choice.get_item_text(index) == preferred_action:
            chosen = index
            break
    action_choice.select(chosen)
    _play_selected()
    popup_centered()
    return ""


func _play_selected() -> void:
    if action_choice.selected < 0 or native_sprite.sprite_frames == null:
        return
    var action := action_choice.get_item_text(action_choice.selected)
    native_sprite.play(action)
    var frames := native_sprite.sprite_frames
    var texture := frames.get_frame_texture(action, 0)
    var bounds: Rect2i = Workbench.visible_bounds(texture)
    info.text = "%s · %d 帧 · %.1f FPS · 首帧可见像素 %s · %s" % [
        action, frames.get_frame_count(action), frames.get_animation_speed(action),
        str(bounds.size), "循环" if frames.get_animation_loop(action) else "单次"]


func _step(direction: int) -> void:
    var frames := native_sprite.sprite_frames
    if frames == null or not frames.has_animation(native_sprite.animation):
        return
    native_sprite.pause()
    var count := frames.get_frame_count(native_sprite.animation)
    if count > 0:
        native_sprite.set_frame_and_progress(posmod(native_sprite.frame + direction, count), 0.0)


func _toggle_raw_pixels(enabled: bool) -> void:
    if visual_sprite == null or native_sprite == null:
        return
    visual_sprite.scale = Vector2.ONE if enabled else actual_scale
    native_sprite.offset = Vector2.ZERO if enabled else actual_offset
