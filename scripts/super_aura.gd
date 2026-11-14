extends Node2D
## scenes/fx/SuperAura.tscn — shown behind Limus while the super is active (30 s).
## Wheel: a spinning fire wheel (Fire pack) that slowly turns and breathes.  Embers: rising sparks.

var t := 0.0

@onready var wheel: AnimatedSprite2D = $Wheel


func _ready() -> void:
	wheel.play("default")


func _process(d: float) -> void:
	t += d
	wheel.rotation += d * 2.0
	wheel.scale = Vector2.ONE * (3.6 + 0.3 * sin(t * 5.0))
