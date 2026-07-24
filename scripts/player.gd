class_name Player
extends CharacterBody2D
## Grid-step overworld movement.
##
## The grid is authoritative: the player always occupies exactly one whole tile.
## A Tween only animates the *visual* glide between tiles — the logical position
## (`grid_cell`) snaps instantly. Wall collision is a pre-move query against the
## TileMapLayer's "walkable" custom data, NOT physics, so there is never a
## partial-tile or sliding state (we deliberately don't call move_and_slide).

const TILE_SIZE := 64          # kept for reference; positioning uses map_to_local
const MOVE_TIME := 0.12        # seconds to glide one tile

const MAP_SPRITES := preload("res://scripts/data/map_sprites.gd")
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const GLOW_COLOR := Color(1.0, 0.88, 0.42)   # a warm "this is you" aura under the avatar

var _glow: Sprite2D

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
var _sound: Node   # SoundManager autoload, looked up at runtime; null in headless/test contexts

# Iteration order sets input priority when two directions are held at once.
const DIRECTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}


func _ready() -> void:
	add_to_group("player")   # so the debug overlay can find the player in any scene
	_sound = get_node_or_null("/root/SoundManager")
	_build_glow()


## A soft, gently-pulsing radial aura rendered BEHIND the avatar — marks the sprite as the player
## (built at runtime so it needs no art asset; additive blend works under GL Compatibility).
func _build_glow() -> void:
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.z_index = -1
	var grad := Gradient.new()
	grad.set_color(0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.5))
	grad.set_color(1, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 112
	tex.height = 112
	_glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "scale", Vector2(1.12, 1.12), 0.9).from(Vector2(0.9, 0.9)) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "scale", Vector2(0.9, 0.9), 0.9).set_trans(Tween.TRANS_SINE)


## Show `monster`'s overworld art (its map sprite; falls back to portrait, then the default
## player.png) as the avatar. Called by the dungeon when the lead monster changes.
func set_monster_appearance(monster) -> void:
	var sprite := get_node_or_null("Sprite2D")
	if sprite == null or monster == null:
		return
	var tex = MAP_SPRITES.for_monster(monster)
	if tex == null:
		tex = PORTRAITS.for_monster(monster)
	if tex == null:
		return   # no art for this monster → keep the default sprite
	sprite.texture = tex
	var largest: int = max(tex.get_width(), tex.get_height())
	if largest > 0:
		sprite.scale = Vector2.ONE * (float(TILE_SIZE) / largest)


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
		_sfx("blocked")
		return

	is_moving = true
	grid_cell = target
	var tween := create_tween()
	tween.tween_property(self, "position", tile_map_layer.map_to_local(target), MOVE_TIME)
	await tween.finished
	is_moving = false
	moved.emit(grid_cell)
	_sfx("step")


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)


## A cell is walkable only if it holds a tile whose "walkable" custom data is true.
## Empty / out-of-bounds cells (no tile) are treated as blocked.
func _is_walkable(cell: Vector2i) -> bool:
	if tile_map_layer == null:
		return false
	var td := tile_map_layer.get_cell_tile_data(cell)
	return td != null and td.get_custom_data("walkable")
