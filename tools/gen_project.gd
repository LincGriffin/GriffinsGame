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
		"application/run/main_scene", "res://scenes/overworld/overworld.tscn")

	# Autoload singletons ("*" = enabled). Order matters: GameState first.
	ProjectSettings.set_setting("autoload/GameState", "*res://autoload/game_state.gd")
	ProjectSettings.set_setting("autoload/DebugOverlay", "*res://scenes/ui/debug_overlay.tscn")

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
