extends SceneTree
## Generates the default power-up roster into assets/data/powerups/*.tres — the upgrades the
## power-up chooser (scripts/powerup_select.gd) draws from. Edit the ROSTER table here to rebalance
## the built-in set, or use the power-up editor dock (addons/powerup_editor/) to add/edit them
## in the Godot GUI. Run:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_powerups.gd

const OUT := "res://assets/data/powerups/"
const POWERUP_DATA := preload("res://scripts/data/powerup_data.gd")

# id, display_name, description, effect, amount, move_id, tint
const ROSTER := [
	["vitality", "Vitality", "+10 Max HP (and heal)", "hp", 10, "", Color(0.85, 0.22, 0.28)],
	["might", "Might", "+3 Attack", "attack", 3, "", Color(0.92, 0.55, 0.18)],
	["aegis", "Aegis", "+3 Defense", "defense", 3, "", Color(0.26, 0.5, 0.9)],
	# "Learn <move>" power-ups — one per teachable pool move (effect "move", amount ignored).
	["learn_strike", "Learn Strike", "Teach the move Strike", "move", 0, "strike", Color(0.62, 0.36, 0.86)],
	["learn_heavy", "Learn Heavy Blow", "Teach the move Heavy Blow", "move", 0, "heavy", Color(0.62, 0.36, 0.86)],
	["learn_slam", "Learn Slam", "Teach the move Slam", "move", 0, "slam", Color(0.62, 0.36, 0.86)],
	["learn_guard", "Learn Guard", "Teach the move Guard", "move", 0, "guard", Color(0.62, 0.36, 0.86)],
	["learn_mend", "Learn Mend", "Teach the move Mend", "move", 0, "mend", Color(0.62, 0.36, 0.86)],
	["learn_drain", "Learn Drain", "Teach the move Drain", "move", 0, "drain", Color(0.62, 0.36, 0.86)],
	["learn_focus", "Learn Focus", "Teach the move Focus", "move", 0, "focus", Color(0.62, 0.36, 0.86)],
]


func _init() -> void:
	var da := DirAccess.open("res://")
	da.make_dir_recursive("assets/data/powerups")
	for row in ROSTER:
		var p: PowerupData = POWERUP_DATA.new()
		p.id = row[0]
		p.display_name = row[1]
		p.description = row[2]
		p.effect = row[3]
		p.amount = row[4]
		p.move_id = row[5]
		p.tint = row[6]
		var dest: String = OUT + p.id + ".tres"
		var err := ResourceSaver.save(p, dest)
		print("  %-14s -> %s [%s]" % [p.id, dest, "ok" if err == OK else "ERR %d" % err])
	print("gen_powerups: done (%d power-ups)" % ROSTER.size())
	quit()
