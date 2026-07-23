extends "res://tools/tests/_base.gd"
## SoundManager is the only thing that touches live AudioStreamPlayer nodes. With zero real audio
## files present (the state this repo ships in), every call must be a safe no-op — these tests
## prove that contract, plus that bus setup is idempotent across instances.

var sm


func before_each() -> void:
	sm = load("res://autoload/sound_manager.gd").new()
	runner.root.add_child(sm)
	await idle()   # let _ready() build the buses + player pool


func after_each() -> void:
	sm.queue_free()
	await idle()


func test_ready_creates_the_audio_buses() -> void:
	check(AudioServer.get_bus_index("SFX") != -1, "the SFX bus exists after _ready")
	check(AudioServer.get_bus_index("Music") != -1, "the Music bus exists after _ready")


func test_play_sfx_with_missing_id_does_not_consume_a_pool_slot() -> void:
	sm.play_sfx("definitely_not_a_real_sfx_id")
	eq(sm._next_sfx, 0, "a missing sfx id returns before advancing the round-robin pool")
	check(not sm._sfx_pool[0].playing, "no pooled player started for a missing id")


func test_play_music_with_missing_id_is_a_silent_no_op() -> void:
	sm.play_music("definitely_not_a_real_track_id")
	eq(sm._current_music_id, "", "a missing music id never becomes the current track")
	check(not sm._music_player.playing, "the music player never started for a missing id")


func test_play_music_with_the_same_id_twice_does_not_restart() -> void:
	sm._current_music_id = "already_playing"   # simulate a track already selected
	sm.play_music("already_playing")
	check(not sm._music_player.playing, "re-requesting the current track is a no-op (no lookup, no play)")


func test_ensure_bus_is_idempotent_across_instances() -> void:
	var before := AudioServer.bus_count
	var sm2 = load("res://autoload/sound_manager.gd").new()
	runner.root.add_child(sm2)
	await idle()
	eq(AudioServer.bus_count, before, "a second instance does not duplicate the SFX/Music buses")
	sm2.queue_free()
	await idle()
