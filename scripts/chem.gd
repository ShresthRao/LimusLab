extends Node
## Autoload "Chem": chemistry rules, catalysts and input bindings.

const ACID := 0
const BASE := 1
const FUEL := 2
const FOAM := 3

var NAMES := ["Acid", "Base", "Fuel", "Foam"]
var COLORS := [Color(0.7, 1.0, 0.25), Color(0.5, 0.6, 1.0), Color(1.0, 0.6, 0.2), Color(0.95, 0.95, 1.0)]
# defender -> the chemical it is weak to
var WEAK_TO := {ACID: BASE, BASE: ACID, FUEL: FOAM, FOAM: FUEL}

# Catalysts: every buff has a cost (from the design doc).
var CATALYSTS := [
	{"name": "None", "desc": "Empty catalyst slot", "icon": ""},
	{"name": "Accelerant", "desc": "Faster attacks, -20 max HP", "attack_cd": 0.6, "hp": -20, "icon": "accelerant"},
	{"name": "Stabilizer", "desc": "+30 max HP, -25 stamina", "hp": 30, "stamina": -25, "icon": "stabilizer"},
	{"name": "Enricher", "desc": "Double health from loot, -20 max HP", "loot_mult": 2, "hp": -20, "icon": "enricher"},
	{"name": "Aerator", "desc": "+50 stamina (2 more dashes), -20 max HP", "stamina": 50, "hp": -20, "icon": "aerator"},
	{"name": "Concentrate", "desc": "+50% damage, -30 max HP", "dmg": 1.5, "hp": -30, "icon": "concentrate"},
	{"name": "Edge", "desc": "Melee x1.6, bubble x0.6", "melee": 1.6, "range": 0.6, "icon": "edge"},
	{"name": "Lobber", "desc": "Bubble x1.6, melee x0.6", "melee": 0.6, "range": 1.6, "icon": "lobber"},
]

# Materials dropped by slimes. Slot them as REAGENTS in your build (they are not used up).
var MATERIALS := {
	"acid_gel": {"name": "Acid Gel", "desc": "Concentration: +15% slash damage", "melee": 0.15},
	"etch_wing": {"name": "Etch Wing", "desc": "+20 stamina, +0.5 stamina regen", "stamina": 20, "regen": 0.5},
	"vitriol_gland": {"name": "Vitriol Gland", "desc": "+20% bubble damage, +10 blast radius", "range": 0.2, "radius": 10},
	"slime_core": {"name": "Slime Core", "desc": "+15 max HP", "hp": 15},
	"corrosion_heart": {"name": "Corrosion Heart", "desc": "+10% all damage, +5 HP from every loot pickup", "dmg": 0.1, "loot_bonus": 5},
}
# HP restored when Limus picks up this loot (extra goes to OVERHEAL)
var LOOT_HEAL := {"acid_gel": 10, "etch_wing": 10, "vitriol_gland": 10, "slime_core": 25, "corrosion_heart": 50}
var MATERIAL_ORDER := ["acid_gel", "etch_wing", "vitriol_gland", "slime_core", "corrosion_heart"]
# enemy kind -> material it drops
var DROPS := {"tank": "acid_gel", "annoying": "etch_wing", "ranged": "vitriol_gland", "dummy": "acid_gel"}

