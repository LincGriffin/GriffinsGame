extends Node
## Plays SFX and music by convention-based id lookup (SfxLibrary / MusicLibrary), so adding or
## swapping a sound is just dropping a file at `assets/audio/{sfx,music}/<id>.*` — no code or
## data changes. Registered as the autoload singleton `SoundManager`. Missing audio is always a
## silent no-op, so the game runs fine with zero sound files present (same contract as
## Portraits/MapSprites). Scripts reach it via `get_node_or_null("/root/SoundManager")` rather
## than the global identifier, same reasoning as RunState (generators/tests never depend on
## autoload registration order).

const SFX_LIBRARY := preload("res://scripts/data/sfx_library.gd")
const MUSIC_LIBRARY := preload("res://scripts/data/music_library.gd")

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const SFX_POOL_SIZE := 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _music_player: AudioStreamPlayer
var _current_music_id := ""


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


## Create `bus_name` routed to Master if it doesn't already exist. Idempotent — safe to call
## every time a SoundManager instance is readied (e.g. across tests).
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


## Play a one-shot sound effect by event id. No-op if that id has no audio file yet. Uses a
## small round-robin pool so overlapping sounds (e.g. a footstep and an attack) don't cut each
## other off.
func play_sfx(id: String) -> void:
	var stream := SFX_LIBRARY.for_id(id)
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	player.stream = stream
	player.play()


## Switch the looping background track by id. No-op (keeps whatever's already playing) if the
## id has no audio file yet, or if it's already the current track. Looping is handled here (via
## `finished`) rather than relying on each file's own loop metadata, so any dropped-in file loops
## correctly with zero import fiddling.
func play_music(id: String) -> void:
	if id == _current_music_id:
		return
	var stream := MUSIC_LIBRARY.for_id(id)
	if stream == null:
		return
	_current_music_id = id
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_current_music_id = ""


func _on_music_finished() -> void:
	if _current_music_id != "":
		_music_player.play()
