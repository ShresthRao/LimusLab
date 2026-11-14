extends CharacterBody2D
## scenes/actors/Player.tscn — Limus, a light-blue slime (user's "Mini Slime" sheets) that flushes
## faint red when hit. Stats come from the BUILD (chemical + catalyst + 3 reagents).
## The same Player node is moved from room to room by game.gd, so HP, materials and build persist.
## Child nodes (made in the scene): Sprite (AnimatedSprite2D, frames/limus.tres), Shape, Bubbles, Camera.

signal died
signal build_changed

var PROJECTILE: PackedScene = load("res://scenes/actors/Projectile.tscn")
const GRAVITY := 1400.0
const THROW_COST := 7.0
const BUBBLE_BASE := 3.5        # slime bubble base damage (was 2.0)
const MELEE_REACH := 124.0      # 2x the old 62 px reach
const BASE_SCALE := Vector2(1.5, 1.5)  # 32x32 frames (body ~29x20 px)
const HURT_TINT := Color(1.0, 0.84, 0.85)  # faint red flush when hit

var speed := 260.0
const TILE := 32.0
const JUMP_TILES := 2.0          # bounce height: exactly 2 tiles
# v = sqrt(2gh) plus half a physics step of gravity, so the per-frame integration really peaks at 2 tiles
var jump_v := -(sqrt(2.0 * GRAVITY * TILE * JUMP_TILES) + GRAVITY / 120.0)   # ~ -435 px/s
var dash_speed := 720.0
var max_hp := 100
var hp := 100.0
var overheal := 0.0
var max_overheal := 50.0
var max_stamina := 100.0
var stamina := 100.0
var stamina_regen := 1.0   # stamina per second
var dash_cost := 10.0      # 100 stamina = 10 dashes

# ---- health regen (out of combat) ----
const HP_REGEN := 1.0          # HP per second
const OUT_OF_COMBAT_DELAY := 3.0
var combat_t := 0.0            # seconds since Limus last took damage

# ---- SUPER (Q / middle mouse) ----
const SUPER_MIN_STAMINA := 50.0   # need at least this much; it drains ALL stamina
const SUPER_CHARGE := 3.0         # immobile while charging
const SUPER_TIME := 30.0          # buff duration
const SUPER_MULT := 3.0           # x3 health and x3 damage
var super_charge := 0.0           # > 0 while charging (frozen in place)
var super_t := 0.0                # > 0 while the buff is active
var super_mult := 1.0
var charge_fx: Node2D
var aura_fx: Node2D
var SUPER_CHARGE_SCENE: PackedScene = load("res://scenes/fx/SuperCharge.tscn")
var SUPER_AURA_SCENE: PackedScene = load("res://scenes/fx/SuperAura.tscn")
var loot_mult := 1
var loot_bonus := 0
var melee_dmg := 2.0
var range_dmg := BUBBLE_BASE
var bubble_radius := 64.0
var attack_cd := 0.35
var chem := 0
var level := 1               # +1 after every floor (see level_up)

# ---- inventory ----
var materials := {}  # id -> owned count
var build := {"chem": 0, "catalyst": 0, "reagents": ["", "", ""]}

var facing := 1.0
var dashing := 0.0
var atk_timer := 0.0
var throw_timer := 0.0
var invuln := 0.0
var stun := 0.0
var coyote := 0.0
var dead := false
var size := Vector2(34, 26)
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera
var squash := Vector2.ONE      # squash & stretch multiplier, eases back to 1
var was_on_floor := true
var action_anim := ""          # "attack" / "land" while a one-shot plays
var ghost_t := 0.0
var hurt_t := 0.0             # faint-red flush timer


func _ready() -> void:
	add_to_group("player")
	sprite.animation_finished.connect(func(): action_anim = "")
	sprite.play("idle")
	apply_build(true)


# ---------------- inventory / build ----------------

func equipped_count(id: String) -> int:
	return build["reagents"].count(id)


func available(id: String) -> int:
	return int(materials.get(id, 0)) - equipped_count(id)


func add_material(id: String, n: int = 1) -> void:
	materials[id] = int(materials.get(id, 0)) + n
	build_changed.emit()


## Loot pickup: store the material and restore health.
func collect(id: String) -> float:
	add_material(id, 1)
	var amt: float = Chem.LOOT_HEAL.get(id, 10) * loot_mult + loot_bonus
	heal(amt)
	return amt


## Heal fills HP first; anything above max HP becomes OVERHEAL (capped).
func heal(amount: float) -> void:
	var to_hp: float = min(amount, max_hp - hp)
	hp += to_hp
	overheal = min(max_overheal, overheal + amount - to_hp)


