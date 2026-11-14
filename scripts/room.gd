extends Node2D
## Root script of every room scene (scenes/rooms/Room_*.tscn).
##
## Scene layout (built by tools/build_scenes.gd, editable in Godot):
##   Background / Ground / Platforms / Acid / Decor   TileMapLayer (lab tiles, drawn at 2x)
##   Hazards     AcidPool areas over each acid pit
##   Props       extra sprites (DANGER signs)
##   Signs       tutorial text
##   Spawns      Marker2D: "Ground*" for walkers, "Air*" for flyers
##   PlayerSpawn / BossSpawn  Marker2D
##   ExitDoor    locked until the room is cleared
##   Actors      Limus, enemies, projectiles, drops and effects live here
##
## Flow: game.gd adds Limus to Actors and calls start(). Tutorial rooms wait for their dummies;
## fight rooms run `waves`, then the `sub_boss`; boss rooms spawn the boss. When nothing is left
## the door unlocks (`cleared`) and touching it emits `exit_reached` so the game fades onward.

signal cleared
signal exit_reached

var ENEMY: PackedScene = load("res://scenes/actors/Enemy.tscn")
var BOSS: PackedScene = load("res://scenes/actors/Boss.tscn")
var PICKUP: PackedScene = load("res://scenes/actors/Pickup.tscn")

@export var room_title := "Room"
@export var tutorial := false
@export var boss_room := false
@export var waves: Array = []          # e.g. [["tank","tank"], ["tank","annoying"]]
@export var sub_boss := ""
@export var size_px := Vector2(1280, 736)
@export var floor_y := 608.0
@export var floor_i := 0             # theme / difficulty (Chem.FLOORS index; 4 = final reactor)
@export var floor_end := false       # last room of a floor -> level-up pop-up when you leave
@export var start_x := 200.0         # waves begin once Limus walks past this x (calm moment to use the Lab Kit)

@onready var actors: Node2D = $Actors
@onready var door = $ExitDoor

var player
var active := false
var is_cleared := false
var pending := false
var wave_idx := -1
var alive := []
var boss_ref


func _ready() -> void:
	add_to_group("room")
	door.entered.connect(func(): exit_reached.emit())


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, size_px)


var waiting := false


func start(p) -> void:
	player = p
	Chem.hud_msg(room_title, 1.6)
	if not tutorial:
		waiting = true      # fights begin when Limus steps in (see _process)
		return
	active = true
	if tutorial:
		for e in actors.get_children():
			if e.is_in_group("enemies"):
				e.player = p
				alive.append(e)
		wave_idx = 999
		return
	_next_wave()


func enemies_alive() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and is_ancestor_of(e):
			n += 1
	return n


func _process(_d: float) -> void:
	if waiting and is_instance_valid(player) and player.global_position.x > start_x:
		waiting = false
		active = true
		_next_wave()
		return
	if not active or is_cleared or pending:
		return
	alive = alive.filter(func(e): return is_instance_valid(e) and not e.dead)
	if alive.is_empty():
		pending = true
		await get_tree().create_timer(0.9).timeout
		pending = false
		if active:
			_next_wave()


func _next_wave() -> void:
	wave_idx += 1
	if boss_room:
		if wave_idx == 0:
			boss_ref = BOSS.instantiate()
			boss_ref.floor_i = floor_i
			boss_ref.player = player
			boss_ref.room = self
			boss_ref.arena = bounds()
			boss_ref.floor_y = floor_y
			boss_ref.position = $BossSpawn.position
			actors.add_child(boss_ref)
			alive.append(boss_ref)
			var hud = get_tree().get_first_node_in_group("hud")
			if hud:
				hud.boss = boss_ref
			Chem.hud_msg("%s awakens!" % Chem.FLOORS[floor_i]["boss"][2], 2.0)
		else:
			_clear()
		return
	if wave_idx < waves.size():
		var spawns_g := _markers("Ground")
		var spawns_a := _markers("Air")
		var i := 0
		for k in waves[wave_idx]:
			var pts := spawns_a if k == "annoying" and not spawns_a.is_empty() else spawns_g
			var pos: Vector2 = pts[i % pts.size()].position
			if k == "annoying" and spawns_a.is_empty():
				pos.y -= 200
			_spawn(k, pos, false)
			i += 1
		Chem.hud_msg("Wave %d / %d" % [wave_idx + 1, waves.size()], 1.2)
	elif wave_idx == waves.size() and sub_boss != "":
		var pts := _markers("Ground")
		var far: Vector2 = pts[0].position
		for m in pts:   # spawn the sub-boss on the marker farthest from Limus
			if m.position.distance_to(player.position) > far.distance_to(player.position):
				far = m.position
		var sb = _spawn(sub_boss, far + Vector2(0, -20), true)
		Chem.hud_msg("SUB-BOSS: GIANT " + sb.display_name.to_upper(), 2.0)
	else:
		_clear()


func _markers(prefix: String) -> Array:
	return $Spawns.get_children().filter(func(m): return m.name.begins_with(prefix))


func _spawn(kind: String, pos: Vector2, sub: bool):
	var e = ENEMY.instantiate()
	e.kind = kind
	e.subboss = sub
	e.floor_i = floor_i
	e.player = player
	e.position = pos
	actors.add_child(e)
	alive.append(e)
	Chem.fx(actors, "boom_3", pos, 4.0 if sub else 2.0, 10.0)
	return e


func spawn_minion(kind: String, pos: Vector2) -> void:
	var count := 0
	for e in alive:
		if is_instance_valid(e) and e != boss_ref:
			count += 1
	if count < 4:
		_spawn(kind, pos, false)


func spawn_drop(id: String, pos: Vector2, n: int) -> void:
	for i in n:
		var p = PICKUP.instantiate()
		p.id = id
		p.player = player
		p.position = pos + Vector2(randf_range(-10, 10), -10)
		actors.call_deferred("add_child", p)


func _clear() -> void:
	if is_cleared:
		return
	is_cleared = true
	active = false
	door.unlock()
	Chem.shake(5.0)
	if boss_room and floor_i == Chem.FINAL_FLOOR:
		Chem.hud_msg("THE PRIME CATALYST IS NEUTRALIZED!\nWalk through the door to escape the lab →", 5.0)
	elif boss_room:
		Chem.hud_msg("%s defeated!  Exit → next floor" % Chem.FLOORS[floor_i]["boss"][2], 3.5)
	else:
		Chem.hud_msg("Room clear!  TAB: Lab Kit   ·   Exit door is open →", 2.6)
	cleared.emit()
