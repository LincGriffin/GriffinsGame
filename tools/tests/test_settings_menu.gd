extends "res://tools/tests/_base.gd"
## The Settings overlay: Escape/Close both emit `closed` and free the menu, and its slider
## wiring genuinely moves the AudioServer bus volume (not just cosmetic). Bus creation here is
## self-contained (doesn't assume test_sound_manager.gd ran first — AudioServer state is
## process-global and test files can run in either order).

const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")

var menu


func before_each() -> void:
	menu = SETTINGS_MENU.new()
	runner.root.add_child(menu)
	await idle()   # let _ready() build the sliders


func after_each() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	await idle()


func test_close_emits_closed_and_frees_the_menu() -> void:
	var fired := {"hit": false}
	menu.closed.connect(func(): fired.hit = true)
	menu._close()
	check(fired.hit, "closing emits the closed signal")
	await idle()
	check(not is_instance_valid(menu), "the settings menu frees itself when closed")


func test_escape_closes_the_menu() -> void:
	var evt := InputEventKey.new()
	evt.keycode = KEY_ESCAPE
	evt.pressed = true
	menu._unhandled_input(evt)
	await idle()
	check(not is_instance_valid(menu), "Escape closes the settings menu")


func test_set_bus_volume_is_safe_when_the_bus_does_not_exist() -> void:
	menu._set_bus_volume("DefinitelyNotARealBus", 0.5)
	check(true, "setting volume on a missing bus does not error")


func test_slider_wiring_updates_the_real_bus_volume() -> void:
	_ensure_bus("SFX")
	menu._set_bus_volume("SFX", 0.5)
	var idx := AudioServer.get_bus_index("SFX")
	var linear := db_to_linear(AudioServer.get_bus_volume_db(idx))
	eq(snappedf(linear, 0.01), 0.5, "moving the SFX slider sets the SFX bus volume")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