## Damage drains OVERHEAL first, then normal HP.
func take_damage(amount: float, flinch: bool = true) -> void:
	combat_t = 0.0
	var absorbed: float = min(overheal, amount)
	overheal -= absorbed
	hp -= amount - absorbed
	if flinch and amount > 0 and hp > 0:
		_hurt_fx()
	if hp <= 0:
		hp = 0
		_die()


func apply_build(refill: bool = false) -> void:
	var c: Dictionary = Chem.CATALYSTS[build["catalyst"]]
	chem = build["chem"]
	var hp_add := int(c.get("hp", 0))
	var stam_add := float(c.get("stamina", 0))
	var regen_add := 0.0
	var melee_mul := float(c.get("melee", 1.0))
	var range_mul := float(c.get("range", 1.0))
	var dmg_mul := float(c.get("dmg", 1.0))
	var radius_add := 0.0
	loot_bonus = 0
	for id in build["reagents"]:
		if id == "":
			continue
		var m: Dictionary = Chem.MATERIALS[id]
		hp_add += int(m.get("hp", 0))
		stam_add += float(m.get("stamina", 0))
		regen_add += float(m.get("regen", 0))
		melee_mul += float(m.get("melee", 0))
		range_mul += float(m.get("range", 0))
		dmg_mul += float(m.get("dmg", 0))
		radius_add += float(m.get("radius", 0))
		loot_bonus += int(m.get("loot_bonus", 0))
	var lv := level - 1
	max_hp = int((100 + hp_add + Chem.LV_HP * lv) * super_mult)
	max_stamina = 100.0 + stam_add + Chem.LV_STAMINA * lv
	stamina_regen = 1.0 + regen_add + Chem.LV_REGEN * lv
	attack_cd = 0.35 * float(c.get("attack_cd", 1.0))
	var lv_mul := (1.0 + Chem.LV_DMG * lv) * super_mult
	melee_dmg = 2.0 * dmg_mul * melee_mul * lv_mul
	range_dmg = BUBBLE_BASE * dmg_mul * range_mul * lv_mul
	bubble_radius = 64.0 + radius_add
	loot_mult = int(c.get("loot_mult", 1))
	if refill:
		hp = max_hp
		stamina = max_stamina
	if not dead:
		hp = clamp(hp, 1, max_hp)
		overheal = min(overheal, max_overheal)
	stamina = min(stamina, max_stamina)
	build_changed.emit()


## Called by game.gd between floors. Raises the level, refills HP and stamina and returns the
## stats before and after, for the level-up pop-up.
func stat_snapshot() -> Dictionary:
	return {"level": level, "hp": max_hp, "slash": melee_dmg, "bubble": range_dmg,
		"stamina": max_stamina, "dashes": int(max_stamina / dash_cost), "regen": stamina_regen}


func level_up() -> Array:
	var before := stat_snapshot()
	level += 1
	apply_build(true)       # full heal + refill on level-up
	overheal = 0.0
	return [before, stat_snapshot()]


# ---------------- gameplay ----------------

func _physics_process(d: float) -> void:
	if dead:
		return
	invuln = max(invuln - d, 0.0)
	atk_timer = max(atk_timer - d, 0.0)
	throw_timer = max(throw_timer - d, 0.0)
	stun = max(stun - d, 0.0)
	stamina = min(max_stamina, stamina + stamina_regen * d)
	coyote = 0.1 if is_on_floor() else max(coyote - d, 0.0)
	_regen(d)
	_super_tick(d)
	if super_charge > 0:          # immobile while the super charges
		velocity = Vector2.ZERO
		_animate(d)
		return
	if Input.is_action_just_pressed("super"):
		start_super()

	var dir := Input.get_axis("left", "right")
	if dir != 0 and stun == 0:
		facing = sign(dir)

	if dashing > 0:
		dashing -= d
		velocity = Vector2(facing * dash_speed, 0)
		ghost_t -= d
		if ghost_t <= 0:
			ghost_t = 0.035
			_afterimage()
	else:
		if stun > 0:
			velocity.x = move_toward(velocity.x, 0, 900 * d)
		else:
			velocity.x = dir * speed
		velocity.y += GRAVITY * d
		if Input.is_action_just_pressed("jump") and coyote > 0:
			velocity.y = jump_v
			coyote = 0
			squash = Vector2(0.85, 1.2)  # stretch up on take-off
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= 0.5
		if Input.is_action_just_pressed("dash") and stamina >= dash_cost:
			stamina -= dash_cost
			dashing = 0.16
			invuln = max(invuln, 0.16)
			squash = Vector2(1.5, 0.7)
			ghost_t = 0
	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not was_on_floor:  # landing
		var k: float = clamp(fall_speed / 900.0, 0.15, 0.5)
		squash = Vector2(1.0 + k, 1.0 - k)
		if action_anim == "":
			action_anim = "land"
			sprite.play("land")
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("slash") and atk_timer == 0:
		_slash()
	if Input.is_action_just_pressed("throw") and throw_timer == 0:
		_throw()

	_animate(d)
	if global_position.y > 900:
		take_damage(9999)


