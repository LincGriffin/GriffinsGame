class_name AssetLink
extends RefCounted
## Copies an author-supplied image into one of the project's optional-art conventions
## (assets/portraits/<id>.png, assets/map_sprites/<id>.png) — the plumbing behind the
## monster editor dock's Browse/Clear buttons. Kept separate from the dock so it has no
## EditorPlugin dependency and can be unit-tested headless.
##
## `src_path` is an absolute OS filesystem path (e.g. from an EditorFileDialog).
## `dir` is a res:// directory (Portraits.DIR / MapSprites.DIR); `id` is the monster id.


static func import_image(src_path: String, dir: String, id: String) -> Dictionary:
	if id.is_empty():
		return {"ok": false, "error": "save the monster before assigning art"}
	if not FileAccess.file_exists(src_path):
		return {"ok": false, "error": "source file not found: " + src_path}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var dest := dir + id + ".png"
	var err := DirAccess.copy_absolute(src_path, ProjectSettings.globalize_path(dest))
	if err != OK:
		return {"ok": false, "error": "copy failed (engine error %d)" % err}
	return {"ok": true, "path": dest}


## Like import_image but keeps the source file's extension instead of forcing .png — for the
## move-editor's sfx (.wav/.ogg/.mp3 → assets/audio/sfx/) and vfx (.tscn → assets/vfx/) uploads,
## whose convention lookups (SfxLibrary / VfxLibrary) try several extensions. `id` names the
## destination file (the move's sfx/vfx id). Returns the copied res:// path on success.
##
## Note: a copied `.tscn` should be self-contained (embedded sub-resources) — a scene that
## references external files by path won't bring them along. The generated assets/vfx/*.tscn are.
static func import_file(src_path: String, dir: String, id: String) -> Dictionary:
	if id.is_empty():
		return {"ok": false, "error": "set an id before assigning a file"}
	if not FileAccess.file_exists(src_path):
		return {"ok": false, "error": "source file not found: " + src_path}
	var ext := src_path.get_extension().to_lower()
	if ext.is_empty():
		return {"ok": false, "error": "source file has no extension: " + src_path}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var dest := dir + id + "." + ext
	var err := DirAccess.copy_absolute(src_path, ProjectSettings.globalize_path(dest))
	if err != OK:
		return {"ok": false, "error": "copy failed (engine error %d)" % err}
	return {"ok": true, "path": dest}


static func clear_image(dir: String, id: String) -> bool:
	var path := dir + id + ".png"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
