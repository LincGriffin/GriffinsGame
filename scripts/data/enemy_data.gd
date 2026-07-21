class_name EnemyData
extends Resource
## Static definition of an enemy. Instances are generated into
## assets/data/enemies/*.tres by tools/gen_content.gd, so all balancing lives in
## data (edit the table there and re-run the generator) rather than in code.

@export var id: String = ""
@export var display_name: String = "Enemy"
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
@export var speed: int = 5          # higher acts first in a round
@export var xp_reward: int = 5
@export var is_boss: bool = false   # the final boss; defeating it wins the game
@export var tint: Color = Color.WHITE   # placeholder sprite colour
