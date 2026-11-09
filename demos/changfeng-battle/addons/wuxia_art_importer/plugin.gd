@tool
extends EditorPlugin
## Isolated art production dock; no runtime dependencies.
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")
const GifDock = preload("res://addons/wuxia_art_importer/native_gif_dock.gd")
const FrameWorkbench = preload("res://addons/wuxia_art_importer/frame_workbench_dock.gd")
var dock: Control
var gif_dock: Control
var frame_workbench: Control

func _enter_tree() -> void:
    frame_workbench = FrameWorkbench.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, frame_workbench)
    dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
    gif_dock = GifDock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, gif_dock)

func _exit_tree() -> void:
    if frame_workbench != null:
        remove_control_from_docks(frame_workbench)
        frame_workbench.queue_free()
        frame_workbench = null
    if dock != null:
        remove_control_from_docks(dock)
        dock.queue_free()
        dock = null
    if gif_dock != null:
        remove_control_from_docks(gif_dock)
        gif_dock.queue_free()
        gif_dock = null
