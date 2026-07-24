extends SceneTree
## One-off project-settings generator. Adds the move_* input actions (arrows AND
## WASD, using physical keycodes so WASD is keyboard-layout independent), the
## toggle_debug action, the main scene, and the autoload singletons, then rewrites
## project.godot via ProjectSettings.save(). Run headless:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_project.gd

func _init() -> void:
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("toggle_debug", [KEY_F3])

	ProjectSettings.set_setting(
		"application/run/main_scene", "res://scenes/map/run.tscn")

	# Autoload singletons ("*" = enabled). Order matters: RunState first.
	if ProjectSettings.has_setting("autoload/GameState"):
		ProjectSettings.clear("autoload/GameState")   # migrated: GameState -> RunState
	ProjectSettings.set_setting("autoload/RunState", "*res://autoload/run_state.gd")
	ProjectSettings.set_setting("autoload/SoundManager", "*res://autoload/sound_manager.gd")
	ProjectSettings.set_setting("autoload/DebugOverlay", "*res://scenes/ui/debug_overlay.tscn")

	# Editor-only tooling. Has no effect on the shipped game (EditorPlugin scripts only run
	# inside the Godot editor), but enabling it here means it's on by default in any clone.
	ProjectSettings.set_setting("editor_plugins/enabled",
		PackedStringArray([
			"res://addons/monster_editor/plugin.cfg",
			"res://addons/move_editor/plugin.cfg",
			"res://addons/powerup_editor/plugin.cfg",
		]))

	var err := ProjectSettings.save()
	assert(err == OK, "ProjectSettings.save failed")
	print("gen_project: done")
	quit()


func _add_action(action: String, physical_keys: Array) -> void:
	var setting := "input/" + action
	var events: Array = []
	for k in physical_keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		events.append(e)
	ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": events})
