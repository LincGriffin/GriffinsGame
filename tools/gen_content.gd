extends SceneTree
## Content generator — writes the enemy roster to assets/data/enemies/*.tres.
## Edit the ROSTER table below and re-run to rebalance:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_content.gd
##
## Uses load() for the EnemyData script (not the class_name) so a freshly written
## data class doesn't depend on the global class cache being rebuilt first.

const OUT_DIR := "res://assets/data/enemies/"

# id, name, hp, atk, def, spd, xp, boss, tint
const ROSTER := [
	{"id": "slime",    "name": "Green Slime", "hp": 18, "atk": 5,  "def": 2, "spd": 3, "xp": 6,  "boss": false, "tint": Color(0.35, 0.78, 0.35)},
	{"id": "bat",      "name": "Cave Bat",    "hp": 12, "atk": 6,  "def": 1, "spd": 8, "xp": 7,  "boss": false, "tint": Color(0.59, 0.43, 0.78)},
	{"id": "skeleton", "name": "Skeleton",    "hp": 24, "atk": 8,  "def": 4, "spd": 4, "xp": 12, "boss": false, "tint": Color(0.86, 0.86, 0.82)},
	{"id": "griffin",  "name": "The Griffin", "hp": 60, "atk": 12, "def": 6, "spd": 7, "xp": 50, "boss": true,  "tint": Color(0.88, 0.71, 0.27)},
]


func _init() -> void:
	var script: GDScript = load("res://scripts/data/enemy_data.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for row in ROSTER:
		var e = script.new()
		e.id = row.id
		e.display_name = row.name
		e.max_hp = row.hp
		e.attack = row.atk
		e.defense = row.def
		e.speed = row.spd
		e.xp_reward = row.xp
		e.is_boss = row.boss
		e.tint = row.tint
		var path := OUT_DIR + str(row.id) + ".tres"
		var err := ResourceSaver.save(e, path)
		assert(err == OK, "failed to save " + path)
		print("wrote ", path)
	print("gen_content: done")
	quit()
