extends "res://tools/tests/_base.gd"
## The walkable treasure room: reaching the chest emits `finished`. Uses a live scene
## instance and drives the player with _try_step (same approach as test_overworld).

var room
var player


func before_each() -> void:
	room = load("res://scenes/map/room.tscn").instantiate()
	runner.root.add_child(room)
	await idle()   # let _ready build the room + spawn the player
	await idle()
	player = room.get_node("Player")


func after_each() -> void:
	room.queue_free()
	await idle()


func test_reaching_chest_emits_finished() -> void:
	var done := {"hit": false}
	room.finished.connect(func() -> void: done.hit = true)
	# The player spawns three tiles directly below the chest, with a clear column up.
	await player._try_step(Vector2i.UP)
	await player._try_step(Vector2i.UP)
	await player._try_step(Vector2i.UP)
	check(done.hit, "walking onto the chest emits finished")


func test_room_walls_block() -> void:
	check(not player._is_walkable(Vector2i(0, 0)), "the corner wall is blocked")
	check(player._is_walkable(player.grid_cell), "the start tile is walkable")
