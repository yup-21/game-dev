@tool
extends EditorPlugin
const Dock = preload("res://addons/wuxia_map_editor/map_painter_dock.gd")
var dock: Control

func _enter_tree() -> void:
    dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL,dock)
    dock.hide()

func _exit_tree() -> void:
    if dock != null:
        remove_control_from_docks(dock)
        dock.queue_free()
        dock = null

func _handles(object: Object) -> bool:
    return object is WuxiaMapDefinition

func _edit(object: Object) -> void:
    if dock != null:
        dock.call("edit_map",object)

func _make_visible(visible: bool) -> void:
    if dock != null:
        dock.visible = visible
