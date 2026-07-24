class_name RosterHud
extends CanvasLayer
## A persistent party roster strip along the BOTTOM of the dungeon screen: each monster's portrait
## with its HP underneath. Built in code (no .tscn), same convention as the other overlays.
##
## Sits at layer 15 — above the walkable world, but BELOW the battle overlay / menus (layer 30), so
## it's visible while exploring and covered while fighting.
##
## Refresh strategy: `RunState.party_changed` covers recruit / merge / permadeath, but plain HP
## changes (damage in battle, a heal node, a +max-HP power-up) mutate the shared Combatants without
## emitting anything. So `_process` also compares a cheap signature and rebuilds only when something
## actually changed — always accurate, no signal plumbing through every HP mutation.

const PORTRAITS := preload("res://scripts/data/portraits.gd")

const CARD_SIZE := Vector2(84, 104)
const ART_SIZE := Vector2(64, 64)
const HP_HIGH := Color(0.45, 0.9, 0.45)
const HP_MID := Color(0.95, 0.85, 0.3)
const HP_LOW := Color(0.95, 0.4, 0.4)

var _gs: Node
var _row: HBoxContainer
var _signature := "￿"   # impossible value so the first _process always builds


## Inject the RunState to read the party from. Call before adding to the tree. run.gd passes its
## own `_gs`; without it we fall back to the autoload lookup. (Explicit injection keeps tests
## deterministic — a global /root/RunState lookup can bind to another suite's leftover instance.)
func setup(gs: Node) -> void:
	_gs = gs


func _ready() -> void:
	layer = 15
	if _gs == null:
		_gs = get_node_or_null("/root/RunState")

	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.custom_minimum_size = Vector2(0, CARD_SIZE.y + 16)
	anchor.offset_top = -(CARD_SIZE.y + 16)
	add_child(anchor)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.add_child(_row)

	_refresh()
	if _gs != null and not _gs.party_changed.is_connected(_refresh):
		_gs.party_changed.connect(_refresh)


func _process(_delta: float) -> void:
	if _gs != null and _party_signature() != _signature:
		_refresh()


## Cheap "has anything visible changed?" fingerprint — name + current/max HP for each member.
func _party_signature() -> String:
	if _gs == null:
		return ""
	var parts: Array[String] = []
	for c in _gs.party:
		parts.append("%s:%d/%d" % [c.display_name, c.hp, c.max_hp])
	return "|".join(parts)


func _refresh() -> void:
	if _row == null:
		return
	_signature = _party_signature()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	if _gs == null:
		return
	for c in _gs.party:
		_row.add_child(_make_card(c))


## One roster entry: portrait (or the monster's flat tint when it has no art) above an HP label.
func _make_card(c) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = CARD_SIZE
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)

	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	art.add_child(_make_art(c))

	var hp := Label.new()
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.text = "%d/%d" % [c.hp, c.max_hp]
	hp.add_theme_color_override("font_color", _hp_color(c))
	hp.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp.add_theme_constant_override("outline_size", 4)
	col.add_child(hp)
	return col


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
	var swatch := ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.color = c.source.tint if c.source != null else Color(0.4, 0.4, 0.4)
	swatch.custom_minimum_size = ART_SIZE
	return swatch


func _hp_color(c) -> Color:
	var frac := float(c.hp) / maxf(1.0, float(c.max_hp))
	if frac > 0.5:
		return HP_HIGH
	return HP_MID if frac > 0.25 else HP_LOW
