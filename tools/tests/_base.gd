extends RefCounted
## Base class for headless test suites. Test files live in tools/tests/ named
## test_*.gd and `extends "res://tools/tests/_base.gd"` (path extend so a freshly
## written suite doesn't depend on the global class-name cache being rebuilt).
##
## Each `func test_*()` method is discovered and run by tools/run_tests.gd. Methods
## may be coroutines (use `await`). Optional `before_each()` / `after_each()` run
## around every test. Report results with `check()` / `eq()`.

var runner  # the TestRunner (a SceneTree) — injected before tests run


## Record a boolean assertion.
func check(cond: bool, label: String) -> void:
	if cond:
		runner.record_pass(label)
	else:
		runner.record_fail(label)


## Assert equality; the got/want detail is only shown when it fails.
func eq(actual, expected, label: String) -> void:
	if actual == expected:
		runner.record_pass(label)
	else:
		runner.record_fail("%s (got %s, want %s)" % [label, str(actual), str(expected)])


## Yield one processed frame (lets _ready, tweens, and signals advance).
func idle() -> void:
	await runner.process_frame
