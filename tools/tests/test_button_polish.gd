extends "res://tools/tests/_base.gd"
## Hover polish is cosmetic (a scale tween + an optional ui_hover sound); these tests only guard
## the wiring — no SoundManager autoload is present in this headless context, and there are no
## assertions on tween-animated values (timing-fragile and not meaningful to assert on headless).

const BUTTON_POLISH := preload("res://scripts/button_polish.gd")

var btn: Button


func before_each() -> void:
	btn = Button.new()
	btn.size = Vector2(100, 40)
	runner.root.add_child(btn)
	await idle()


func after_each() -> void:
	btn.queue_free()
	await idle()


func test_apply_wires_hover_signals_without_erroring() -> void:
	BUTTON_POLISH.apply(btn)
	btn.emit_signal("mouse_entered")
	btn.emit_signal("mouse_exited")
	await idle()
	check(true, "applying polish and emitting hover signals (no SoundManager present) does not error")


func test_resize_keeps_the_scale_pivot_centered() -> void:
	BUTTON_POLISH.apply(btn)
	btn.size = Vector2(200, 80)
	await idle()
	eq(btn.pivot_offset, btn.size / 2.0, "resizing recenters the pivot so scale grows from the middle")
