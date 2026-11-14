extends Area2D
## scenes/rooms/parts/AcidPool.tscn — the hurt zone over an acid pit (placed by the room builder).
## While Limus overlaps it he takes 10 damage (then i-frames) and is bounced out.
## The visible acid is the room's "Acid" TileMapLayer; this node adds the hurt zone and bubbles.
## Child nodes: Shape (CollisionShape2D, local to scene), Bubbles (CPUParticles2D).

@export var size_px := Vector2(128, 64)


func _ready() -> void:
	($Shape.shape as RectangleShape2D).size = size_px
	$Bubbles.emission_rect_extents = Vector2(size_px.x / 2.0, 4)
	$Bubbles.amount = int(max(2, size_px.x / 40))


func _physics_process(_d: float) -> void:
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and b.has_method("acid_contact"):
			b.acid_contact()
