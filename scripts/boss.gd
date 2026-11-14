extends CharacterBody2D
## scenes/actors/Boss.tscn — Floor-1 boss, THE CORROSION CORE (0x72 big demon).
## Hovers, telegraphs every attack, then: acid fan / acid rain / summons imps / dive-slam.
## Phase 2 under 50% HP = faster and denser. Child nodes: Sprite (AnimatedSprite2D), Shape.
## The room (room.gd) spawns it and gives it `arena` (the room rectangle) and `floor_y`.

signal died(e)

var PROJECTILE: PackedScene = load("res://scenes/actors/Projectile.tscn")

var player
var room
var arena: Rect2
var floor_y := 600.0
var hp := 90.0
var max_hp := 90.0
var chem := 0
var size := Vector2(52, 62)
var floor_i := 0              # set by the room: picks sprite, tint, size, HP and name (Chem.FLOORS)
var display_name := "BOSS"
var base_scale := 2.0
var tint := Color.WHITE
var dmg_bonus := 0.0
var is_final := false
var chem_t := 0.0             # final boss: time until its chemical changes
var t := 0.0
var cd := 2.5
var phase := 1
var hurt := 0.0
var touch_cd := 0.0
var dive_t := 0.0
var dive_x := 0.0
var home := Vector2.ZERO
var dead := false
@onready var sprite: AnimatedSprite2D = $Sprite
var windup := 0.0
var squash := Vector2.ONE
var slammed := false
var ghost_t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0
	var b: Array = Chem.FLOORS[floor_i]["boss"]
	sprite.sprite_frames = load("res://frames/%s.tres" % b[0])
	tint = b[1]
	display_name = b[2]
	base_scale = b[3]
	is_final = floor_i == Chem.FINAL_FLOOR
	chem = Chem.FLOORS[floor_i]["chem"]
	hp = Chem.boss_hp(floor_i)
	max_hp = hp
	dmg_bonus = Chem.enemy_dmg_bonus(floor_i) + (6.0 if is_final else 0.0)
	size = Vector2(52, 62) * (base_scale / 2.0)
	($Shape.shape as RectangleShape2D).size = size
	sprite.play("run")
	if is_final:
		chem_t = 7.0
		_set_chem(randi() % 4)
	home = position


func _physics_process(d: float) -> void:
	if dead or not is_instance_valid(player):
		return
	t += d
	cd -= d
	hurt = max(hurt - d, 0.0)
	touch_cd = max(touch_cd - d, 0.0)
	if is_final:
		chem_t -= d
		if chem_t <= 0:
			chem_t = 7.0 if phase == 1 else 5.0
			_set_chem((chem + 1 + randi() % 3) % 4)
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		Chem.hud_msg("The Core boils over!", 1.5)

	var target: Vector2
	var lerp_speed := 2.0
	if dive_t > 0:
		dive_t -= d
		lerp_speed = 5.0
		target = Vector2(dive_x, floor_y - 36) if dive_t > 0.9 else home
		ghost_t -= d
		if ghost_t <= 0 and dive_t > 0.9:
			ghost_t = 0.05
			_afterimage()
		if dive_t <= 0.9 and not slammed:   # hit the floor
			slammed = true
			squash = Vector2(1.5, 0.6)
			Chem.shake(12.0)
			for i in [-1, 1]:
				Chem.fx(get_parent(), "boom_0", global_position + Vector2(i * 40, 28), 4.0, 12.0)
	elif windup > 0:   # telegraph: rise, swell and shake
		windup -= d
		target = position + Vector2(randf_range(-3, 3), -40 * d)
		sprite.position.x = randf_range(-2, 2)
		var k := 1.0 + 0.12 * sin(t * 30.0)
		squash = Vector2(1.0 / k, k)
		if windup <= 0:
			sprite.position.x = 0
			squash = Vector2(1.3, 0.8)
			_attack()
			cd = 2.6 if phase == 1 else 1.7
	else:
		target = home + Vector2(sin(t * 0.6) * arena.size.x * 0.3, sin(t * 1.3) * 30)
		if cd <= 0:
			windup = 0.55 if phase == 1 else 0.4
	position = position.lerp(target, clamp(lerp_speed * d, 0, 1))
	squash = squash.lerp(Vector2.ONE, clamp(6.0 * d, 0, 1))
	var breathe := 1.0 + 0.04 * sin(t * 4.0)
	sprite.scale = Vector2(base_scale, base_scale) * squash * Vector2(1.0 / breathe, breathe)

	var col := tint * (Color(1, 0.6 + 0.4 * sin(t * 10), 0.6 + 0.4 * sin(t * 10)) if phase == 2 else Color.WHITE)
	if windup > 0:
		col = Color(1.6, 1.3, 1.0)
	sprite.modulate = Color(4, 4, 4) if hurt > 0.05 else col
	sprite.flip_h = player.global_position.x < global_position.x
	var to: Vector2 = player.global_position - global_position
	if touch_cd == 0 and abs(to.x) < size.x / 2 + 12 and abs(to.y) < size.y / 2 + 12:
		player.hit(15 + dmg_bonus, chem, self)
		touch_cd = 0.8


