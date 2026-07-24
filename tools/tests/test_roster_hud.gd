extends "res://tools/tests/_base.gd"
## The bottom-of-screen party roster strip: one card per party monster, rebuilt whenever the party
## or anyone's HP changes. Driven against a live RunState instance parented under the test root.

const ROSTER_HUD := preload("res://scripts/roster_hud.gd")
const RUN_STATE := preload("res://autoload/run_state.gd")

var hud
var rs


func before_each() -> void:
	# Inject our own RunState rather than relying on /root/RunState — a global lookup can bind to
	# another suite's leftover instance and silently test the wrong party.
	rs = RUN_STATE.new()
	runner.root.add_child(rs)
	rs.new_run(load("res://assets/data/monsters/slime.tres"))
	hud = ROSTER_HUD.new()
	hud.setup(rs)
	runner.root.add_child(hud)
	await idle()


func after_each() -> void:
	hud.queue_free()
	rs.queue_free()
	await idle()


func _cards() -> int:
	return hud._row.get_child_count()


func test_shows_one_card_per_party_member() -> void:
	eq(_cards(), 1, "a one-monster party shows one card")
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	await idle()
	eq(_cards(), 2, "recruiting adds a card")


func test_rebuilds_when_hp_changes_without_a_signal() -> void:
	# HP mutations (battle damage, heal nodes) don't emit party_changed — _process must catch them.
	var before: String = hud._signature   # hud is untyped, so annotate explicitly
	rs.party[0].hp -= 1
	await idle()
	await idle()
	check(hud._signature != before, "the HUD notices a plain HP change and refreshes")


func test_card_shows_current_and_max_hp() -> void:
	var c = rs.party[0]
	var found := false
	for card in hud._row.get_children():
		for sub in card.get_children():
			if sub is Label and sub.text == "%d/%d" % [c.hp, c.max_hp]:
				found = true
	check(found, "a card labels the monster's current/max HP")


func test_pruning_a_dead_monster_drops_its_card() -> void:
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	await idle()
	eq(_cards(), 2, "two monsters, two cards")
	rs.party[0].hp = 0
	rs.prune_dead()
	await idle()
	eq(_cards(), 1, "a permadead monster's card is removed")
