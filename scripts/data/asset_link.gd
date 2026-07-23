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


static func clear_image(dir: String, id: String) -> bool:
	var path := dir + id + ".png"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