func _attack() -> void:
	match randi() % 4:
		0: _fan()
		1: _rain()
		2: _summon()
		3: _dive()


func _fan() -> void:
	var n := (5 if phase == 1 else 9) + (3 if is_final else 0)
	var base: float = (player.global_position - global_position).angle()
	for i in n:
		_shot(Vector2.RIGHT.rotated(base + (i - (n - 1) / 2.0) * 0.18) * 260.0, 0.0, global_position)


func _rain() -> void:
	Chem.hud_msg("Acid rain!", 0.8)
	var n := 7 if phase == 1 else 12
	for i in n:
		var x := randf_range(arena.position.x + 40, arena.end.x - 40)
		var p = _shot(Vector2(0, randf_range(0, 120)), 500.0, Vector2(x, arena.position.y + 80))
		p.life = 3.0


func _summon() -> void:
	room.spawn_minion("annoying", global_position + Vector2(-70, 20))
	if phase == 2:
		room.spawn_minion("annoying", global_position + Vector2(70, 20))


func _dive() -> void:
	dive_x = clamp(player.global_position.x, arena.position.x + 80, arena.end.x - 80)
	dive_t = 1.8
	slammed = false
	ghost_t = 0


func _afterimage() -> void:
	Chem.afterimage(get_parent(), sprite, Color(1, 0.4, 0.4, 0.5))

func _shot(v: Vector2, g: float, pos: Vector2):
	var p = PROJECTILE.instantiate()
	p.vel = v
	p.grav = g
	p.damage = 8 + dmg_bonus
	p.chem = chem
	p.from_player = false
	p.position = pos
	get_parent().add_child(p)
	return p


func hit(amount: float, c: int, _src) -> void:
	if dead:
		return
	var m: float = Chem.multiplier(c, chem)
	hp -= amount * m
	hurt = 0.1
	squash = Vector2(1.15, 0.88)
	if hp <= 0:
		_death()


## Death: a chain of explosions while the demon shakes and dissolves.
func _death() -> void:
	dead = true
	remove_from_group("enemies")
	room.spawn_drop("corrosion_heart", global_position, 1)
	var par := get_parent()
	var tw := create_tween()
	for i in 7:
		tw.tween_callback(func():
			Chem.fx(par, "boom_%d" % (i % 4), global_position + Vector2(randf_range(-40, 40), randf_range(-40, 30)), 4.0, 12.0)
			Chem.shake(7.0)
			sprite.position = Vector2(randf_range(-4, 4), randf_range(-3, 3))
			sprite.modulate = Color(4, 4, 4) if i % 2 == 0 else Color.WHITE)
		tw.tween_interval(0.14)
	tw.tween_callback(func():
		Chem.corpse(par, sprite, global_position, Color(1, 0.6, 0.6))
		Chem.fx(par, "boom_0", global_position, 8.0, 10.0)
		Chem.shake(16.0))
	tw.tween_callback(queue_free)
	died.emit(self)


## Final boss only: switch to another chemical (tint + HUD warning). Its weakness switches with it.
func _set_chem(c: int) -> void:
	chem = c
	tint = Chem.COLORS[c].lerp(Color.WHITE, 0.35) * 1.4
	squash = Vector2(1.3, 0.8)
	Chem.fx(get_parent(), "boom_%d" % c, global_position, 6.0, 10.0)
	Chem.hud_msg("The Catalyst turns %s — weak to %s!" % [Chem.NAMES[c].to_upper(), Chem.NAMES[Chem.WEAK_TO[c]].to_upper()], 1.6)
