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

## Turns this move is unavailable after use (0 = usable every turn). Non-basic moves get 1, so they
## can only be used every other turn; the basic Strike stays 0. Battle enforces it per-combatant
## (the command menu greys out a cooled move; the enemy picker skips one). See scripts/battle.gd.
## Editable per-move (gen_moves.gd, or the Moves editor dock).
@export var cooldown: int = 0

## When true, the move takes a full turn to CHARGE before it fires: on the turn it's chosen the
## caster only charges (the opponent still acts), then the move auto-resolves on the caster's next
## turn. A telegraphed, higher-risk hit. Off by default; toggle per-move. Handled on both sides.
@export var charge: bool = false

## Optional per-move effects, referenced by id so moves can share or swap them (see battle.gd).
## Both are OPTIONAL and fall back gracefully:
##   sfx — a sound id under assets/audio/sfx/<sfx>.{ogg,wav,mp3} (SfxLibrary). Blank → the
##         per-kind default "move_<kind>", so audio is unchanged unless a move overrides it.
##   vfx — a PackedScene id under assets/vfx/<vfx>.tscn (VfxLibrary), played at the target/caster.
##         Blank (or no file) → no extra effect, just the built-in flash/shake/popup feedback.
@export var sfx: String = ""
@export var vfx: String = ""
