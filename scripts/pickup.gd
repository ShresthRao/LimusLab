extends Node2D
## scenes/actors/Pickup.tscn — a material dropped by a monster.
## Pops out spinning, lands on the floor below it, bobs and sparkles, gets pulled toward Limus and
## is absorbed on touch: adds the material to the inventory and heals (extra HP becomes overheal).
## Child nodes: Sprite (Sprite2D), Sparkle (CPUParticles2D).

var id := "acid_gel"
var player
var t := 0.0
var vel := Vector2.ZERO
var taken := false
var rest_y := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = Chem.icon(id)
	sprite.scale = Vector2.ZERO
	vel = Vector2(randf_range(-110, 110), -300)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	# find the floor under the drop
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -20), global_position + Vector2(0, 700), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	rest_y = (hit.position.y - 14.0) if hit else global_position.y
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(Chem.PIXEL, Chem.PIXEL) * 1.3, 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(sprite, "scale", Vector2(Chem.PIXEL, Chem.PIXEL), 0.1)


func _physics_process(d: float) -> void:
	if taken:
		return
	t += d
	if t < 0.6:   # pop-out arc with a spin, small bounce on the floor
		vel.y += 1100 * d
		position += vel * d
		sprite.rotation += d * 14.0 * sign(vel.x)
		if global_position.y > rest_y:
			global_position.y = rest_y
			vel.y *= -0.35
			vel.x *= 0.5
		return
	sprite.rotation = lerp_angle(sprite.rotation, 0.0, 10 * d)
	sprite.position.y = sin(t * 4) * 3
	if not is_instance_valid(player) or player.dead:
		return
	var to: Vector2 = player.global_position - global_position
	if to.length() < 170:
		position += to.normalized() * min(to.length(), (300 + 900 * (1.0 - to.length() / 170.0)) * d)
	if to.length() < 22:
		_collect()


func _collect() -> void:
	taken = true
	var amt: float = player.collect(id)
	Chem.hud_toast("+1 %s   +%d HP" % [Chem.MATERIALS[id]["name"], int(amt)])
	Chem.fx(get_parent(), "slash_%d" % player.chem, player.global_position, 2.5, 26.0)
	player.squash = Vector2(1.2, 0.85)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", player.global_position + Vector2(0, -6), 0.1)
	tw.tween_property(sprite, "scale", Vector2(0.5, 3.0), 0.1)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
