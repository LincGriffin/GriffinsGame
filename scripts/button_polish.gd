class_name ButtonPolish
extends RefCounted
## Small hover juice for dynamically-created buttons: a slight scale-up tween on hover (back to
## normal on exit) plus a "ui_hover" sound. Call once right after creating a Button — used by
## starter_select.gd's cards and battle.gd's command/monster-select buttons.

const HOVER_SCALE := 1.06
const TWEEN_TIME := 0.08


static func apply(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func():
		_play_hover(b)
		_scale_to(b, HOVER_SCALE))
	b.mouse_exited.connect(func(): _scale_to(b, 1.0))


static func _scale_to(b: Button, s: float) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * s, TWEEN_TIME)


static func _play_hover(b: Button) -> void:
	var sound := b.get_node_or_null("/root/SoundManager")
	if sound != null:
		sound.play_sfx("ui_hover")
