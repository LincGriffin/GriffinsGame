class_name StarterSelect
extends CanvasLayer
## Run-start overlay: the player picks one of a few weaker starter monsters. Built in
## code (like the overworld's banner) so it needs no separate .tscn. Emits
## `chosen(monster)` with the pick; the Overworld then seeds the run's party and frees
## this overlay.

signal chosen(monster: MonsterData)

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


func _make_card(m: MonsterData) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 150)
	b.text = "%s\n\nHP %d\nATK %d   DEF %d\nSPD %d" % [
		m.display_name, m.max_hp, m.attack, m.defense, m.speed]
	b.pressed.connect(func(): chosen.emit(m))
	return b
