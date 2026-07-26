class_name MergeSelect
extends CanvasLayer
## Post-capture merge OFFER overlay (Phase 21). Shown after a won wild/elite fight when the party
## has a never-fused member: fuse the **newly captured** monster with one chosen partner, or decline.
## Below cap, declining recruits the capture as-is; at cap, declining loses it (run.gd applies this).
## Emits `merged(partner)` with the chosen partner Combatant, or `declined`. Built in code (no .tscn),
## same convention as starter_select.gd / powerup_select.gd.
##
## On Merge it plays a self-contained fuse animation (the two cards converge, a particle burst fires,
## the fused result reveals) before emitting, reusing the Phase 18 VfxLibrary / CPUParticles2D system.

signal merged(partner)
signal declined

const MONSTER_MERGE := preload("res://scripts/monster_merge.gd")
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const BUTTON_POLISH := preload("res://scripts/button_polish.gd")
const VFX_LIBRARY := preload("res://scripts/data/vfx_library.gd")

const SELECTED_MOD := Color(1.5, 1.5, 0.7)   # brighten a picked card
const NORMAL_MOD := Color(1, 1, 1)
const ART_SIZE := Vector2(96, 96)

var _incoming: MonsterData        # the newly captured monster (a fixed participant in the fusion)
var _incoming_combatant: Combatant
var _candidates: Array = []       # never-fused living Combatants — eligible partners
var _at_cap: bool = false
var _selected = null              # the chosen partner Combatant, or null
var _cards: Array = []            # [{c, b}] combatant -> its card Button
var _sound: Node
var _preview: Label
var _merge_btn: Button
var _content: Control             # the whole selection UI (hidden during the fuse animation)
var _fx_layer: Control            # absolute-positioned layer the animation runs in


## Call before adding to the tree.
func setup_offer(incoming: MonsterData, candidates: Array, at_cap: bool) -> void:
	_incoming = incoming
	_incoming_combatant = Combatant.from_monster(incoming)
	_candidates = candidates
	_at_cap = at_cap


func _ready() -> void:
	layer = 30
	_sound = get_node_or_null("/root/SoundManager")

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 14)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(_content)

	var title := Label.new()
	title.text = "Merge %s with one of your monsters?" % _incoming.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	_content.add_child(title)

	# The newly captured monster, shown prominently as the fixed fusion participant.
	var new_row := HBoxContainer.new()
	new_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(new_row)
	new_row.add_child(_labelled_art(_incoming_combatant, "NEW — %s" % _incoming.display_name))

	var hint := Label.new()
	hint.text = "Pick a monster to fuse it with (spends both for one stronger monster)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	for c in _candidates:
		var b := _make_card(c)
		row.add_child(b)
		_cards.append({"c": c, "b": b})

	_preview = Label.new()
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_theme_font_size_override("font_size", 20)
	_content.add_child(_preview)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	_content.add_child(buttons)
	_merge_btn = Button.new()
	_merge_btn.text = "Merge"
	_merge_btn.disabled = true
	BUTTON_POLISH.apply(_merge_btn)
	_merge_btn.pressed.connect(_on_merge)
	buttons.add_child(_merge_btn)
	var decline := Button.new()
	decline.text = "Skip — lose it" if _at_cap else "Keep both"
	BUTTON_POLISH.apply(decline)
	decline.pressed.connect(_on_decline)
	buttons.add_child(decline)

	# A full-rect layer above the content that the fuse animation is staged in.
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_update()


func _labelled_art(c, text: String) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var center := CenterContainer.new()
	center.add_child(_make_art(c))
	box.add_child(center)
	return box


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
	var tex := PORTRAITS.for_monster(c.source)
	if tex != null:
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		pic.custom_minimum_size = ART_SIZE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return pic
	var sw := ColorRect.new()
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.color = c.source.tint if c.source != null else Color(0.4, 0.4, 0.4)
	sw.custom_minimum_size = ART_SIZE
	return sw


func _on_card(c) -> void:
	_sfx("ui_select")
	_selected = null if _selected == c else c
	_update()


func _update() -> void:
	for entry in _cards:
		entry["b"].modulate = SELECTED_MOD if _selected == entry["c"] else NORMAL_MOD
	if _selected != null:
		_preview.text = "→ %s" % MONSTER_MERGE.result_name(_selected, _incoming_combatant)
		_merge_btn.disabled = false
	else:
		_preview.text = ""
		_merge_btn.disabled = true


func _on_merge() -> void:
	if _selected == null:
		return
	_sfx("ui_select")
	await _play_fuse_animation(_selected)
	merged.emit(_selected)


func _on_decline() -> void:
	_sfx("ui_select")
	declined.emit()


## Two art tokens (the capture + the chosen partner) converge to center, a particle burst fires, and
## the fused result reveals. Purely cosmetic — the party mutation is run.gd's job after `merged`.
func _play_fuse_animation(partner) -> void:
	# Capture the partner card's screen center before we hide the selection UI.
	var partner_pos := _viewport_center()
	for entry in _cards:
		if entry["c"] == partner:
			var b: Control = entry["b"]
			partner_pos = b.global_position + b.size / 2.0
	_content.visible = false

	var center := _viewport_center()
	var a := _floating_art(_incoming_combatant, Vector2(center.x - 180, center.y))
	var b := _floating_art(partner, partner_pos)
	_sfx("node_powerup")

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(a, "global_position", center - ART_SIZE / 2.0, 0.45)
	tw.tween_property(b, "global_position", center - ART_SIZE / 2.0, 0.45)
	await tw.finished

	_spawn_burst(center)
	await _flash()
	a.queue_free()
	b.queue_free()

	var result := MONSTER_MERGE.fuse(partner, _incoming_combatant)   # deterministic; matches run.gd
	var res_art := _floating_art(result, center - ART_SIZE / 2.0)
	res_art.scale = Vector2(0.2, 0.2)
	res_art.pivot_offset = ART_SIZE / 2.0
	var name_lbl := Label.new()
	name_lbl.text = result.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.position = Vector2(center.x - 120, center.y + 60)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	_fx_layer.add_child(name_lbl)
	var rt := create_tween()
	rt.tween_property(res_art, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rt.finished
	await get_tree().create_timer(0.5).timeout


func _floating_art(c, pos: Vector2) -> Control:
	var art := _make_art(c)
	art.global_position = pos
	_fx_layer.add_child(art)
	return art


func _spawn_burst(center: Vector2) -> void:
	var scene := VFX_LIBRARY.for_id("merge")
	if scene == null:
		return
	var fx := scene.instantiate()
	_fx_layer.add_child(fx)
	if fx is Node2D:
		fx.global_position = center


func _flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.75, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.25)
	await tw.finished
	flash.queue_free()


func _viewport_center() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size) / 2.0


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)