func _animate(d: float) -> void:
	sprite.flip_h = facing < 0
	if action_anim == "":
		var a := "idle"
		if dashing > 0:
			a = "dash"
		elif not is_on_floor():
			a = "jump" if velocity.y < -80 else "fall"
		elif abs(velocity.x) > 10:
			a = "run"
		if sprite.animation != a:
			sprite.play(a)
	# squash & stretch, eased back to normal; airborne stretch follows vertical speed
	squash = squash.lerp(Vector2.ONE, clamp(12.0 * d, 0, 1))
	var air := Vector2.ONE
	if not is_on_floor() and dashing <= 0:
		var v: float = clamp(abs(velocity.y) / 2800.0, 0, 0.12)
		air = Vector2(1.0 - v, 1.0 + v)
	sprite.scale = BASE_SCALE * squash * air
	sprite.position.y = 13.0 - 16.0 * sprite.scale.y  # keep the slime's base on the floor
	hurt_t = max(hurt_t - d, 0.0)
	sprite.self_modulate = Color.WHITE.lerp(HURT_TINT, clamp(hurt_t / 0.25, 0.0, 1.0))
	if super_t > 0:   # golden glow pulse while supercharged (faster in the last 5 s)
		var g := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * (6.0 if super_t > 5.0 else 16.0))
		sprite.self_modulate *= Color(1.0 + 0.6 * g, 1.0 + 0.35 * g, 0.85)
	elif super_charge > 0:
		sprite.self_modulate *= Color(1.6, 1.3, 0.8)
	var blink := invuln > 0 and dashing <= 0 and int(invuln * 20) % 2 == 0
	sprite.modulate.a = 0.35 if blink else 1.0


func _afterimage() -> void:
	Chem.afterimage(get_parent(), sprite, Color(0.7, 0.88, 1.0, 0.55))


func _play_attack() -> void:
	action_anim = "attack"
	sprite.play("attack")
	squash = Vector2(1.25, 0.85)


