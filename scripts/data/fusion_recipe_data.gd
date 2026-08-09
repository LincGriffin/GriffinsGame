class_name FusionRecipeData
extends Resource
## A single monster-merge recipe: fusing `parent_a` + `parent_b` (two monster ids — order doesn't
## matter, and they CAN be the same id, e.g. griffin+griffin) produces `result_id` (a real roster
## monster) instead of the generic "Fused <parent>" blend (see MonsterMerge). Data-driven (like
## MonsterData/MoveData/PowerupData) so it's editable via the Fusions dock
## (addons/fusion_editor/) without hand-editing scripts/data/fusion_table.gd. Generated into
## assets/data/fusions/*.tres by tools/gen_fusions.gd.
##
## `id` is NOT freely chosen — it's derived from the sorted parent pair (FusionRepo.id_for), so a
## given pair can only ever have one recipe. The dock only exposes Parent A / Parent B / Result
## pickers, not a raw id field.

@export var id: String = ""
@export var parent_a: String = ""
@export var parent_b: String = ""
@export var result_id: String = ""
