class_name PowerupSelect
extends CanvasLayer
## Power-up node overlay: the player picks 1 of 3 offered upgrades, then assigns it to a party
## monster. Built in code (no .tscn), same convention as starter_select.gd. Emits
## `chosen(upgrade, monster)` once the player has picked BOTH an upgrade and a recipient; the Run
## controller (run.gd) applies it via _grant_upgrade() and clears the room.
##
## `upgrade` is one of the Dictionaries built by run.gd::_build_upgrade_options()
## ({type, amount, move, label, desc}); `monster` is the recipient Combatant.

signal chosen(upgrade: Dictionary, monster)

const BUTTON_POLISH := preload("res://scripts/button_polish.gd")
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const UPGRADE_ICONS := preload("res://scripts/data/upgrade_icons.gd")

var _options: Array = []   # Array[Dictionary] — the 3 offered upgrades
var _party: Array = []     # living Combatants (recipients)
var _sound: Node
var _content: VBoxContainer   # cleared/rebuilt between the two steps
var _picked: Dictionary = {}  # the upgrade chosen in step 1, during step 2


## Call before adding to the tree.
func setup(options: Array, party: Array) -> void:
	_options = options
	_party = party


func _ready() -> void:
	layer = 30
	_sound = get_node_or_null("/root/SoundManager")

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 18)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(_content)

	_show_upgrade_step()


func _clear_content() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()


# --- Step 1: pick an upgrade ------------------------------------------------

func _show_upgrade_step() -> void:
	_clear_content()
	_content.add_child(_heading("Choose an upgrade", 28))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_content.add_child(row)
	for up in _options:
		row.add_child(_make_upgrade_card(up))


func _make_upgrade_card(up: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 260)
	BUTTON_POLISH.apply(b)
	b.pressed.connect(func():
		_sfx("ui_select")
		_picked = up
		_show_assign_step())

	var col := _card_column(b)
	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art)
	art.add_child(_make_icon(String(up["type"])))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s\n%s" % [up["label"], up["desc"]]
	col.add_child(label)
	return b


func _make_icon(type: String) -> Control:
	var size := Vector2(140, 140)
	var tex := UPGRADE_ICONS.for_type(type)
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
	swatch.color = UPGRADE_ICONS.color_for(type)
	swatch.custom_minimum_size = size
	return swatch


# --- Step 2: assign to a monster --------------------------------------------

func _show_assign_step() -> void:
	_clear_content()
	_content.add_child(_heading("%s — give it to which monster?" % _picked["label"], 24))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	for c in _recipients():
		row.add_child(_make_monster_card(c))

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 40)
	BUTTON_POLISH.apply(back)
	back.pressed.connect(func():
		_sfx("ui_select")
		_show_upgrade_step())
	_content.add_child(back)


## Valid recipients for the picked upgrade — everyone, except a "move" upgrade only goes to
## monsters that don't already know that move.
func _recipients() -> Array:
	if String(_picked.get("type", "")) == "move":
		var mv = _picked["move"]
		return _party.filter(func(c): return not _c_knows(c, mv))
	return _party


func _c_knows(c, mv) -> bool:
	for m in c.moves:
		if m.id == mv.id:
			return true
	return false


func _make_monster_card(c) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 210)
	BUTTON_POLISH.apply(b)
	b.pressed.connect(func():
		_sfx("ui_select")
		chosen.emit(_picked, c))

	var col := _card_column(b)
	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art)
	art.add_child(_make_monster_art(c))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s\nHP %d/%d\nATK %d  DEF %d" % [c.display_name, c.hp, c.max_hp, c.attack, c.defense]
	col.add_child(label)
	return b


func _make_monster_art(c) -> Control:
	var size := Vector2(110, 110)
	var tex := PORTRAITS.for_monster(c.source)
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
	swatch.color = c.source.tint if c.source != null else Color(0.4, 0.4, 0.4)
	swatch.custom_minimum_size = size
	return swatch


# --- shared helpers ---------------------------------------------------------

func _heading(text: String, font_size: int) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	return title


## A VBox that fills a card button with a small inset; the inner controls ignore the mouse so
## clicks reach the Button underneath (same recipe as starter_select.gd).
func _card_column(b: Button) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]:
		col.set(side, 12)
	for side in ["offset_right", "offset_bottom"]:
		col.set(side, -12)
	b.add_child(col)
	return col


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)
