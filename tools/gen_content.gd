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

# id, name, hp, atk, def, spd, tier, boss, elite, starter, tint, moves (ids from gen_moves.gd)
#
# Difficulty tiers scale wild encounters with map depth (run.gd picks by node row):
#   tier 0 = starters / earliest wild · 1 = early · 2 = mid · 3 = late.
# Starters are the three weakest (tier 0). Elites are tough optional-path encounters
# (better reward on win). The Hydra is the final boss; the Griffin is now an elite guardian.
const ROSTER := [
	# --- tier 0: starters (the fixed weakest trio, also the earliest wild pool) ---
	{"id": "chicken",  "name": "Cluckling",    "hp": 10, "atk": 4,  "def": 1, "spd": 6,  "tier": 0, "boss": false, "elite": false, "starter": true,  "tint": Color(0.95, 0.85, 0.35), "moves": ["strike", "focus"]},
	{"id": "slime",    "name": "Green Slime",   "hp": 16, "atk": 5,  "def": 2, "spd": 3,  "tier": 0, "boss": false, "elite": false, "starter": true,  "tint": Color(0.35, 0.78, 0.35), "moves": ["strike", "guard"]},
	{"id": "bat",      "name": "Cave Bat",      "hp": 12, "atk": 6,  "def": 1, "spd": 8,  "tier": 0, "boss": false, "elite": false, "starter": true,  "tint": Color(0.59, 0.43, 0.78), "moves": ["strike", "drain"]},
	# --- tier 1: early wild ---
	{"id": "rat",      "name": "Sewer Rat",     "hp": 16, "atk": 7,  "def": 2, "spd": 7,  "tier": 1, "boss": false, "elite": false, "starter": false, "tint": Color(0.55, 0.45, 0.40), "moves": ["strike", "drain"]},
	{"id": "skeleton", "name": "Skeleton",      "hp": 22, "atk": 8,  "def": 4, "spd": 4,  "tier": 1, "boss": false, "elite": false, "starter": false, "tint": Color(0.86, 0.86, 0.82), "moves": ["strike", "heavy", "guard"]},
	# --- tier 2: mid wild ---
	{"id": "goblin",   "name": "Goblin",        "hp": 28, "atk": 10, "def": 4, "spd": 6,  "tier": 2, "boss": false, "elite": false, "starter": false, "tint": Color(0.45, 0.70, 0.35), "moves": ["strike", "heavy", "focus"]},
	{"id": "spider",   "name": "Giant Spider",  "hp": 26, "atk": 9,  "def": 3, "spd": 9,  "tier": 2, "boss": false, "elite": false, "starter": false, "tint": Color(0.30, 0.30, 0.42), "moves": ["strike", "drain", "focus"]},
	# --- tier 3: late wild ---
	{"id": "golem",    "name": "Stone Golem",   "hp": 46, "atk": 12, "def": 8, "spd": 2,  "tier": 3, "boss": false, "elite": false, "starter": false, "tint": Color(0.55, 0.55, 0.60), "moves": ["slam", "guard"]},
	{"id": "wraith",   "name": "Wraith",        "hp": 32, "atk": 13, "def": 5, "spd": 8,  "tier": 3, "boss": false, "elite": false, "starter": false, "tint": Color(0.50, 0.50, 0.72), "moves": ["strike", "drain", "focus"]},
	# --- elites: tougher, better reward (recruit + full heal) ---
	{"id": "gremlin_knob", "name": "Gremlin Knob", "hp": 42, "atk": 14, "def": 6, "spd": 10, "tier": 3, "boss": false, "elite": true,  "starter": false, "tint": Color(0.80, 0.40, 0.50), "moves": ["strike", "heavy", "drain", "focus"]},
	{"id": "griffin",  "name": "The Griffin",   "hp": 56, "atk": 15, "def": 7, "spd": 9,  "tier": 3, "boss": false, "elite": true,  "starter": false, "tint": Color(0.88, 0.71, 0.27), "moves": ["strike", "heavy", "slam", "guard"]},
	# --- final boss ---
	{"id": "hydra",    "name": "The Hydra",     "hp": 78, "atk": 16, "def": 8, "spd": 6,  "tier": 4, "boss": true,  "elite": false, "starter": false, "tint": Color(0.20, 0.60, 0.55), "moves": ["strike", "heavy", "slam", "drain", "mend"]},
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
		m.is_elite = row.elite
		m.is_starter = row.starter
		m.tier = row.tier
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