# ---------------- floors ----------------
# Floors: 1 Acid -> 2 Base -> 3 Fuel -> the Prime Reactor (final boss).
# Each floor is themed around one chemical: its enemies ARE that chemical (so the chemical it is
# weak to deals x2), its pits are that chemical, its rooms are tinted, and it ends in a themed boss.
# enemies: kind -> [sprite (frames/<sprite>.tres), tint, display name]
var FLOORS := [
	{"name": "Floor 1: The Acid Vats", "chem": ACID, "hazard": "acid",
		"hazard_tint": Color(0.9, 2.6, 0.5), "bg_tint": Color(0.8, 0.86, 1.0),
		"enemies": {"tank": ["muddy", Color(1, 1, 1), "Acid Slime"], "annoying": ["imp", Color(1, 1, 1), "Etch Imp"],
			"ranged": ["orc_shaman", Color(1, 1, 1), "Vitriol Shaman"], "dummy": ["skelet", Color(1, 1, 1), "Training Skeleton"]},
		"boss": ["big_demon", Color(1, 1, 1), "THE CORROSION CORE", 2.0]},
	{"name": "Floor 2: The Alkali Depths", "chem": BASE, "hazard": "lye",
		"hazard_tint": Color(1.2, 0.8, 2.6), "bg_tint": Color(0.8, 0.72, 1.06),
		"enemies": {"tank": ["swampy", Color(0.9, 0.6, 2.0), "Lye Slime"], "annoying": ["imp", Color(0.7, 0.8, 2.0), "Alkali Imp"],
			"ranged": ["necromancer", Color(1, 1, 1), "Lye Necromancer"], "dummy": ["skelet", Color(1, 1, 1), "Training Skeleton"]},
		"boss": ["big_zombie", Color(0.95, 0.75, 2.0), "THE ALKALINE TYRANT", 2.2]},
	{"name": "Floor 3: The Fuel Furnace", "chem": FUEL, "hazard": "burning fuel",
		"hazard_tint": Color(4.2, 1.7, 0.35), "bg_tint": Color(1.0, 0.78, 0.66),
		"enemies": {"tank": ["swampy", Color(2.2, 0.9, 0.35), "Cinder Slime"], "annoying": ["imp", Color(1.3, 0.9, 0.5), "Ember Imp"],
			"ranged": ["orc_warrior", Color(1.8, 1.0, 0.5), "Flare Grunt"], "dummy": ["skelet", Color(1, 1, 1), "Training Skeleton"]},
		"boss": ["ogre", Color(1.7, 0.95, 0.55), "THE FURNACE OGRE", 2.4]},
	{"name": "The Prime Reactor", "chem": ACID, "hazard": "reactor waste",
		"hazard_tint": Color(2.0, 1.4, 2.4), "bg_tint": Color(0.9, 0.8, 0.95),
		"enemies": {"tank": ["muddy", Color(1, 1, 1), "Acid Slime"], "annoying": ["imp", Color(1, 1, 1), "Etch Imp"],
			"ranged": ["orc_shaman", Color(1, 1, 1), "Vitriol Shaman"], "dummy": ["skelet", Color(1, 1, 1), "Training Skeleton"]},
		"boss": ["big_demon", Color(1, 1, 1), "THE PRIME CATALYST", 3.0]},
]
const FINAL_FLOOR := 3

## Difficulty grows per floor; the player's level-ups (after each floor) keep pace.
func enemy_hp_mult(floor_i: int) -> float:
	return 1.0 + 0.45 * min(floor_i, 2)

func enemy_dmg_bonus(floor_i: int) -> float:
	return 3.0 * min(floor_i, 2)

func boss_hp(floor_i: int) -> float:
	return 300.0 if floor_i == FINAL_FLOOR else 90.0 * (1.0 + 0.6 * floor_i)

# Level-up rewards (per level gained)
const LV_HP := 30
const LV_DMG := 0.25        # +25% slash and bubble damage
const LV_STAMINA := 25.0    # one extra dash
const LV_REGEN := 0.25     # stamina regen per second, per level

var ABILITIES := [
	{"name": "Slash", "icon": "slash", "key": "Left click / J"},
	{"name": "Slime Bubble", "icon": "bubble", "key": "Right click / K"},
	{"name": "Dash", "icon": "dash", "key": "Shift"},
	{"name": "Absorb Loot", "icon": "heal", "key": "walk over drops"},
]

func icon(n: String) -> Texture2D:
	return load("res://assets/icons/%s.png" % n) if n != "" else null


const PIXEL := 2.0


