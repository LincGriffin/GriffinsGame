class_name MapView
extends Control
## Renders a run's node-map (from MapGenerator) as clickable node buttons with edges
## drawn behind them. Reachable nodes are enabled and bright; the rest are shown dimmed
## and disabled. Emits node_selected(id) when a reachable node is clicked. Built in
## code (no .tscn) — the Run controller creates one and feeds it the map.

signal node_selected(id: int)

const COL_W := 150.0
const ROW_H := 84.0
const MARGIN := Vector2(70, 40)
const NODE_SIZE := Vector2(104, 46)

const LABELS := {
	"battle": "Fight", "heal": "Heal", "powerup": "Power",
	"teleport": "Warp", "room": "Room", "boss": "BOSS",
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
		var id: int = n["id"]
		button.pressed.connect(func(): node_selected.emit(id))
		add_child(button)
		_buttons[id] = button
	queue_redraw()


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
			b.modulate = Color(0.45, 0.5, 0.45)
		else:
			b.modulate = Color(0.7, 0.7, 0.75)
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
	for n in _map["nodes"]:
		var from := _node_center(n)
		for t in n["to"]:
			var to_node: Dictionary = _map["nodes"][t]
			var lit: bool = _reachable.has(t) or _cleared.has(n["id"])
			var col := Color(0.6, 0.75, 0.9, 0.8) if lit else Color(0.4, 0.4, 0.5, 0.5)
			draw_line(from, _node_center(to_node), col, 2.0)
