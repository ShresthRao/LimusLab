extends Area2D
## scenes/actors/Projectile.tscn — slime bubbles (player) and acid globs (enemies).
## Child nodes: Sprite (Sprite2D), Shape (CollisionShape2D), Trail (CPUParticles2D).
##
## Player bubble rules:
##   * World hit (wall/floor/ceiling/platform): bounces ONCE, +30% damage. Second world hit -> explode.
##   * Enemy hit: damages that enemy, then RICOCHETS in a bouncy arc toward the nearest enemy it
##     has not hit yet (up to `ricochets` times). With no target left it explodes (area damage).
## World hits come from a ray each frame (so we know the surface normal); enemy/player hits come
## from the Area2D overlap.

var vel := Vector2.ZERO
var grav := 0.0
var damage := 1.0
var chem := 0
var from_player := true
var radius := 0.0      # > 0 = explodes with area damage
var bounces := 0       # world bounces left; each adds +30% damage
var ricochets := 0     # enemy-to-enemy ricochets left
var bounced := false
var life := 2.5
var done := false
var t := 0.0
var hit_list := []     # enemies already hit by this bubble

const BOUNCE_BONUS := 1.3
const RICOCHET_RANGE := 480.0
const RICOCHET_TIME := 0.45   # seconds of flight for each ricochet arc

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	collision_mask = 4 if from_player else 2   # targets only; the world is ray-cast
	if from_player or chem != Chem.ACID:
		sprite.texture = load("res://assets/fx/bubble_%d.png" % chem)   # Green / Water / Fire / Purple orbs
	else:
		sprite.texture = load("res://assets/fx/glob.png")
	if not from_player:
		sprite.self_modulate = Color(1.3, 1.3, 1.3)
	body_entered.connect(_on_body)
	sprite.scale = Vector2.ONE * 0.5   # pop-in
	create_tween().tween_property(sprite, "scale", Vector2(Chem.PIXEL, Chem.PIXEL), 0.12).set_trans(Tween.TRANS_BACK)


func _physics_process(d: float) -> void:
	if done:
		return
	t += d
	vel.y += grav * d
	var step := vel * d
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 8.0, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		if bounces > 0:
			_bounce(hit.position, hit.normal)
		else:
			global_position = hit.position
			_pop()
		return
	global_position += step
	sprite.rotation += d * 8.0 * sign(vel.x)
	var stretch: float = clamp(vel.length() / 2500.0, 0.0, 0.25)
	if sprite.scale.x > 1.5:  # after pop-in, stretch along travel direction
		sprite.scale = Vector2(Chem.PIXEL * (1.0 + stretch), Chem.PIXEL * (1.0 - stretch))
	life -= d
	if life <= 0:
		_pop()


func _squash_flash() -> void:
	sprite.self_modulate = Color(1.6, 1.6, 1.6)
	sprite.scale = Vector2(Chem.PIXEL * 1.5, Chem.PIXEL * 0.6)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(Chem.PIXEL * 1.15, Chem.PIXEL * 1.15), 0.15).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)


func _bounce(at: Vector2, normal: Vector2) -> void:
	bounces -= 1
	bounced = true
	damage *= BOUNCE_BONUS
	global_position = at + normal * 9.0
	vel = vel.bounce(normal) * 0.8
	if vel.length() < 260:
		vel = vel.normalized() * 260
	life = max(life, 1.2)
	_squash_flash()
	Chem.fx(get_parent(), "slash_%d" % chem, at, 2.0, 24.0)


func _on_body(b) -> void:
	if done or b in hit_list:
		return
	if not from_player:
		if b.has_method("hit"):
			b.hit(damage, chem, self)
		_pop()
		return
	# player bubble hit an enemy
	hit_list.append(b)
	var target = _next_target(b)
	if target == null or ricochets <= 0:
		_pop()
		return
	b.hit(damage, chem, self)
	ricochets -= 1
	_ricochet_to(target)


## Nearest living enemy this bubble has not hit yet, within range.
func _next_target(from_enemy):
	var best = null
	var best_d := RICOCHET_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == from_enemy or e in hit_list or not is_instance_valid(e) or e.dead:
			continue
		var dist := global_position.distance_to(e.global_position)
		if dist < best_d:
			best_d = dist
			best = e
	return best


## Bounce off the enemy we just hit and arc onto the next one (ballistic launch).
func _ricochet_to(target) -> void:
	var to: Vector2 = target.global_position + Vector2(0, -6) - global_position
	var tt := RICOCHET_TIME
	vel = Vector2(to.x / tt, (to.y - 0.5 * grav * tt * tt) / tt)
	life = max(life, tt + 0.6)
	global_position += Vector2(0, -6)
	_squash_flash()
	Chem.fx(get_parent(), "slash_%d" % chem, global_position, 2.5, 26.0)
	Chem.shake(2.5)


func _pop() -> void:
	if done:
		return
	done = true
	if radius > 0:
		var grp := "enemies" if from_player else "player"
		for tgt in get_tree().get_nodes_in_group(grp):
			if tgt.global_position.distance_to(global_position) <= radius + 16:
				tgt.hit(damage, chem, self)
		var scl: float = round(radius / 12.0) + (1.0 if bounced else 0.0)
		Chem.fx(get_parent(), "boom_%d" % chem, global_position, scl, 14.0)
		Chem.shake(5.0 if bounced else 3.5)
	else:
		Chem.fx(get_parent(), "boom_%d" % chem, global_position, 1.5, 18.0)
	queue_free()
