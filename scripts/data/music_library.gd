class_name MusicLibrary
extends RefCounted
## Background-music lookup, by convention: `assets/audio/music/<track id>.{ogg,wav,mp3}`.
##
## Same optional-art contract as scripts/data/portraits.gd / sfx_library.gd: SoundManager treats
## a missing id as a silent no-op (keeps whatever was already playing). See
## assets/audio/README.md for the id vocabulary and file spec.

const DIR := "res://assets/audio/music/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

static var _cache: Dictionary = {}


## The track for a music id, or null when no matching file exists yet.
static func for_id(id: String) -> AudioStream:
	if id.is_empty():
		return null
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := DIR + id + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_cache[id] = stream
	return stream


## Drop the memo (used by tests; also handy if audio is added while the game is running).
static func clear_cache() -> void:
	_cache = {}
