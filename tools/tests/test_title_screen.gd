extends "res://tools/tests/_base.gd"
## The opening title screen: a click dismisses it and emits `started` so run.gd can
## proceed to starter select / the walkable dungeon.

func test_click_emits_started_and_frees_the_screen() -> void:
	var title = load("res://scripts/title_screen.gd").new()
	runner.root.add_child(title)
	await idle()

	var fired := {"hit": false}   # dict wrapper: GDScript lambdas capture locals by value
	title.started.connect(func(): fired.hit = true)

	var evt := InputEventMouseButton.new()
	evt.button_index = MOUSE_BUTTON_LEFT
	evt.pressed = true
	title._on_gui_input(evt)

	check(fired.hit, "a mouse click emits started")
	await idle()
	check(not is_instance_valid(title), "the title screen frees itself after the click")
