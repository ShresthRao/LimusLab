extends Node2D
## scenes/Main.tscn — the game controller.
##
## Main.tscn
##   World      the current room scene is added here
##   HUD        scenes/ui/HUD.tscn
##   Fader      CanvasLayer with a black ColorRect used for every fade
##
## * Creates Limus once (scenes/actors/Player.tscn) and MOVES that same node from room to room,
##   so HP, overheal, materials and the build carry over.
## * Rooms are separate scenes (ROOMS). When a room's exit door is touched the screen fades to
##   black, the old room is freed, the next one is loaded, Limus is placed on its PlayerSpawn and
##   the screen fades back in.
## * TAB / I fades into the Lab Kit (scenes/ui/InventoryScreen.tscn) — only when the room has no
##   enemies left. The world is paused while it is open; TAB / I or Esc fades back.

## Room scenes in play order (filled in by tools/build_scenes.gd; editable in the Inspector).
@export var rooms: PackedStringArray = []
@export var room_titles: PackedStringArray = []   # shown in the developer room list
@export var room_floors: PackedInt32Array = []
var PLAYER: PackedScene = load("res://scenes/actors/Player.tscn")
var INVENTORY: PackedScene = load("res://scenes/ui/InventoryScreen.tscn")
var LEVEL_UP: PackedScene = load("res://scenes/ui/LevelUpScreen.tscn")
var DEV_MENU: PackedScene = load("res://scenes/ui/DevMenu.tscn")
var dev_menu
const FADE := 0.4

@onready var world: Node2D = $World
@onready var hud = $HUD
@onready var black: ColorRect = $Fader/Black

var player
var room
var room_index := -1
var busy := false          # true while fading
var inventory
var game_over := false
var shake_amt := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps fades / input alive while the world is paused
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	player = PLAYER.instantiate()
	player.died.connect(_on_player_died)
	hud.player = player
	black.color.a = 1.0
	_go_to_room(0)


# ---------------- fades ----------------

func _fade(to_alpha: float, dur: float = FADE) -> void:
	var tw := create_tween()
	tw.tween_property(black, "color:a", to_alpha, dur)
	await tw.finished


# ---------------- rooms ----------------

func _go_to_room(i: int) -> void:
	if busy:
		return
	busy = true
	if room:
		await _fade(1.0)
		room.get_node("Actors").remove_child(player)
		room.queue_free()
		room = null
	room_index = i
	room = load(rooms[i]).instantiate()
	world.add_child(room)
	room.exit_reached.connect(_on_exit_reached)
	room.get_node("Actors").add_child(player)
	var spawn = room.get_node_or_null("PlayerSpawn")
	player.global_position = spawn.global_position if spawn else Vector2(80, room.floor_y - 13)
	player.velocity = Vector2.ZERO
	var r: Rect2 = room.bounds()
	player.camera.limit_left = int(r.position.x)
	player.camera.limit_top = int(r.position.y)
	player.camera.limit_right = int(r.end.x)
	player.camera.limit_bottom = int(min(r.end.y, 720))
	player.camera.reset_smoothing()
	hud.room_name = room.room_title if room.floor_i == Chem.FINAL_FLOOR else "%s  ·  %s" % [Chem.FLOORS[room.floor_i]["name"].split(":")[0], room.room_title]
	hud.boss = null
	await _fade(0.0)
	busy = false
	room.start(player)


func _on_exit_reached() -> void:
	if busy:
		return
	var finished_floor: int = room.floor_i
	if room.floor_end or room_index + 1 >= rooms.size():
		await _floor_complete(finished_floor, room_index + 1 >= rooms.size())
		if room_index + 1 >= rooms.size():
			return
	_go_to_room(room_index + 1)


## Between floors: fade to black, level Limus up and show the LevelUpScreen pop-up.
## After the final boss the same pop-up becomes the victory card.
func _floor_complete(floor_i: int, is_final: bool) -> void:
	busy = true
	await _fade(1.0)
	var stats: Array = [player.stat_snapshot(), player.stat_snapshot()] if is_final else player.level_up()
	var pop = LEVEL_UP.instantiate()
	add_child(pop)
	hud.visible = false
	pop.setup(floor_i, min(floor_i + 1, Chem.FINAL_FLOOR), stats[0], stats[1], is_final)
	if is_final:
		game_over = true
		return
	await pop.continued
	pop.queue_free()
	hud.visible = true
	busy = false


# ---------------- Lab Kit ----------------

func can_open_inventory() -> bool:
	return room != null and not busy and not game_over and not player.dead and room.enemies_alive() == 0


func _unhandled_input(e: InputEvent) -> void:
	# DEVELOPER: Shift + = opens the room-select list
	if e is InputEventKey and e.pressed and not e.echo and e.shift_pressed and e.keycode in [KEY_EQUAL, KEY_PLUS]:
		get_viewport().set_input_as_handled()
		if dev_menu:
			_close_dev_menu()
		else:
			_open_dev_menu()
		return
	if dev_menu:
		return
	if e.is_action_pressed("inventory") or (inventory and e.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if inventory:
			_close_inventory()
		elif can_open_inventory():
			_open_inventory()
		elif room and room.enemies_alive() > 0:
			hud.toast("The Lab Kit is sealed while enemies remain!")
	elif e.is_action_pressed("restart") and game_over:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _open_inventory() -> void:
	busy = true
	get_tree().paused = true
	await _fade(1.0, 0.3)
	inventory = INVENTORY.instantiate()
	inventory.player = player
	add_child(inventory)
	hud.visible = false
	await _fade(0.0, 0.3)
	busy = false


func _close_inventory() -> void:
	if busy:
		return
	busy = true
	await _fade(1.0, 0.3)
	inventory.queue_free()
	inventory = null
	hud.visible = true
	await _fade(0.0, 0.3)
	get_tree().paused = false
	busy = false


# ---------------- misc ----------------

func add_shake(amount: float) -> void:
	shake_amt = min(18.0, max(shake_amt, amount))


func _process(d: float) -> void:
	if player and player.is_inside_tree():
		player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	shake_amt = move_toward(shake_amt, 0.0, d * 40.0)


func _on_player_died() -> void:
	game_over = true
	hud.show_msg("Limus dissolved...  Press R to retry", 9999)


# ---------------- developer room select (Shift + =) ----------------

func _open_dev_menu() -> void:
	dev_menu = DEV_MENU.instantiate()
	dev_menu.game = self
	add_child(dev_menu)
	dev_menu.picked.connect(dev_jump)
	dev_menu.closed.connect(_close_dev_menu)
	get_tree().paused = true


func _close_dev_menu() -> void:
	if dev_menu:
		dev_menu.queue_free()
		dev_menu = null
	if inventory == null:
		get_tree().paused = false


## Jump straight to room i: closes any pop-up / Lab Kit, revives Limus if needed, then loads the room.
func dev_jump(i: int) -> void:
	_close_dev_menu()
	if inventory:
		inventory.queue_free()
		inventory = null
	for c in get_children():
		if c.has_method("setup"):   # a level-up / victory pop-up
			c.queue_free()
	get_tree().paused = false
	busy = false
	game_over = false
	hud.visible = true
	if player.dead:
		player.revive()
	_go_to_room(i)
