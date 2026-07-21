extends SceneTree
## Headless test runner. Discovers every tools/tests/test_*.gd suite, runs each
## `test_*` method (with optional before_each/after_each), and reports a summary.
## Exit code 0 = all passed, 1 = at least one failure, 2 = timed out.
##
## Run:  Godot_console.exe --headless --path <project> --script res://tools/run_tests.gd

const TESTS_DIR := "res://tools/tests/"

var _pass := 0
var _fail := 0
var _failed: Array[String] = []


func _init() -> void:
	# Safety net so a hung await can never wedge CI / a pre-push hook.
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("run_tests: timed out")
		quit(2))
	_run()


func _run() -> void:
	var suites := _discover()
	if suites.is_empty():
		print("run_tests: no test_*.gd suites found in ", TESTS_DIR)
	for file in suites:
		var script: GDScript = load(TESTS_DIR + file)
		if script == null:
			record_fail("could not load suite " + file)
			continue
		var suite = script.new()
		suite.runner = self
		print("• ", file)
		for method in _test_methods(suite):
			if suite.has_method("before_each"):
				await suite.before_each()
			await suite.call(method)
			if suite.has_method("after_each"):
				await suite.after_each()
	_report()


func _discover() -> Array:
	var out: Array = []
	var d := DirAccess.open(TESTS_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out


func _test_methods(suite) -> Array:
	var names: Array = []
	for m in suite.get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and not names.has(n):
			names.append(n)
	names.sort()
	return names


func record_pass(label: String) -> void:
	_pass += 1
	print("  ok   ", label)


func record_fail(label: String) -> void:
	_fail += 1
	_failed.append(label)
	print(" FAIL  ", label)


func _report() -> void:
	print("\nTESTS: %d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		print("Failures:")
		for l in _failed:
			print("  - ", l)
	print("RESULT: ", "PASS" if _fail == 0 else "FAIL")
	quit(0 if _fail == 0 else 1)
