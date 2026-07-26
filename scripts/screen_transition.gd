class_name ScreenTransition
extends RefCounted
## A two-phase screen transition played over the whole game: `cover()` hides the current screen,
## the caller swaps whatever is underneath (open a battle, a chooser, heal the party…), then
## `reveal()` shows the new screen. It runs on a top-most `CanvasLayer` (above every other overlay)
## whose full-rect `ColorRect` also eats mouse input while raised, so the swap is never seen or
## clicked through.
##
## Construct one per screen owner and reuse it:
##     _transition = ScreenTransition.new(self)   # self = a Node that lives in the tree
##     await _transition.cover(ScreenTransition.Kind.BATTLE)
##     add_child(battle)                          # swap happens behind the cover
##     await _transition.reveal(ScreenTransition.Kind.BATTLE)
##
## ── Plan for richer transitions later ────────────────────────────────────────────────────────
## TODAY every `Kind` resolves to the same simple fade-to-black (`_fade`). The `Kind` argument is
## the EXTENSION SEAM: call sites in run.gd already pass a *distinct* kind per node type, so they
## never change when the visuals diverge. To add a dynamic/varied transition later:
##   1. Keep the Kind (or add one) and branch in `_cover`/`_reveal` on it.
##   2. Implement the new look as a `_cover_<style>()` / `_reveal_<style>()` pair — e.g. an IRIS
##      wipe (animate a circular mask), a diagonal SWIPE (slide a shaped `ColorRect`/`Polygon2D`),
##      a glass-SHATTER or PIXELATE (a `ShaderMaterial` on the cover rect driven by a uniform the
##      tween animates), or a themed flash (green for heal, gold for treasure, red for battle).
##   3. Route the Kind → style in one place here. run.gd is untouched.
## Because cover/reveal are a matched pair around an awaited swap, any style just needs to (a) end
## fully opaque on cover and (b) end fully clear on reveal; everything between is free.
## See docs/DESIGN.md → "Screen transitions".

## One value per situation that MIGHT eventually want its own look. All map to a fade today.
enum Kind { FADE, BATTLE, POWERUP, HEAL, TREASURE, TELEPORT }

const FADE_TIME := 0.25

var _host: Node                     # a Node in the live tree — creates the tweens, parents the layer
var _layer: CanvasLayer = null      # non-null exactly while a cover is raised


func _init(host: Node) -> void:
	_host = host


## True between a cover() and its reveal() — a transition is currently hiding the screen.
func is_covering() -> bool:
	return _layer != null


## Raise the transition to hide the screen. `await` this, then swap what's underneath. A second
## cover() while already covering is a no-op (keeps the existing cover).
func cover(kind := Kind.FADE) -> void:
	if _layer != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 60   # above every other overlay (Settings 45, DebugOverlay 50, battle/menus 30)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks on whatever is mid-swap underneath
	layer.add_child(rect)
	_host.add_child(layer)
	_layer = layer
	await _play(rect, kind, true)


## Drop the transition to reveal whatever was swapped in. No-op if nothing is covering.
func reveal(kind := Kind.FADE) -> void:
	if _layer == null:
		return
	var rect: ColorRect = _layer.get_child(0)
	await _play(rect, kind, false)
	_layer.queue_free()
	_layer = null


## Dispatch a Kind to its visual. Every kind is a fade today — see the "Plan" note above for how a
## kind gets its own `_cover_<style>`/`_reveal_<style>` implementation without touching call sites.
func _play(rect: ColorRect, _kind: int, covering: bool) -> void:
	await _fade(rect, 1.0 if covering else 0.0)


## The baseline transition: tween the cover rect's alpha to `target_a` over FADE_TIME.
func _fade(rect: ColorRect, target_a: float) -> void:
	var tw := _host.create_tween()
	tw.tween_property(rect, "color:a", target_a, FADE_TIME)
	await tw.finished
