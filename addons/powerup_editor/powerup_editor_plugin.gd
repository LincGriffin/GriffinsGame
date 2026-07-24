@tool
extends EditorPlugin
## Registers the Power-up Editor dock (see powerup_editor_dock.gd) in the left panel while the
## project is open in the Godot editor. Dev tool only — no effect on the shipped game, not loaded
## at runtime. Mirrors monster_editor_plugin.gd / move_editor_plugin.gd.

const DOCK_SCRIPT := preload("res://addons/powerup_editor/powerup_editor_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DOCK_SCRIPT.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
