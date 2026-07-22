class_name MapGenerator
extends RefCounted
## Generates a run's branching node-map: a layered DAG (Slay-the-Spire style) where
## wandering paths fork and reconnect, then funnel into a single boss node. Pure and
## deterministic given an rng, so it is unit-testable without a scene.
##
## Returns a plain Dictionary:
##   { nodes: Array[Dictionary], start_row_nodes: Array[int], boss: int, rows: int }
## Each node: { id:int, row:int, col:int, type:String, to:Array[int] }.
## `type` is one of: battle, heal, powerup, teleport, boss.

const WIDTH := 4          # columns available per row
const NORMAL_ROWS := 6    # rows 0..5 are normal encounters; row 6 is the boss
const PATHS := 6          # wandering paths seeded through the grid

# Encounter-type weights for intermediate rows (row 0 is always a battle to ease in).
const TYPE_WEIGHTS := {
	"battle": 54,
	"heal": 13,
	"powerup": 13,
	"teleport": 10,
	"room": 10,
}

var _nodes: Array = []
var _by_cell: Dictionary = {}   # Vector2i(row, col) -> node id


func generate(rng: RandomNumberGenerator) -> Dictionary:
	_nodes = []
	_by_cell = {}

	# Seed wandering paths from row 0 down to the last normal row. Each step moves at
	# most one column, so paths naturally branch and rejoin at shared cells.
	for _p in PATHS:
		var col := rng.randi_range(0, WIDTH - 1)
		var cur := _ensure(0, col)
		for row in range(0, NORMAL_ROWS - 1):
			col = clampi(col + rng.randi_range(-1, 1), 0, WIDTH - 1)
			var nxt := _ensure(row + 1, col)
			_link(cur, nxt)
			cur = nxt

	# One boss node in its own row; every last-normal-row node funnels into it.
	var boss_id := _ensure(NORMAL_ROWS, int(WIDTH / 2))
	_nodes[boss_id]["type"] = "boss"
	for n in _nodes:
		if n["row"] == NORMAL_ROWS - 1:
			_link(n["id"], boss_id)

	# Assign encounter types.
	for n in _nodes:
		if n["row"] == 0:
			n["type"] = "battle"
		elif n["row"] < NORMAL_ROWS:
			n["type"] = _weighted_type(rng)

	var starts: Array = []
	for n in _nodes:
		if n["row"] == 0:
			starts.append(n["id"])

	return {
		"nodes": _nodes,
		"start_row_nodes": starts,
		"boss": boss_id,
		"rows": NORMAL_ROWS + 1,
	}


func _ensure(row: int, col: int) -> int:
	var key := Vector2i(row, col)
	if _by_cell.has(key):
		return _by_cell[key]
	var id := _nodes.size()
	_nodes.append({"id": id, "row": row, "col": col, "type": "", "to": []})
	_by_cell[key] = id
	return id


func _link(a: int, b: int) -> void:
	if not _nodes[a]["to"].has(b):
		_nodes[a]["to"].append(b)


func _weighted_type(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in TYPE_WEIGHTS:
		total += TYPE_WEIGHTS[k]
	var roll := rng.randi_range(1, total)
	for k in TYPE_WEIGHTS:
		roll -= TYPE_WEIGHTS[k]
		if roll <= 0:
			return k
	return "battle"
