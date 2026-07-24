class_name MergeSelect
extends CanvasLayer
## Monster-merge overlay (Phase 6): shown when the player wins a battle with a FULL party. Pick two
## party members to fuse into one — freeing a slot for the new recruit — or Skip (don't recruit,
## the pre-merge behavior). Built in code (no .tscn), same convention as starter_select.gd /
## powerup_select.gd. Emits `merged(a, b)` with the two picks, or `skipped`.

signal merged(a, b)
signal skipped

const MONSTER_MERGE := preload("res://scripts/monster_merge.gd")
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const BUTTON_POLISH := preload("res://scripts/button_polish.gd")

const SELECTED_MOD := Color(1.5, 1.5, 0.7)   # brighten a picked card
const NORMAL_MOD := Color(1, 1, 1)

var _party: Array = []          # living Combatants (recipients)
var _incoming: MonsterData      # the monster waiting to be recruited
var _selected: Array = []       # up to 2 picked Combatants
var _cards: Array = []          # [{c, b}] combatant -> its card Button
var _sound: Node
var _preview: Label
var _merge_btn: Button


## Call before adding to the tree.
func setup(party: Array, incoming: MonsterData) -> void:
	_party = party
	_incoming = incoming


func _ready() -> void:
	layer = 30
	_sound = get_node_or_null("/root/SoundManager")

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(col)

	var title := Label.new()
	title.text = "Party's full! Merge two monsters to recruit %s" % _incoming.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Pick two to fuse into one — freeing a slot."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for c in _party:
		var b := _make_card(c)
		row.add_child(b)
		_cards.append({"c": c, "b": b})

	_preview = Label.new()
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_theme_font_size_override("font_size", 20)
	col.add_child(_preview)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	_merge_btn = Button.new()
	_merge_btn.text = "Merge"
	_merge_btn.disabled = true
	BUTTON_POLISH.apply(_merge_btn)
	_merge_btn.pressed.connect(_on_merge)
	buttons.add_child(_merge_btn)
	var skip := Button.new()
	skip.text = "Skip (don't recruit)"
	BUTTON_POLISH.apply(skip)
	skip.pressed.connect(_on_skip)
	buttons.add_child(skip)

	_update()


func _make_card(c) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 200)
	BUTTON_POLISH.apply(b)
	b.pressed.connect(_on_card.bind(c))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["offset_left", "offset_top"]:
		col.set(s, 10)
	for s in ["offset_right", "offset_bottom"]:
		col.set(s, -10)
	b.add_child(col)

	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art)
	art.add_child(_make_art(c))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s\nHP %d/%d\nATK %d  DEF %d" % [c.display_name, c.hp, c.max_hp, c.attack, c.defense]
	col.add_child(label)
	return b


func _make_art(c) -> Control:
	var size := Vector2(96, 96)
	var tex := PORTRAITS.for_monster(c.source)
	if tex != null:
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		pic.custom_minimum_size = size
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return pic
	var sw := ColorRect.new()
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.color = c.source.tint if c.source != null else Color(0.4, 0.4, 0.4)
	sw.custom_minimum_size = size
	return sw


func _on_card(c) -> void:
	_sfx("ui_select")
	if _selected.has(c):
		_selected.erase(c)
	elif _selected.size() < 2:
		_selected.append(c)
	_update()


func _update() -> void:
	for entry in _cards:
		entry["b"].modulate = SELECTED_MOD if _selected.has(entry["c"]) else NORMAL_MOD
	if _selected.size() == 2:
		_preview.text = "→ %s" % MONSTER_MERGE.result_name(_selected[0], _selected[1])
		_merge_btn.disabled = false
	else:
		_preview.text = ""
		_merge_btn.disabled = true


func _on_merge() -> void:
	if _selected.size() != 2:
		return
	_sfx("ui_select")
	merged.emit(_selected[0], _selected[1])


func _on_skip() -> void:
	_sfx("ui_select")
	skipped.emit()


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)
