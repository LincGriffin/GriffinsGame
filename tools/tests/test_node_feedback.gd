extends "res://tools/tests/_base.gd"
## Non-battle node feedback: each of heal / powerup / room / teleport plays a sound (the files are
## present, so play_sfx isn't a silent no-op) and shows on-screen feedback. Heal/treasure/teleport
## get a fading `_toast` banner; power-up shows its chooser overlay.

const RUN_SCRIPT := preload("res://scripts/run.gd")
const SFX_LIBRARY := preload("res://scripts/data/sfx_library.gd")


func test_non_battle_node_sfx_files_exist() -> void:
	SFX_LIBRARY.clear_cache()
	for id in ["node_heal", "node_powerup", "node_room", "node_teleport"]:
		check(SFX_LIBRARY.for_id(id) != null,
			"the '%s' sound effect file is present, so it actually plays" % id)


func test_toast_adds_a_banner_then_is_safe() -> void:
	var run = RUN_SCRIPT.new()
	runner.root.add_child(run)
	await idle()   # _ready() no-ops without a RunState autoload
	var before: int = run.get_child_count()
	run._toast("Party fully healed!")
	check(run.get_child_count() > before, "_toast adds an on-screen banner node")
	run.queue_free()
	await idle()
