@tool
extends EditorPlugin
## Isolated art production dock; no runtime dependencies.
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")
var dock: Control

func _enter_tree() -> void:
    dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree() -> void:
    if dock != null:
        remove_control_from_docks(dock)
        dock.queue_free()
        dock = null
