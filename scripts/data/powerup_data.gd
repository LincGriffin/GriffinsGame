class_name PowerupData
extends Resource
## A power-up definition — one upgrade the power-up chooser (scripts/powerup_select.gd) can offer.
## Data-driven (like MonsterData / MoveData) so it's editable via the power-up editor dock without
## hand-editing code. Generated into assets/data/powerups/*.tres by tools/gen_powerups.gd.
##
## `effect` selects what applying it does (run.gd::_grant_upgrade):
##   "hp"      — raise the recipient's max HP by `amount` (and heal that much)
##   "attack"  — raise the recipient's attack by `amount`
##   "defense" — raise the recipient's defense by `amount`
##   "move"    — teach the recipient the move whose id is `move_id`

@export var id: String = ""
@export var display_name: String = "Power-up"
@export var description: String = ""
@export var effect: String = "hp"        # hp | attack | defense | move
@export var amount: int = 5              # stat delta for hp/attack/defense (ignored for "move")
@export var move_id: String = ""         # the move to teach when effect == "move"
@export var tint: Color = Color(0.6, 0.6, 0.6)   # fallback swatch when it has no portrait/sprite art
