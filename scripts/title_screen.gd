class_name TitleScreen
extends CanvasLayer
## The run's opening screen: game title + a "click to begin" prompt. A click anywhere
## dismisses it and emits `started`. Built in code (like StarterSelect) so it needs no
## separate .tscn.

signal started


func _ready() -> void:
	layer = 40   # above starter-select (30) and battle (10)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.11, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_gui_input)
	add_child(bg)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(col)

	var title := Label.new()
	title.text = "GRIFFIN'S GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.88, 0.71, 0.27))
	col.add_child(title)

	var prompt := Label.new()
	prompt.text = "Click to begin"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	col.add_child(prompt)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		started.emit()
		queue_free()
