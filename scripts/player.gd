class_name Player
extends CharacterBody2D
## Grid-step overworld movement.
##
## The grid is authoritative: the player always occupies exactly one whole tile.
## A Tween only animates the *visual* glide between tiles — the logical position
## (`grid_cell`) snaps instantly. Wall collision is a pre-move query against the
## TileMapLayer's "walkable" custom data, NOT physics, so there is never a
## partial-tile or sliding state (we deliberately don't call move_and_slide).

const TILE_SIZE := 32          # kept for reference; positioning uses map_to_local
const MOVE_TIME := 0.12        # seconds to glide one tile

## Injected by the Overworld so the player can ask the map what's walkable.
@export var tile_map_layer: TileMapLayer

## true  = holding a direction keeps stepping tile-by-tile (classic Pokemon/FF feel).
## false = one tile per key press.
@export var hold_to_move := true

## Emitted after a step finishes, with the tile the player now stands on.
signal moved(cell: Vector2i)
## Emitted when a step is attempted into a blocked (non-walkable) tile.
signal move_blocked(cell: Vector2i)

var grid_cell := Vector2i.ZERO
var is_moving := false

# Iteration order sets input priority when two directions are held at once.
const DIRECTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}


func _ready() -> void:
	add_to_group("player")   # so the debug overlay can find the player in any scene


func _physics_process(_delta: float) -> void:
	if is_moving:
		return
	var dir := _read_direction()
	if dir != Vector2i.ZERO:
		_try_step(dir)


## Instantly place the player on a tile (used for spawn). No animation, no signal.
func snap_to_cell(cell: Vector2i) -> void:
	grid_cell = cell
	if tile_map_layer != null:
		position = tile_map_layer.map_to_local(cell)


func _read_direction() -> Vector2i:
	for action in DIRECTIONS:
		var pressed := Input.is_action_pressed(action) if hold_to_move \
			else Input.is_action_just_pressed(action)
		if pressed:
			return DIRECTIONS[action]
	return Vector2i.ZERO


## Attempt a one-tile step. Blocked tiles emit `move_blocked` and don't move.
func _try_step(dir: Vector2i) -> void:
	var target := grid_cell + dir
	if not _is_walkable(target):
		move_blocked.emit(target)
		return

	is_moving = true
	grid_cell = target
	var tween := create_tween()
	tween.tween_property(self, "position", tile_map_layer.map_to_local(target), MOVE_TIME)
	await tween.finished
	is_moving = false
	moved.emit(grid_cell)


## A cell is walkable only if it holds a tile whose "walkable" custom data is true.
## Empty / out-of-bounds cells (no tile) are treated as blocked.
func _is_walkable(cell: Vector2i) -> bool:
	if tile_map_layer == null:
		return false
	var td := tile_map_layer.get_cell_tile_data(cell)
	return td != null and td.get_custom_data("walkable")
