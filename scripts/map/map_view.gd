class_name MapView
extends Control
## Renders a run's node-map (from MapGenerator) as clickable node buttons with edges
## drawn behind them. Reachable nodes are enabled and bright; the rest are shown dimmed
## and disabled. Emits node_selected(id) when a reachable node is clicked. Built in
## code (no .tscn) — the Run controller creates one and feeds it the map.
##
## Magna-Tiles look: each node is a translucent primary-color "plastic" chip (rounded,
## glowing border) keyed by type; edges are drawn as glowing connective paths.

signal node_selected(id: int)

const COL_W := 150.0
const ROW_H := 84.0
const MARGIN := Vector2(70, 40)
const NODE_SIZE := Vector2(104, 46)

const LABELS := {
	"battle": "Fight", "heal": "Heal", "powerup": "Power",
	"teleport": "Warp", "room": "Room", "elite": "Elite", "boss": "BOSS",
}

# Per-type primary hues (translucent plastic chips).
const TYPE_COLOR := {
	"battle": Color(0.87, 0.27, 0.27),    # red
	"heal": Color(0.29, 0.74, 0.40),      # green
	"powerup": Color(0.95, 0.80, 0.25),   # yellow
	"teleport": Color(0.36, 0.55, 0.95),  # blue
	"room": Color(0.95, 0.55, 0.20),      # orange
	"elite": Color(0.70, 0.25, 0.75),     # purple — the tough one
	"boss": Color(0.96, 0.78, 0.22),      # bright gold
}

var _map: Dictionary = {}
var _buttons: Dictionary = {}   # id -> Button
var _reachable: Array = []
var _cleared: Array = []


func setup(map: Dictionary) -> void:
	_map = map
	for b in _buttons.values():
		b.queue_free()
	_buttons.clear()
	for n in _map["nodes"]:
		var button := Button.new()
		button.text = LABELS.get(n["type"], str(n["type"]))
		button.size = NODE_SIZE
		button.position = _node_pos(n)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		_style_node(button, n["type"])
		var id: int = n["id"]
		button.pressed.connect(func(): node_selected.emit(id))
		add_child(button)
		_buttons[id] = button
	queue_redraw()


## Give a node button the translucent-plastic chip look for its type (applied across all
## button states so it reads consistently; set_state() only modulates brightness).
func _style_node(button: Button, type: String) -> void:
	var hue: Color = TYPE_COLOR.get(type, Color(0.6, 0.6, 0.65))
	var boss := type == "boss"
	var emphatic := boss or type == "elite"   # tough encounters get a heavier glow
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hue.r, hue.g, hue.b, 0.82)
	sb.set_border_width_all(3 if emphatic else 2)
	sb.border_color = hue.lightened(0.35)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(hue.r, hue.g, hue.b, 0.45)
	sb.shadow_size = 8 if emphatic else 5
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, sb)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	button.add_theme_font_size_override("font_size", 18 if boss else 15)


func set_state(reachable: Array, cleared: Array) -> void:
	_reachable = reachable
	_cleared = cleared
	for id in _buttons:
		var b: Button = _buttons[id]
		var reach: bool = reachable.has(id)
		b.disabled = not reach
		if reach:
			b.modulate = Color(1, 1, 1)
		elif cleared.has(id):
			b.modulate = Color(0.5, 0.5, 0.5)
		else:
			b.modulate = Color(0.72, 0.72, 0.78)
	queue_redraw()


func _node_pos(n: Dictionary) -> Vector2:
	# Row 0 at the bottom, boss at the top (you climb toward the boss).
	var rows: int = _map["rows"]
	var x := MARGIN.x + float(n["col"]) * COL_W
	var y := MARGIN.y + float(rows - 1 - int(n["row"])) * ROW_H
	return Vector2(x, y)


func _node_center(n: Dictionary) -> Vector2:
	return _node_pos(n) + NODE_SIZE * 0.5


func _draw() -> void:
	if _map.is_empty():
		return
	# Glowing connective paths: a wide translucent underlay plus a bright thin core. Edges
	# leading to a currently-reachable node (or out of a cleared node) light up.
	for n in _map["nodes"]:
		var from := _node_center(n)
		for t in n["to"]:
			var to_node: Dictionary = _map["nodes"][t]
			var to := _node_center(to_node)
			var lit: bool = _reachable.has(t) or _cleared.has(n["id"])
			if lit:
				draw_line(from, to, Color(0.55, 0.78, 1.0, 0.30), 8.0)
				draw_line(from, to, Color(0.80, 0.92, 1.0, 0.95), 2.5)
			else:
				draw_line(from, to, Color(0.45, 0.45, 0.55, 0.35), 6.0)
				draw_line(from, to, Color(0.55, 0.55, 0.62, 0.55), 2.0)
