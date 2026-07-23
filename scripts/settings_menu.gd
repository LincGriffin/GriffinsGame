class_name SettingsMenu
extends CanvasLayer
## A simple audio-volume overlay: one slider per bus SoundManager creates ("SFX", "Music"),
## wired straight to AudioServer. Toggled with Escape from run.gd (works from any screen —
## title, starter select, dungeon, battle) so it needs no dedicated menu button. Built in code,
## no .tscn, same convention as title_screen.gd / starter_select.gd.

signal closed

const BUSES := ["SFX", "Music"]
const BUTTON_POLISH := preload("res://scripts/button_polish.gd")


func _ready() -> void:
	layer = 45   # above battle(10)/starter(30)/title(40), below DebugOverlay(50)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.11, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(col)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	col.add_child(title)

	for bus in BUSES:
		col.add_child(_make_slider_row(bus))

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(140, 44)
	BUTTON_POLISH.apply(close_btn)
	close_btn.pressed.connect(_close)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(close_btn)
	col.add_child(center)

	var hint := Label.new()
	hint.text = "(Esc to close)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	col.add_child(hint)


func _make_slider_row(bus: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = bus
	label.custom_minimum_size = Vector2(70, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(220, 0)
	slider.value = _current_linear_volume(bus)
	slider.value_changed.connect(func(v): _set_bus_volume(bus, v))
	row.add_child(slider)
	return row


func _current_linear_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return 1.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
