extends SceneTree
## Content generator — writes the monster roster to assets/data/monsters/*.tres.
## Edit the ROSTER table below and re-run to rebalance:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_content.gd
##
## Uses load() for the MonsterData script (not the class_name) so a freshly written
## data class doesn't depend on the global class cache being rebuilt first.

const OUT_DIR := "res://assets/data/monsters/"

# id, name, hp, atk, def, spd, boss, starter, tint
# `starter` monsters are the weaker common ones offered as run-start picks.
const ROSTER := [
	{"id": "slime",    "name": "Green Slime", "hp": 18, "atk": 5,  "def": 2, "spd": 3, "boss": false, "starter": true,  "tint": Color(0.35, 0.78, 0.35)},
	{"id": "bat",      "name": "Cave Bat",    "hp": 12, "atk": 6,  "def": 1, "spd": 8, "boss": false, "starter": true,  "tint": Color(0.59, 0.43, 0.78)},
	{"id": "skeleton", "name": "Skeleton",    "hp": 24, "atk": 8,  "def": 4, "spd": 4, "boss": false, "starter": true,  "tint": Color(0.86, 0.86, 0.82)},
	{"id": "griffin",  "name": "The Griffin", "hp": 60, "atk": 12, "def": 6, "spd": 7, "boss": true,  "starter": false, "tint": Color(0.88, 0.71, 0.27)},
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
		var path := OUT_DIR + str(row.id) + ".tres"
		var err := ResourceSaver.save(m, path)
		assert(err == OK, "failed to save " + path)
		print("wrote ", path)
	print("gen_content: done")
	quit()