## Mini Dungeon stone frame as a 9-patch, drawn at 2x. size = on-screen size.
func frame(size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load("res://assets/ui/frame.png")
	n.patch_margin_left = 6; n.patch_margin_right = 6
	n.patch_margin_top = 6; n.patch_margin_bottom = 14
	n.size = size / PIXEL
	n.scale = Vector2(PIXEL, PIXEL)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n  # every 16x16 sprite/tile is drawn at 2x


var _scenes := {}
## Loads (and caches) a scene the first time it is needed.
func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## One-shot effect (scenes/fx/Effect.tscn) using frames/fx_<prefix>.tres; frees itself when done.
func fx(parent: Node, prefix: String, pos: Vector2, scl: float = PIXEL, fps: float = 14.0) -> AnimatedSprite2D:
	var e: AnimatedSprite2D = scene("res://scenes/fx/Effect.tscn").instantiate()
	e.sprite_frames = load("res://frames/fx_%s.tres" % prefix)
	e.speed_scale = fps / 14.0
	e.position = pos
	e.scale = Vector2(scl, scl)
	parent.add_child(e)
	return e


## Fading copy of a sprite's current frame (dash / dive afterimages).
func afterimage(parent: Node, spr: AnimatedSprite2D, tint: Color) -> void:
	var g = scene("res://scenes/fx/Ghost.tscn").instantiate()
	parent.add_child(g)
	g.setup(spr, spr.global_position, tint, "fade")


## Floating damage number (scenes/fx/DamageNumber.tscn).
func damage_number(parent: Node, pos: Vector2, text: String, col: Color, big: bool) -> void:
	var d = scene("res://scenes/fx/DamageNumber.tscn").instantiate()
	parent.add_child(d)
	d.show_number(pos, text, col, big)


## Damage multiplier: x2 if the defender is weak to the attacker, x0.5 for same chemical.
func multiplier(attacker: int, defender: int) -> float:
	if WEAK_TO[defender] == attacker:
		return 2.0
	if attacker == defender:
		return 0.5
	return 1.0


func _ready() -> void:
	_bind("left", [KEY_A, KEY_LEFT])
	_bind("right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_W, KEY_SPACE, KEY_UP])
	_bind("dash", [KEY_SHIFT])
	_bind("slash", [KEY_J], MOUSE_BUTTON_LEFT)
	_bind("throw", [KEY_K], MOUSE_BUTTON_RIGHT)
	_bind("inventory", [KEY_TAB, KEY_I])
	_bind("interact", [KEY_E])
	_bind("super", [KEY_Q], MOUSE_BUTTON_MIDDLE)
	_bind("restart", [KEY_R])


func _bind(action: String, keys: Array, mouse: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	if mouse > 0:
		var m := InputEventMouseButton.new()
		m.button_index = mouse
		InputMap.action_add_event(action, m)


## Camera shake (handled by main.gd).
func shake(amount: float) -> void:
	var m = get_tree().current_scene
	if m and m.has_method("add_shake"):
		m.add_shake(amount)


var _stopping := false
## Brief freeze-frame on impactful hits.
func hitstop(dur: float) -> void:
	if _stopping or get_tree().paused:
		return
	_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


## Death "splat": a copy of the sprite's current frame that flattens and fades (scenes/fx/Ghost.tscn).
func corpse(parent: Node, spr: AnimatedSprite2D, pos: Vector2, tint: Color = Color.WHITE) -> void:
	var g = scene("res://scenes/fx/Ghost.tscn").instantiate()
	parent.add_child(g)
	g.setup(spr, pos + spr.position, tint, "splat")


## The room the player is currently in (group "room").
func room() -> Node:
	return get_tree().get_first_node_in_group("room")


## Show a centre-screen message on the HUD (if there is one).
func hud_msg(text: String, dur: float) -> void:
	var h = get_tree().get_first_node_in_group("hud")
	if h:
		h.show_msg(text, dur)


func hud_toast(text: String) -> void:
	var h = get_tree().get_first_node_in_group("hud")
	if h:
		h.toast(text)
