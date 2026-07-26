extends Node2D
## Drives a one-shot move visual effect: fires every CPUParticles2D under this node once, then
## frees the whole scene after they've had time to finish. Attached to the generated effect scenes
## in assets/vfx/ (tools/gen_vfx.gd) so an effect is fully self-contained — battle.gd just
## instantiates it at an anchor and forgets it. battle.gd ALSO safety-frees after VFX_MAX_TIME, so
## a hand-authored effect that omits this script still won't leak.
##
## `life` is set slightly above the particles' own lifetime by the generator; a scene built by hand
## can leave it at the default.

@export var life: float = 0.7


func _ready() -> void:
	var longest := 0.0
	for child in get_children():
		if child is CPUParticles2D:
			child.emitting = false   # reset, then fire once so it always plays on spawn
			child.one_shot = true
			child.restart()
			child.emitting = true
			longest = maxf(longest, child.lifetime)
	var wait := maxf(life, longest + 0.15)
	# get_tree() can be null for a frame right after instantiation in odd contexts — guard it.
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(wait).timeout
	queue_free()
