class_name StarterSelect
extends CanvasLayer
## Run-start overlay: the player picks one of a few weaker starter monsters. Built in
## code (like the overworld's banner) so it needs no separate .tscn. Emits
## `chosen(monster)` with the pick; the Overworld then seeds the run's party and frees
## this overlay.

signal chosen(monster: MonsterData)

## Preloaded rather than referenced by class_name so this compiles regardless of whether the
## global class cache has been rebuilt yet (same reason the generators use load()).
const PORTRAITS := preload("res://scripts/data/portraits.gd")

var _options: Array = []


## Call before adding to the tree.
func setup(options: Array) -> void:
	_options = options


func _ready() -> void:
	layer = 30

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(col)

	var title := Label.new()
	title.text = "Choose your starter monster"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)

	for m in _options:
		row.add_child(_make_card(m))


## A pick-me card: the monster's portrait (or a flat tint swatch when it has no art yet)
## above its stat block. The inner controls ignore the mouse so clicks reach the Button.
func _make_card(m: MonsterData) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 280)
	b.pressed.connect(func(): chosen.emit(m))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]:
		col.set(side, 12)
	for side in ["offset_right", "offset_bottom"]:
		col.set(side, -12)
	b.add_child(col)

	var art_box := CenterContainer.new()
	art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art_box)
	art_box.add_child(_make_art(m))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s\nHP %d\nATK %d   DEF %d\nSPD %d" % [
		m.display_name, m.max_hp, m.attack, m.defense, m.speed]
	col.add_child(label)
	return b


## The portrait if this monster has one, else a swatch of its tint the same size.
func _make_art(m: MonsterData) -> Control:
	var size := Vector2(150, 150)
	var tex := PORTRAITS.for_monster(m)
	if tex != null:
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		pic.custom_minimum_size = size
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return pic
	var swatch := ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.color = m.tint
	swatch.custom_minimum_size = size
	return swatch
