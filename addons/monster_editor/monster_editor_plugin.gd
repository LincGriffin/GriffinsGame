@tool
extends EditorPlugin
## Registers the Monster Editor dock (see monster_editor_dock.gd) in the left panel while the
## project is open in the Godot editor. The dock is a dev tool only — it has no effect on the
## shipped game and is not loaded at runtime (EditorPlugin scripts only run in the editor).

const DOCK_SCRIPT := preload("res://addons/monster_editor/monster_editor_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DOCK_SCRIPT.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
