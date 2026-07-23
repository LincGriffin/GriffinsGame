class_name MoveData
extends Resource
## A battle move — effect-based, no elemental types. Generated into
## assets/data/moves/*.tres by tools/gen_moves.gd (edit the table there to rebalance).
## `kind` selects the effect:
##   "attack" — deal damage: attacker.attack (+ atk_bonus) + power - floor(target.defense / 2)
##   "guard"  — brace this turn (halves the incoming hit)
##   "heal"   — restore `power` HP to the user
##   "drain"  — deal damage like "attack", then heal the user for half the damage dealt
##   "buff"   — raise the user's attack by `power` for the rest of the battle

@export var id: String = ""
@export var display_name: String = "Move"
@export var kind: String = "attack"   # attack | guard | heal | drain | buff
@export var power: int = 0
@export var description: String = ""
