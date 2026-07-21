extends Node
## Persistent player state that survives between battles (and, later, between
## rooms and save files). Registered as the autoload singleton `GameState`.
## HP carries over between fights — classic dungeon-crawler attrition.

signal stats_changed
signal leveled_up(new_level: int)

var player_name := "Hero"
var level := 1
var xp := 0
var max_hp := 30
var hp := 30
var attack := 8
var defense := 3
var speed := 5


func _ready() -> void:
	new_game()   # fresh run each launch (no save/load yet)


func new_game() -> void:
	player_name = "Hero"
	level = 1
	xp = 0
	max_hp = 30
	hp = 30
	attack = 8
	defense = 3
	speed = 5
	stats_changed.emit()


func xp_to_next() -> int:
	return level * 10


func is_dead() -> bool:
	return hp <= 0


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	stats_changed.emit()


func full_heal() -> void:
	set_hp(max_hp)


## Award XP and apply any level-ups (each grants stat gains + a full heal).
## Returns the number of levels gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		max_hp += 6
		attack += 2
		defense += 1
		hp = max_hp
		leveled_up.emit(level)
	stats_changed.emit()
	return gained
