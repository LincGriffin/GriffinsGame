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

## Optional per-move effects, referenced by id so moves can share or swap them (see battle.gd).
## Both are OPTIONAL and fall back gracefully:
##   sfx — a sound id under assets/audio/sfx/<sfx>.{ogg,wav,mp3} (SfxLibrary). Blank → the
##         per-kind default "move_<kind>", so audio is unchanged unless a move overrides it.
##   vfx — a PackedScene id under assets/vfx/<vfx>.tscn (VfxLibrary), played at the target/caster.
##         Blank (or no file) → no extra effect, just the built-in flash/shake/popup feedback.
@export var sfx: String = ""
@export var vfx: String = ""