func _slash() -> void:
	atk_timer = attack_cd
	_play_attack()
	# wide crescent sweep that travels out to the full (doubled) reach
	var fx := Chem.fx(self, "slash_%d" % chem, Vector2(facing * 40, -4), 5.0, 14.0)
	fx.flip_h = facing < 0
	var tw := fx.create_tween()
	tw.tween_property(fx, "position:x", facing * (MELEE_REACH - 30), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fx2 := Chem.fx(self, "slash_%d" % chem, Vector2(facing * 90, -4), 4.0, 12.0)
	fx2.flip_h = facing < 0
	fx2.modulate.a = 0.6
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var r: Vector2 = e.global_position - global_position
		var es: Vector2 = e.size
		var in_front: bool = sign(r.x) == facing or abs(r.x) < 12
		if in_front and abs(r.x) < MELEE_REACH + es.x / 2 and abs(r.y) < 40 + es.y / 2:
			e.hit(melee_dmg, chem, self)
			hit_any = true
	if hit_any:
		Chem.shake(3.0)
		Chem.hitstop(0.04)


func _throw() -> void:
	if hp + overheal <= THROW_COST:
		return  # not enough health to spend on a bubble
	throw_timer = 0.55
	take_damage(THROW_COST, false)  # paying for a bubble is not getting hurt
	_play_attack()
	var v: Vector2
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		v = (get_global_mouse_position() - global_position).normalized() * 560.0
		if v.x != 0:
			facing = sign(v.x)
	else:
		v = Vector2(facing * 440.0, -480.0)
	var b = PROJECTILE.instantiate()
	b.vel = v
	b.grav = 600.0
	b.damage = range_dmg
	b.chem = chem
	b.from_player = true
	b.radius = bubble_radius
	b.bounces = 1          # bounces once off anything that is not an enemy (+30% damage)
	b.ricochets = 3        # hits an enemy -> bounces in an arc toward the next one
	b.position = global_position + Vector2(facing * 16, -8)
	get_parent().add_child(b)


## Enemy damage (amount = HP lost).
func hit(amount, _chem, src) -> void:
	if dead or invuln > 0:
		return
	take_damage(float(amount))
	invuln = 0.9
	stun = 0.2
	dashing = 0
	var dx: float = sign(global_position.x - src.global_position.x)
	if dx == 0:
		dx = -facing
	velocity = Vector2(dx * 320, -300)
	Chem.shake(6.0)


func _hurt_fx() -> void:
	squash = Vector2(1.25, 0.8)
	hurt_t = 0.6            # light purple -> faint red, fading back
	action_anim = "hurt"
	sprite.play("hurt")


func acid_contact() -> void:
	if dead or invuln > 0:
		return
	take_damage(10)
	invuln = 0.9
	velocity.y = -700
	squash = Vector2(0.6, 1.5)
	Chem.fx(get_parent(), "boom_0", global_position + Vector2(0, 10), 3.0)


func _die() -> void:
	if dead:
		return
	dead = true
	action_anim = "death"
	squash = Vector2.ONE
	sprite.scale = BASE_SCALE
	sprite.self_modulate = HURT_TINT
	sprite.play("death")       # the sheet's own burst-apart animation
	Chem.fx(get_parent(), "boom_%d" % chem, global_position, 4.0, 10.0)
	Chem.shake(10.0)
	died.emit()


# ---------------- health regen ----------------

## +1 HP per second when out of combat: no living enemies in the room and no damage for 3 s.
## Regen never creates overheal.
func _regen(d: float) -> void:
	combat_t += d
	var room = Chem.room()
	var calm: bool = room == null or room.enemies_alive() == 0
	if calm and combat_t >= OUT_OF_COMBAT_DELAY and hp < max_hp:
		hp = min(float(max_hp), hp + HP_REGEN * d)


# ---------------- SUPER ----------------

func can_super() -> bool:
	return not dead and super_charge <= 0 and super_t <= 0 and stamina >= SUPER_MIN_STAMINA


## Q / middle mouse: drains ALL stamina, freezes Limus for 3 s while the charge effect plays,
## then grants x3 health and x3 damage for 30 s.
func start_super() -> void:
	if not can_super():
		if super_t <= 0 and super_charge <= 0:
			Chem.hud_toast("Super needs %d stamina" % int(SUPER_MIN_STAMINA))
		return
	stamina = 0.0
	dashing = 0
	super_charge = SUPER_CHARGE
	charge_fx = SUPER_CHARGE_SCENE.instantiate()
	add_child(charge_fx)
	sprite.play("idle")
	action_anim = "charge"
	var tw := camera.create_tween()
	tw.tween_property(camera, "zoom", Vector2(1.25, 1.25), SUPER_CHARGE).set_trans(Tween.TRANS_SINE)
	Chem.hud_msg("SUPER CHARGING...", SUPER_CHARGE)


func _super_tick(d: float) -> void:
	if super_charge > 0:
		super_charge -= d
		var k: float = 1.0 - super_charge / SUPER_CHARGE
		Chem.shake(1.0 + 5.0 * k)                       # rumble builds up
		var p := 1.0 + (0.06 + 0.12 * k) * sin(Time.get_ticks_msec() / 1000.0 * (14.0 + 30.0 * k))
		squash = Vector2(1.0 / p, p)                    # throbbing slime
		if super_charge <= 0:
			_release_super()
	elif super_t > 0:
		super_t -= d
		if super_t <= 0:
			_end_super()


func _release_super() -> void:
	super_charge = 0.0
	action_anim = ""
	if is_instance_valid(charge_fx):
		charge_fx.queue_free()
	var tw := camera.create_tween()
	tw.tween_property(camera, "zoom", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	# x3 health (current HP scales with the new maximum) and x3 damage
	super_mult = SUPER_MULT
	super_t = SUPER_TIME
	apply_build(false)
	hp = min(float(max_hp), hp * SUPER_MULT)
	aura_fx = SUPER_AURA_SCENE.instantiate()
	add_child(aura_fx)
	move_child(aura_fx, 0)          # behind the sprite
	Chem.fx(get_parent(), "super_burst", global_position + Vector2(0, -6), 7.0, 12.0)
	Chem.fx(get_parent(), "boom_2", global_position, 8.0, 10.0)
	Chem.shake(16.0)
	Chem.hitstop(0.08)
	squash = Vector2(1.8, 0.5)
	for e in get_tree().get_nodes_in_group("enemies"):   # shockwave pushes enemies away
		var to: Vector2 = e.global_position - global_position
		if to.length() < 220 and "knock" in e:
			e.knock = Vector2(sign(to.x) * 420.0, 0)
	Chem.hud_msg("SUPER!  x3 HEALTH  ·  x3 DAMAGE  (30 s)", 2.0)


func _end_super() -> void:
	super_t = 0.0
	var ratio := hp / float(max_hp)
	super_mult = 1.0
	apply_build(false)
	hp = max(1.0, ratio * max_hp)    # keep the same fraction of health
	if is_instance_valid(aura_fx):
		aura_fx.queue_free()
	Chem.fx(get_parent(), "super_burst", global_position, 4.0, 14.0)
	Chem.hud_toast("Super faded")


## Developer room-select only: bring Limus back after death.
func revive() -> void:
	dead = false
	hp = max_hp
	stamina = max_stamina
	action_anim = ""
	sprite.scale = BASE_SCALE
	sprite.self_modulate = Color.WHITE
	sprite.play("idle")
