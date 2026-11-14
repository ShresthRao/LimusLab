extends CharacterBody2D
## scenes/actors/Enemy.tscn — Floor-1 acid enemies.
## kind = "tank" (muddy slime, hops 2 tiles high) | "annoying" (imp, flies) | "ranged" (orc shaman,
## lobs acid) | "dummy" (training skeleton). subboss = true: 2x size, 5x HP and a special move.
## Child nodes (made in the scene): Sprite (AnimatedSprite2D), Shape (CollisionShape2D, local
## to scene so each enemy can resize it), FloorRay (RayCast2D used to stop at ledges).

signal died(e)

var PROJECTILE: PackedScene = load("res://scenes/actors/Projectile.tscn")
const GRAVITY := 1400.0
const HOP_V := -435.0   # 2-tile hop, same height as Limus' jump

@export_enum("tank", "annoying", "ranged", "dummy") var kind := "tank"
@export var subboss := false
@export var floor_i := 0       # which floor theme (Chem.FLOORS) this enemy belongs to
var display_name := ""
var dmg_bonus := 0.0
var player

var hp := 4.0
var max_hp := 4.0
var speed := 60.0
var chem := 0  # Acid
var dir := -1.0
var cd := 1.5
var hurt := 0.0
var touch_cd := 0.0
var knock := Vector2.ZERO
var t := 0.0
var flying := false
var retreat := 0.0
var charging := 0.0
var dead := false
var size := Vector2(32, 24)
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var ray: RayCast2D = $FloorRay
var hop_cd := 0.5
var was_on_floor := true
var base_scale := Vector2(2, 2)
var squash := Vector2.ONE
var windup := 0.0          # >0 while telegraphing an attack
var spawn_t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	match kind:
		"tank":
			hp = 8; speed = 55; size = Vector2(26, 24)
		"annoying":
			hp = 3; speed = 170; size = Vector2(22, 22); flying = true
		"ranged":
			hp = 4; speed = 50; size = Vector2(20, 28)
		"dummy":
			hp = 3; speed = 0; size = Vector2(20, 28)
	var sc := Chem.PIXEL
	if subboss:
		hp *= 5
		sc = Chem.PIXEL * 2
		speed *= 1.15
	max_hp = hp
	size *= sc / Chem.PIXEL
	# floor theme: sprite, tint, chemical, and difficulty scaling
	var fl: Dictionary = Chem.FLOORS[floor_i]
	var skin: Array = fl["enemies"][kind]
	sprite.sprite_frames = load("res://frames/%s.tres" % skin[0])  # 0x72 monsters
	sprite.self_modulate = skin[1]
	display_name = skin[2]
	chem = fl["chem"]
	if kind != "dummy":
		hp *= Chem.enemy_hp_mult(floor_i)
		max_hp = hp
		dmg_bonus = Chem.enemy_dmg_bonus(floor_i)
	sprite.play("idle")
	sprite.position.y = -size.y * 0.12
	base_scale = Vector2(sc, sc)
	sprite.speed_scale = randf_range(0.85, 1.15)  # so a group doesn't animate in lockstep
	# spawn: pop up out of the floor
	sprite.scale = Vector2(base_scale.x * 1.6, 0.05)
	spawn_t = 0.35
	($Shape.shape as RectangleShape2D).size = size
	ray.target_position = Vector2(0, size.y / 2 + 20)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	cd = randf_range(1.0, 2.0)


func _physics_process(d: float) -> void:
	if not is_instance_valid(player) or dead:
		return
	t += d
	cd -= d
	hurt = max(hurt - d, 0.0)
	touch_cd = max(touch_cd - d, 0.0)
	var to: Vector2 = player.global_position - global_position
	match kind:
		"tank": _tank(d, to)
		"annoying": _fly(d, to)
		"ranged": _ranged(d, to)
		"dummy": velocity.x = 0
	if not flying:
		velocity.y += GRAVITY * d
	velocity += knock
	knock *= 0.8
	move_and_slide()
	if flying:
		position.y = clamp(position.y, 50, 600)
	_animate(d)
	queue_redraw()
	if kind != "dummy" and touch_cd == 0 and abs(to.x) < size.x / 2 + 14 and abs(to.y) < size.y / 2 + 14:
		player.hit((15 if subboss else 10) + dmg_bonus, chem, self)
		touch_cd = 0.8


func _animate(d: float) -> void:
	sprite.flip_h = dir < 0  # 0x72 sprites face right
	sprite.play("run" if flying or abs(velocity.x) > 5 else "idle")
	if spawn_t > 0:
		spawn_t -= d
		sprite.scale = sprite.scale.lerp(base_scale, clamp(14.0 * d, 0, 1))
		return
	squash = squash.lerp(Vector2.ONE, clamp(10.0 * d, 0, 1))
	var s := squash
	if windup > 0:  # telegraph: swell and shake before attacking
		var k := 1.0 + 0.15 * sin(t * 40.0)
		s *= Vector2(1.0 / k, k)
		sprite.position.x = randf_range(-1.5, 1.5)
	else:
		sprite.position.x = 0
	if flying:
		sprite.rotation = clamp(velocity.x / 900.0, -0.35, 0.35)
	elif kind == "tank" and not is_on_floor():
		var v: float = clamp(abs(velocity.y) / 2000.0, 0, 0.2)
		s *= Vector2(1.0 - v, 1.0 + v)       # stretched while airborne
	elif abs(velocity.x) > 5:
		s *= Vector2(1.0, 1.0 + 0.06 * sin(t * 18.0))  # walk bob

	sprite.scale = base_scale * s
	if hurt > 0.05:
		sprite.modulate = Color(4, 4, 4)
	elif windup > 0:
		sprite.modulate = Color(1.0, 1.0 + 0.6 * abs(sin(t * 20.0)), 1.0)
	else:
		sprite.modulate = Color.WHITE


