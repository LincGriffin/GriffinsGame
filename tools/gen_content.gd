extends SceneTree
## Content generator — writes the monster roster to assets/data/monsters/*.tres.
## Edit the ROSTER table below and re-run to rebalance. Run gen_moves.gd FIRST — each
## monster references moves from assets/data/moves/ by id.
##   Godot_console.exe --headless --path <project> --script res://tools/gen_content.gd
##
## Uses load() for the MonsterData script (not the class_name) so a freshly written
## data class doesn't depend on the global class cache being rebuilt first.

const OUT_DIR := "res://assets/data/monsters/"
const MOVES_DIR := "res://assets/data/moves/"

# id, name, hp, atk, def, spd, boss, starter, tint, moves (ids from gen_moves.gd)
const ROSTER := [
	{"id": "slime",    "name": "Green Slime", "hp": 18, "atk": 5,  "def": 2, "spd": 3, "boss": false, "starter": true,  "tint": Color(0.35, 0.78, 0.35), "moves": ["strike", "guard"]},
	{"id": "bat",      "name": "Cave Bat",    "hp": 12, "atk": 6,  "def": 1, "spd": 8, "boss": false, "starter": true,  "tint": Color(0.59, 0.43, 0.78), "moves": ["strike", "heavy"]},
	{"id": "skeleton", "name": "Skeleton",    "hp": 24, "atk": 8,  "def": 4, "spd": 4, "boss": false, "starter": true,  "tint": Color(0.86, 0.86, 0.82), "moves": ["strike", "heavy", "guard"]},
	{"id": "griffin",  "name": "The Griffin", "hp": 60, "atk": 12, "def": 6, "spd": 7, "boss": true,  "starter": false, "tint": Color(0.88, 0.71, 0.27), "moves": ["strike", "heavy", "guard", "mend"]},
]


func _init() -> void:
	var script: GDScript = load("res://scripts/data/monster_data.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for row in ROSTER:
		var m = script.new()
		m.id = row.id
		m.display_name = row.name
		m.max_hp = row.hp
		m.attack = row.atk
		m.defense = row.def
		m.speed = row.spd
		m.is_boss = row.boss
		m.is_starter = row.starter
		m.tint = row.tint
		m.moves.clear()
		for mid in row.moves:
			var mv = load(MOVES_DIR + str(mid) + ".tres")
			assert(mv != null, "missing move " + str(mid))
			m.moves.append(mv)
		var path := OUT_DIR + str(row.id) + ".tres"
		var err := ResourceSaver.save(m, path)
		assert(err == OK, "failed to save " + path)
		print("wrote ", path)
	print("gen_content: done")
	quit()
