class_name MonsterData
extends Resource
## Static definition of a monster. The SAME type describes both wild enemies and the
## monsters the player recruits — defeating a wild monster turns its data into a party
## member. Instances are generated into assets/data/monsters/*.tres by
## tools/gen_content.gd, so all balancing lives in data (edit the table there and
## re-run the generator) rather than in code.

@export var id: String = ""
@export var display_name: String = "Monster"
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
@export var speed: int = 5           # higher acts first in a round
@export var is_boss: bool = false    # the final boss; defeating it wins the run
@export var is_starter: bool = false # eligible to be offered as a run-start starter
@export var tint: Color = Color.WHITE   # placeholder sprite colour
