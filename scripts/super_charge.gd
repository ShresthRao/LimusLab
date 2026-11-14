extends Node2D
## scenes/fx/SuperCharge.tscn — the 3-second "super is activating" effect around Limus.
## Rings: fire rings that keep collapsing inward (looping).  Pillar: a flame pillar that grows from a
## spark into a full blaze over the 3 seconds.  Sparks: particles pulled in toward Limus.
## The pulse speeds up as the charge fills; player.gd frees this node when the super releases.

const DURATION := 3.0
var t := 0.0

@onready var rings: AnimatedSprite2D = $Rings
@onready var pillar: AnimatedSprite2D = $Pillar


func _ready() -> void:
	rings.play("default")
	pillar.play("default")


func _process(d: float) -> void:
	t += d
	var k: float = clamp(t / DURATION, 0.0, 1.0)
	rings.speed_scale = 1.0 + 2.0 * k                 # rings collapse faster and faster
	var pulse := 1.0 + 0.08 * sin(t * (10.0 + 30.0 * k))
	rings.scale = Vector2.ONE * (7.0 + 2.0 * k) * pulse
	pillar.modulate.a = 0.55 + 0.45 * k
	$Sparks.speed_scale = 1.0 + 2.0 * k
