extends SceneTree
## Project health check ("doctor"). Catches the footguns that have actually bitten
## this project. Exit code 0 = healthy, 1 = problems found.
##
## Run:  Godot_console.exe --headless --path <project> --script res://tools/doctor.gd
##
## Checks:
##   1. No directory is named like a file (e.g. a `player.gd` folder) — a GDScript
##      file cannot share a path with a directory.
##   2. application/run/main_scene is set and the file exists.
##   3. Every .gd / .tscn / .tres under res:// actually loads (catches parse errors
##      and broken ext_resource references).

const SKIP_DIRS := [".godot", ".git", "android"]
const FILE_LIKE_EXTS := [".gd", ".tscn", ".tres", ".png", ".import"]
const LOADABLE_EXTS := [".gd", ".tscn", ".tres"]

var _problems: Array[String] = []
var _dirs: Array[String] = []
var _files: Array[String] = []


func _init() -> void:
	_scan("res://")
	_check_file_named_dirs()
	_check_main_scene()
	_check_resources_load()
	_report()


## Walk res:// once, collecting directories and files (skipping engine/vcs dirs).
func _scan(root: String) -> void:
	var stack: Array[String] = [root]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		for sub in da.get_directories():
			if SKIP_DIRS.has(sub):
				continue
			var sub_path := dir_path.path_join(sub)
			_dirs.append(sub_path)
			stack.append(sub_path)
		for f in da.get_files():
			_files.append(dir_path.path_join(f))


func _check_file_named_dirs() -> void:
	for dir_path in _dirs:
		var dname := dir_path.get_file()
		for ext in FILE_LIKE_EXTS:
			if dname.ends_with(ext):
				_problems.append("Directory named like a file (should be a %s file, not a folder): %s"
					% [ext, dir_path])
				break


func _check_main_scene() -> void:
	var ms: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if ms == "":
		_problems.append("application/run/main_scene is not set.")
	elif not ResourceLoader.exists(ms):
		_problems.append("main_scene points at a missing resource: " + ms)


func _check_resources_load() -> void:
	for file_path in _files:
		for ext in LOADABLE_EXTS:
			if file_path.ends_with(ext):
				if ResourceLoader.load(file_path) == null:
					_problems.append("Failed to load (parse error or broken reference): " + file_path)
				break


func _report() -> void:
	if _problems.is_empty():
		print("doctor: OK — scanned %d dirs / %d files, no problems found." % [_dirs.size(), _files.size()])
		quit(0)
	else:
		print("doctor: %d problem(s) found:" % _problems.size())
		for p in _problems:
			print("  x ", p)
		quit(1)