func _floor_ahead(move_dir: float, dist: float = 0.0) -> bool:
	ray.position.x = (size.x / 2 + dist) * move_dir
	ray.force_raycast_update()
	return not is_on_floor() or ray.is_colliding()


## Muddy slime: travels by hopping exactly 2 tiles high toward Limus.
## Sub-boss: telegraphs, then does a long leap at Limus instead.
func _tank(d: float, to: Vector2) -> void:
	if abs(to.x) < 560 and abs(to.y) < 260 and to.x != 0:
		dir = sign(to.x)
	if is_on_floor():
		if not was_on_floor:            # landed: squash and stop sliding
			squash = Vector2(1.45, 0.65)
			if charging > 0:
				charging = 0
				Chem.shake(6.0)
		velocity.x = move_toward(velocity.x, 0, 1600 * d)
		hop_cd -= d
		if subboss and cd <= 0 and abs(to.x) < 420 and windup <= 0:
			windup = 0.45
			cd = 3.0
		if windup > 0:
			windup -= d
			if windup <= 0:              # big leap at the player
				charging = 1.0
				velocity = Vector2(clamp(to.x * 1.4, -520, 520), HOP_V * 1.15)
				squash = Vector2(0.6, 1.5)
		elif hop_cd <= 0 and _floor_ahead(dir, speed * 2.4 * 0.62):   # check where the hop lands
			hop_cd = randf_range(0.35, 0.6)
			velocity = Vector2(dir * speed * 2.4, HOP_V)
			squash = Vector2(0.7, 1.35)    # stretch on take-off
	was_on_floor = is_on_floor()


func _fly(d: float, to: Vector2) -> void:
	if to.x != 0:
		dir = sign(to.x)
	if retreat > 0:
		retreat -= d
		velocity = -to.normalized() * speed * 0.8
	else:
		velocity = (to + Vector2(0, -50)).normalized() * speed + Vector2(0, sin(t * 6) * 80)
	if to.length() < 40:
		retreat = 0.7
	if subboss and cd <= 0 and windup <= 0:
		windup = 0.4
		cd = 2.5
	if windup > 0:
		windup -= d
		velocity *= 0.2
		if windup <= 0:
			for i in 6:
				_shot(Vector2.RIGHT.rotated(TAU * i / 6.0) * 220.0, 0.0)


func _ranged(d: float, to: Vector2) -> void:
	if to.x != 0:
		dir = sign(to.x)
	var dist: float = abs(to.x)
	var mv := 0.0
	if dist < 220:
		mv = -dir
	elif dist > 380:
		mv = dir
	if mv != 0 and not _floor_ahead(mv):
		mv = 0
	velocity.x = mv * speed
	if cd <= 0 and dist < 650 and windup <= 0:
		windup = 0.35   # visible wind-up before spitting
		cd = 1.3 if subboss else 2.2
	if windup > 0:
		windup -= d
		velocity.x = 0
		if windup <= 0:
			squash = Vector2(1.3, 0.75)  # recoil
			if subboss:
				for a in [-0.25, 0.0, 0.25]:
					_lob(to, a)
			else:
				_lob(to, 0.0)


func _lob(to: Vector2, spread: float) -> void:
	var T := 0.9
	var g := 700.0
	var v := Vector2(to.x / T, (to.y - 0.5 * g * T * T) / T).rotated(spread)
	_shot(v, g)


func _shot(v: Vector2, g: float):
	var p = PROJECTILE.instantiate()
	p.vel = v
	p.grav = g
	p.damage = 8 + dmg_bonus
	p.chem = chem
	p.from_player = false
	p.position = global_position + Vector2(dir * 14, -10)
	get_parent().add_child(p)
	return p


func hit(amount: float, c: int, src) -> void:
	if dead:
		return
	var m: float = Chem.multiplier(c, chem)
	var dmg := amount * m
	hp -= dmg
	hurt = 0.12
	squash = Vector2(1.35, 0.7)
	windup = 0.0 if not subboss else windup  # small enemies get interrupted
	var kx: float = sign(global_position.x - src.global_position.x)
	knock = Vector2(kx * (40.0 if subboss else 160.0), 0)
	Chem.fx(get_parent(), "slash_%d" % c, global_position + Vector2(randf_range(-6, 6), randf_range(-8, 4)), 2.0, 28.0)
	_popup(("%.0f" % dmg) + ("!" if m > 1 else ""), Color(1, 1, 0.3) if m > 1 else (Color(0.6, 0.6, 0.6) if m < 1 else Color.WHITE))
	if hp <= 0:
		_die()


func _popup(text: String, col: Color) -> void:
	Chem.damage_number(get_parent(), global_position + Vector2(0, -size.y / 2 - 20), text, col, col == Color(1, 1, 0.3))


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	Chem.corpse(get_parent(), sprite, global_position)
	Chem.fx(get_parent(), "boom_0", global_position, 4.0 if subboss else 2.5, 12.0)
	Chem.shake(8.0 if subboss else 2.5)
	var room = Chem.room()
	if room:
		room.spawn_drop(Chem.DROPS[kind], global_position, 2 if subboss else 1)
		if subboss:
			room.spawn_drop("slime_core", global_position, 1)
	died.emit(self)
	queue_free()


func _draw() -> void:
	if kind == "dummy" or (not subboss and hp >= max_hp):
		return
	var w := size.x + 10
	var y := -size.y / 2 - 10
	draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, y, w * max(hp, 0) / max_hp, 4), Color(0.9, 0.2, 0.2))
