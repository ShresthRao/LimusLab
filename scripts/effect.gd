extends AnimatedSprite2D
## scenes/fx/Effect.tscn — plays its SpriteFrames once ("default"), then frees itself.
## Chem.fx() sets sprite_frames, position and scale before adding it to the tree.

func _ready() -> void:
	z_index = 5
	animation_finished.connect(queue_free)
	play("default")
