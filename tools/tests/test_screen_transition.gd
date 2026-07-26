extends "res://tools/tests/_base.gd"
## ScreenTransition: cover() raises a top-most, input-blocking layer; reveal() tears it back down.
## The fade is the baseline visual; the Kind argument is the seam for varied transitions later (all
## Kinds fade today), so these tests assert the cover/reveal CONTRACT — a fully-opaque, click-eating
## cover appears, then is fully cleared and freed — not the specific look.

const SCREEN_TRANSITION := preload("res://scripts/screen_transition.gd")

var _host: Node


func before_each() -> void:
	_host = Node.new()
	runner.root.add_child(_host)
	await idle()


func after_each() -> void:
	_host.queue_free()
	await idle()


func test_cover_raises_a_blocking_layer_then_reveal_clears_it() -> void:
	var t = SCREEN_TRANSITION.new(_host)
	check(not t.is_covering(), "a fresh transition isn't covering")
	await t.cover(SCREEN_TRANSITION.Kind.BATTLE)
	check(t.is_covering(), "cover() raises the transition")
	var layer := _find_layer(_host)
	check(layer != null, "cover() added a CanvasLayer to the host")
	if layer != null:
		check(layer.layer >= 60, "the cover sits above every other overlay")
		var rect = layer.get_child(0)
		check(rect is ColorRect, "the layer holds a ColorRect cover")
		eq(rect.color.a, 1.0, "the cover ends fully opaque (screen hidden)")
		eq(rect.mouse_filter, Control.MOUSE_FILTER_STOP, "the cover eats input while raised")
	await t.reveal(SCREEN_TRANSITION.Kind.BATTLE)
	check(not t.is_covering(), "reveal() clears the covering state")
	await idle()
	check(_find_layer(_host) == null, "reveal() frees the transition layer")


func test_a_second_cover_while_covered_does_not_stack() -> void:
	var t = SCREEN_TRANSITION.new(_host)
	await t.cover()
	await t.cover()   # already covering — must be a no-op, not a second layer
	eq(_count_layers(_host), 1, "a second cover() keeps a single transition layer")
	await t.reveal()


func test_reveal_with_nothing_covering_is_safe() -> void:
	var t = SCREEN_TRANSITION.new(_host)
	await t.reveal()   # no crash, no layer created
	check(not t.is_covering(), "reveal() with nothing covering stays uncovered")
	eq(_count_layers(_host), 0, "reveal() on a fresh transition adds no layer")


# --- helpers ---

func _find_layer(host: Node) -> CanvasLayer:
	for c in host.get_children():
		if c is CanvasLayer:
			return c
	return null


func _count_layers(host: Node) -> int:
	var n := 0
	for c in host.get_children():
		if c is CanvasLayer:
			n += 1
	return n
