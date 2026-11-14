extends SceneTree
## Generates every scene and resource of Limus Lab. Run from the project folder:
##   godot --headless --import            (first time, so the PNGs are imported)
##   godot --headless -s tools/build_scenes.gd
## Outputs:
##   frames/*.tres                 SpriteFrames for Limus, monsters and effects
##   tiles/lab_tileset.tres        TileSet (Laboratory.png, hospital2.png, LabIcons.png, acid tiles)
##   scenes/fx/*.tscn              Effect, Ghost, DamageNumber
##   scenes/actors/*.tscn          Player, Enemy, Boss, Projectile, Pickup
##   scenes/rooms/parts/*.tscn     ExitDoor, AcidPool
##   scenes/rooms/Room_*.tscn      every room, from tools/rooms.json
##   scenes/ui/*.tscn              HUD, Slot, InventoryScreen
##   scenes/Main.tscn
## After generating you can edit everything in the Godot editor. Re-running this tool overwrites
## the generated files, so either keep editing in Godot OR edit rooms.json and regenerate.

const T := 16          # source tile size
const S := 2.0         # every 16x16 tile/sprite is drawn at 2x
const W := 32          # world size of one tile
const FLOOR := 19

const SRC_LAB := 0     # Laboratory.png (SciFi lab, 16x16)
const SRC_HOSP := 1    # hospital2.png (lab props, 16x16)
const SRC_ICONS := 2   # LabIcons.png (flasks, burners, 16x16)
const SRC_ACID_TOP := 3
const SRC_ACID := 4

var tileset: TileSet
var chem_data   # an instance of scripts/chem.gd, for the floor themes
var room_files: PackedStringArray = []
var room_titles: PackedStringArray = []
var room_floors: PackedInt32Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://frames")
	DirAccess.make_dir_recursive_absolute("res://tiles")
	for d in ["fx", "actors", "rooms/parts", "ui"]:
		DirAccess.make_dir_recursive_absolute("res://scenes/" + d)
	chem_data = load("res://scripts/chem.gd").new()
	_frames()
	_tileset()
	_fx_scenes()
	_actor_scenes()
	_part_scenes()
	_ui_scenes()
	var rooms = JSON.parse_string(FileAccess.get_file_as_string("res://tools/rooms.json"))
	for r in rooms:
		_room(r)
	_main()
	chem_data.free()
	print("build_scenes: done")
	quit()


# ------------------------------------------------------------------ helpers

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed " + path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed " + path)
	root.free()
	print("  wrote ", path)


func _add(parent: Node, n: Node, nm: String) -> Node:
	n.name = nm
	parent.add_child(n)
	return n


func _sprite(tex: String, region: Rect2 = Rect2(), scl: float = S) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex)
	if region.size != Vector2.ZERO:
		s.region_enabled = true
		s.region_rect = region
	s.scale = Vector2(scl, scl)
	return s


func _label(text: String, pos: Vector2, fs: int, col: Color = Color.WHITE, outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _frame(size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load("res://assets/ui/frame.png")
	n.patch_margin_left = 6
	n.patch_margin_right = 6
	n.patch_margin_top = 6
	n.patch_margin_bottom = 14
	n.size = size / S
	n.scale = Vector2(S, S)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _particles(amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/spark.png")
	p.amount = amount
	p.lifetime = life
	return p


# ------------------------------------------------------------------ SpriteFrames

func _sf(defs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for d in defs:   # [name, [texture paths], fps, loop]
		if not sf.has_animation(d[0]):
			sf.add_animation(d[0])
		sf.set_animation_speed(d[0], d[2])
		sf.set_animation_loop(d[0], d[3])
		for p in d[1]:
			sf.add_frame(d[0], load(p))
	if sf.has_animation("default") and sf.get_frame_count("default") == 0:
		sf.remove_animation("default")
	return sf


func _seq(fmt: String, idx: Array) -> Array:
	var out := []
	for i in idx:
		out.append(fmt % i)
	return out


func _frames() -> void:
	var limus := _sf([
		["idle", _seq("res://assets/chars/limus_idle_%d.png", range(9)), 9.0, true],
		["run", _seq("res://assets/chars/limus_walk_%d.png", range(8)), 12.0, true],
		["jump", _seq("res://assets/chars/limus_walk_%d.png", [6, 7]), 14.0, false],
		["fall", _seq("res://assets/chars/limus_walk_%d.png", [0]), 1.0, false],
		["land", _seq("res://assets/chars/limus_walk_%d.png", [3, 4, 5]), 18.0, false],
		["attack", _seq("res://assets/chars/limus_walk_%d.png", [3, 4, 6, 7, 0]), 24.0, false],
		["dash", _seq("res://assets/chars/limus_walk_%d.png", [3]), 1.0, false],
		["hurt", _seq("res://assets/chars/limus_hurt_%d.png", range(6)), 18.0, false],
		["death", _seq("res://assets/chars/limus_death_%d.png", range(10)), 12.0, false],
	])
	ResourceSaver.save(limus, "res://frames/limus.tres")
	for k in ["muddy", "imp", "orc_shaman", "skelet", "big_demon", "swampy", "necromancer", "orc_warrior", "ogre", "big_zombie"]:
		var sf := _sf([
			["idle", _seq("res://assets/chars/" + k + "_idle_%d.png", range(4)), 8.0, true],
			["run", _seq("res://assets/chars/" + k + "_run_%d.png", range(4)), 8.0, true],
		])
		ResourceSaver.save(sf, "res://frames/%s.tres" % k)
	for c in 4:
		for fx in ["boom", "slash"]:
			var sf := _sf([["default", _seq("res://assets/fx/" + fx + "_" + str(c) + "_%d.png", range(3)), 14.0, false]])
			ResourceSaver.save(sf, "res://frames/fx_%s_%d.tres" % [fx, c])
	var sup := {"ring": [5, 12.0, true], "pillar": [6, 2.0, false], "burst": [6, 12.0, false], "aura": [4, 10.0, true]}
	for k in sup:
		var sf := _sf([["default", _seq("res://assets/fx/super_" + k + "_%d.png", range(sup[k][0])), sup[k][1], sup[k][2]]])
		ResourceSaver.save(sf, "res://frames/fx_super_%s.tres" % k)
	print("  wrote frames/*.tres")


# ------------------------------------------------------------------ TileSet

func _atlas(path: String) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(T, T)
	var img: Image = src.texture.get_image()
	for y in img.get_height() / T:
		for x in img.get_width() / T:
			if not img.get_region(Rect2i(x * T, y * T, T, T)).is_invisible():
				src.create_tile(Vector2i(x, y))
	return src


func _collide(src: TileSetAtlasSource, coords: Vector2i, one_way: bool) -> void:
	if not src.has_tile(coords):
		return
	var td := src.get_tile_data(coords, 0)
	td.add_collision_polygon(0)
	var top := -5.0 if one_way else -8.0   # platforms: walkable surface a little below the lip
	td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, top), Vector2(8, top), Vector2(8, 8), Vector2(-8, 8)]))
	td.set_collision_polygon_one_way(0, 0, one_way)


func _tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	var lab := _atlas("res://assets/lab/Laboratory.png")
	tileset.add_source(lab, SRC_LAB)
	tileset.add_source(_atlas("res://assets/lab/hospital2.png"), SRC_HOSP)
	tileset.add_source(_atlas("res://assets/lab/LabIcons.png"), SRC_ICONS)
	tileset.add_source(_atlas("res://assets/tiles/acid_top.png"), SRC_ACID_TOP)
	tileset.add_source(_atlas("res://assets/tiles/acid.png"), SRC_ACID)
	for x in range(10, 16):
		for y in [8, 9, 10, 11, 13]:
			_collide(lab, Vector2i(x, y), false)       # floors / walls / ceilings
	for x in range(8, 16):
		_collide(lab, Vector2i(x, 2), true)            # one-way slabs
	ResourceSaver.save(tileset, "res://tiles/lab_tileset.tres")
	tileset = load("res://tiles/lab_tileset.tres")
	print("  wrote tiles/lab_tileset.tres")


# ------------------------------------------------------------------ fx scenes

func _fx_scenes() -> void:
	var e := AnimatedSprite2D.new()
	e.name = "Effect"
	e.set_script(load("res://scripts/effect.gd"))
	e.sprite_frames = load("res://frames/fx_boom_0.tres")
	_save(e, "res://scenes/fx/Effect.tscn")

	var g := Sprite2D.new()
	g.name = "Ghost"
	g.set_script(load("res://scripts/ghost.gd"))
	_save(g, "res://scenes/fx/Ghost.tscn")

	# --- super move effects
	var sc := Node2D.new()
	sc.name = "SuperCharge"
	sc.set_script(load("res://scripts/super_charge.gd"))
	var rings := AnimatedSprite2D.new()
	rings.sprite_frames = load("res://frames/fx_super_ring.tres")
	rings.scale = Vector2(7, 7)
	rings.modulate = Color(1.4, 1.2, 1.0)
	rings.position = Vector2(0, -4)
	_add(sc, rings, "Rings")
	var pil := AnimatedSprite2D.new()
	pil.sprite_frames = load("res://frames/fx_super_pillar.tres")
	pil.scale = Vector2(4, 4)
	pil.position = Vector2(0, -50)          # 16x32 frame, base at Limus' feet
	pil.z_index = -1
	_add(sc, pil, "Pillar")
	var sp := _particles(30, 0.6)
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 90
	sp.gravity = Vector2.ZERO
	sp.radial_accel_min = -380                # pulled in toward Limus
	sp.radial_accel_max = -260
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.0
	sp.texture = load("res://assets/fx/fire_spark.png")
	sp.color = Color(1, 1, 1)
	_add(sc, sp, "Sparks")
	_save(sc, "res://scenes/fx/SuperCharge.tscn")

	var au := Node2D.new()
	au.name = "SuperAura"
	au.set_script(load("res://scripts/super_aura.gd"))
	var wh := AnimatedSprite2D.new()
	wh.sprite_frames = load("res://frames/fx_super_aura.tres")
	wh.scale = Vector2(3.6, 3.6)
	wh.position = Vector2(0, -4)
	wh.modulate = Color(1, 1, 1, 0.55)
	_add(au, wh, "Wheel")
	var em := _particles(16, 0.9)
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	em.emission_rect_extents = Vector2(18, 4)
	em.position = Vector2(0, 8)
	em.direction = Vector2(0, -1)
	em.spread = 15
	em.gravity = Vector2(0, -40)
	em.initial_velocity_min = 30
	em.initial_velocity_max = 70
	em.scale_amount_min = 0.4
	em.scale_amount_max = 0.8
	em.texture = load("res://assets/fx/fire_spark.png")
	em.color = Color(1, 1, 1, 0.9)
	_add(au, em, "Embers")
	_save(au, "res://scenes/fx/SuperAura.tscn")

	var d := _label("0", Vector2.ZERO, 16)
	d.name = "DamageNumber"
	d.z_index = 20
	d.set_script(load("res://scripts/damage_number.gd"))
	_save(d, "res://scenes/fx/DamageNumber.tscn")


# ------------------------------------------------------------------ actors

func _rect_shape(size: Vector2, local: bool = false) -> CollisionShape2D:
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	r.resource_local_to_scene = local
	c.shape = r
	return c


func _actor_scenes() -> void:
	# --- Player
	var p := CharacterBody2D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 2
	p.collision_mask = 1
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://frames/limus.tres")
	spr.animation = "idle"
	spr.scale = Vector2(1.5, 1.5)
	spr.position = Vector2(0, 13 - 24)
	_add(p, spr, "Sprite")
	_add(p, _rect_shape(Vector2(34, 26)), "Shape")
	var b := _particles(6, 0.8)
	b.direction = Vector2(0, -1)
	b.spread = 30
	b.gravity = Vector2(0, -60)
	b.initial_velocity_min = 10
	b.initial_velocity_max = 30
	b.scale_amount_min = 0.4
	b.scale_amount_max = 0.7
	b.color = Color(0.85, 0.95, 1, 0.8)
	b.position = Vector2(0, -14)
	_add(p, b, "Bubbles")
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	_add(p, cam, "Camera")
	_save(p, "res://scenes/actors/Player.tscn")

	# --- Enemy
	var e := CharacterBody2D.new()
	e.name = "Enemy"
	e.set_script(load("res://scripts/enemy.gd"))
	e.collision_layer = 4
	e.collision_mask = 1
	var es := AnimatedSprite2D.new()
	es.sprite_frames = load("res://frames/muddy.tres")
	es.animation = "idle"
	es.scale = Vector2(S, S)
	_add(e, es, "Sprite")
	_add(e, _rect_shape(Vector2(26, 24), true), "Shape")
	var ray := RayCast2D.new()
	ray.collision_mask = 1
	ray.target_position = Vector2(0, 32)
	_add(e, ray, "FloorRay")
	_save(e, "res://scenes/actors/Enemy.tscn")

	# --- Boss
	var bo := CharacterBody2D.new()
	bo.name = "Boss"
	bo.set_script(load("res://scripts/boss.gd"))
	bo.collision_layer = 4
	bo.collision_mask = 0
	var bs := AnimatedSprite2D.new()
	bs.sprite_frames = load("res://frames/big_demon.tres")
	bs.animation = "run"
	bs.scale = Vector2(S, S)
	_add(bo, bs, "Sprite")
	_add(bo, _rect_shape(Vector2(52, 62), true), "Shape")
	_save(bo, "res://scenes/actors/Boss.tscn")

	# --- Projectile
	var pr := Area2D.new()
	pr.name = "Projectile"
	pr.set_script(load("res://scripts/projectile.gd"))
	pr.collision_layer = 0
	pr.collision_mask = 4
	var ps := Sprite2D.new()
	ps.texture = load("res://assets/fx/bubble_0.png")
	ps.scale = Vector2(S, S)
	_add(pr, ps, "Sprite")
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8
	cs.shape = circ
	_add(pr, cs, "Shape")
	var tr := _particles(10, 0.3)
	tr.gravity = Vector2.ZERO
	tr.initial_velocity_max = 10
	tr.scale_amount_min = 0.3
	tr.scale_amount_max = 0.6
	tr.color = Color(1, 1, 1, 0.6)
	tr.show_behind_parent = true
	_add(pr, tr, "Trail")
	_save(pr, "res://scenes/actors/Projectile.tscn")

	# --- Pickup
	var pk := Node2D.new()
	pk.name = "Pickup"
	pk.set_script(load("res://scripts/pickup.gd"))
	var pks := Sprite2D.new()
	pks.texture = load("res://assets/icons/acid_gel.png")
	_add(pk, pks, "Sprite")
	var gl := _particles(4, 0.9)
	gl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	gl.emission_sphere_radius = 12
	gl.gravity = Vector2(0, -20)
	gl.initial_velocity_max = 8
	gl.scale_amount_min = 0.3
	gl.scale_amount_max = 0.6
	_add(pk, gl, "Sparkle")
	_save(pk, "res://scenes/actors/Pickup.tscn")


# ------------------------------------------------------------------ room parts

func _part_scenes() -> void:
	var d := Area2D.new()
	d.name = "ExitDoor"
	d.set_script(load("res://scripts/door.gd"))
	d.collision_layer = 0
	d.collision_mask = 2
	var fr := _sprite("res://assets/lab/hospital2.png", Rect2(11 * T, 2 * T, T, T))   # teal lab door
	fr.position = Vector2(0, -16)
	_add(d, fr, "Frame")
	var top := _sprite("res://assets/lab/hospital2.png", Rect2(11 * T, 0, T, T))      # door header panel
	top.position = Vector2(0, -48)
	_add(d, top, "Header")
	var sh := _sprite("res://assets/lab/hospital2.png", Rect2(5 * T, 1 * T, T, T))   # barred grate
	sh.position = Vector2(0, -16)
	_add(d, sh, "Shutter")
	var lamp := _sprite("res://assets/lab/hospital2.png", Rect2(11 * T, 4 * T, T, T))
	lamp.position = Vector2(0, -70)
	_add(d, lamp, "Lamp")
	_add(d, _label("EXIT →", Vector2(-40, -92), 16, Color(0.6, 1, 0.6)), "Arrow")
	var c := _rect_shape(Vector2(28, 40))
	c.position = Vector2(0, -20)
	_add(d, c, "Shape")
	_save(d, "res://scenes/rooms/parts/ExitDoor.tscn")

	var a := Area2D.new()
	a.name = "AcidPool"
	a.set_script(load("res://scripts/hazard.gd"))
	a.collision_layer = 0
	a.collision_mask = 2
	_add(a, _rect_shape(Vector2(128, 64), true), "Shape")
	var bub := _particles(4, 1.2)
	bub.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bub.emission_rect_extents = Vector2(64, 4)
	bub.position = Vector2(0, -28)
	bub.direction = Vector2(0, -1)
	bub.spread = 10
	bub.gravity = Vector2.ZERO
	bub.initial_velocity_min = 15
	bub.initial_velocity_max = 35
	bub.scale_amount_min = 0.5
	bub.scale_amount_max = 1.0
	_add(a, bub, "Bubbles")
	_save(a, "res://scenes/rooms/parts/AcidPool.tscn")


# ------------------------------------------------------------------ rooms

var _m: Array      # current map rows
var _w := 0


func _ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _w or y >= _m.size():
		return "#"
	return _m[y][x]


func _solid(x: int, y: int) -> bool:
	return _ch(x, y) == "#"


## Picks the right Laboratory.png piece for a solid cell from its neighbours.
func _ground_tile(x: int, y: int) -> Vector2i:
	var col := 11 + (x % 4)
	if not _solid(x - 1, y):
		col = 10
	elif not _solid(x + 1, y):
		col = 15
	if not _solid(x, y - 1):
		return Vector2i(col, 8)            # metal cap
	if not _solid(x, y - 2):
		return Vector2i(col, 9)            # panel border under the cap
	if not _solid(x, y + 1):
		return Vector2i(col, 13)           # underside (ceilings)
	return Vector2i(col, 10 + y % 2)       # panel body


const DECOR := {   # char: [source, atlas coords]   (multi-tile props continue to the right)
	"v": [SRC_HOSP, Vector2i(5, 1)], "w": [SRC_HOSP, Vector2i(6, 1)], "l": [SRC_HOSP, Vector2i(1, 3)],
	"k": [SRC_HOSP, Vector2i(10, 1)], "m": [SRC_HOSP, Vector2i(0, 2)], "c": [SRC_HOSP, Vector2i(3, 2)],
	"j": [SRC_HOSP, Vector2i(12, 3)], "r": [SRC_HOSP, Vector2i(8, 4)], "p": [SRC_HOSP, Vector2i(3, 3)],
	"M": [SRC_HOSP, Vector2i(4, 2)], "t": [SRC_HOSP, Vector2i(4, 3)], "T": [SRC_HOSP, Vector2i(0, 5)],
	"b": [SRC_ICONS, Vector2i(5, 0)], "f": [SRC_ICONS, Vector2i(2, 3)],
}


func _layer(root: Node, nm: String, collide: bool, tint: Color = Color.WHITE) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset
	l.scale = Vector2(S, S)
	l.collision_enabled = collide
	l.modulate = tint
	return _add(root, l, nm)


func _room(r: Dictionary) -> void:
	_m = r["map"]
	_w = _m[0].length()
	var root := Node2D.new()
	root.name = r["file"]
	root.set_script(load("res://scripts/room.gd"))
	root.room_title = r["title"]
	root.tutorial = r.get("tutorial", false)
	root.boss_room = r.get("boss", false)
	root.waves = r.get("waves", [])
	root.sub_boss = r.get("sub", "")
	root.size_px = Vector2(_w * W, _m.size() * W)
	root.floor_y = FLOOR * W
	var fi: int = int(r.get("floor", 0))
	root.floor_i = fi
	root.floor_end = r.get("floor_end", false)
	root.start_x = 7 * W
	var theme: Dictionary = chem_data.FLOORS[fi]
	room_files.append("res://scenes/rooms/%s.tscn" % r["file"])
	room_titles.append(r["title"])
	room_floors.append(fi)

	var bg := _layer(root, "Background", false, theme["bg_tint"])
	bg.z_index = -2
	var ground := _layer(root, "Ground", true)
	var plats := _layer(root, "Platforms", true)
	var acid := _layer(root, "Acid", false, theme["hazard_tint"])
	var decor := _layer(root, "Decor", false)
	decor.z_index = -1
	var hazards := _add(root, Node2D.new(), "Hazards")
	var props := _add(root, Node2D.new(), "Props")
	var signs := _add(root, Node2D.new(), "Signs")
	var spawns := _add(root, Node2D.new(), "Spawns")
	var actors := _add(root, Node2D.new(), "Actors")
	var n_ground := 0
	var n_air := 0
	var run_start := {}

	for y in _m.size():
		for x in _w:
			var ch := _ch(x, y)
			var cell := Vector2i(x, y)
			if ch != "#":
				bg.set_cell(cell, SRC_LAB, Vector2i(11 + x % 4, 10 + y % 2))
			var foot := Vector2(x * W + W / 2.0, (y + 1) * W)   # bottom-centre of the cell
			match ch:
				"#":
					ground.set_cell(cell, SRC_LAB, _ground_tile(x, y))
				"=":
					var l := _ch(x - 1, y) != "="
					var rr := _ch(x + 1, y) != "="
					var c := Vector2i(11 + x % 4, 2)
					if l and rr:
						c = Vector2i(8, 2)
					elif l:
						c = Vector2i(10, 2)
					elif rr:
						c = Vector2i(15, 2)
					plats.set_cell(cell, SRC_LAB, c)
				"~":
					acid.set_cell(cell, SRC_ACID_TOP if _ch(x, y - 1) != "~" else SRC_ACID, Vector2i.ZERO)
				"P":
					var m := Marker2D.new()
					m.position = foot + Vector2(0, -13)
					_add(root, m, "PlayerSpawn")
				"B":
					var m := Marker2D.new()
					m.position = foot
					_add(root, m, "BossSpawn")
				"g":
					n_ground += 1
					var m := Marker2D.new()
					m.position = foot + Vector2(0, -20)
					_add(spawns, m, "Ground%d" % n_ground)
				"a":
					n_air += 1
					var m := Marker2D.new()
					m.position = foot + Vector2(0, -16)
					_add(spawns, m, "Air%d" % n_air)
				"x":
					var e: Node2D = load("res://scenes/actors/Enemy.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
					e.kind = "dummy"
					e.position = foot + Vector2(0, -14)
					_add(actors, e, "Dummy%d" % (actors.get_child_count() + 1))
				"D":
					var d: Node2D = load("res://scenes/rooms/parts/ExitDoor.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
					d.position = foot
					_add(root, d, "ExitDoor")
				"!":
					var s := _sprite("res://assets/lab/lab_tileset_LITE.png", Rect2(3 * 32, 32, 32, 32), 1.0)
					s.position = foot + Vector2(0, -16)
					_add(props, s, "Danger%d" % (props.get_child_count() + 1))
				_:
					if DECOR.has(ch):
						var k := 0   # position inside a multi-tile prop run
						while ch in "MtT" and _ch(x - k - 1, y) == ch:
							k += 1
						decor.set_cell(cell, DECOR[ch][0], DECOR[ch][1] + Vector2i(k, 0))
	# acid hurt zones: one AcidPool per run of acid on the floor row
	var x := 0
	while x < _w:
		if _ch(x, FLOOR) == "~":
			var x0 := x
			while _ch(x, FLOOR) == "~":
				x += 1
			var pool: Area2D = load("res://scenes/rooms/parts/AcidPool.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			pool.size_px = Vector2((x - x0) * W, 64)
			pool.get_node("Bubbles").color = theme["hazard_tint"].clamp(Color(0, 0, 0), Color(1, 1, 1)).lerp(Color.WHITE, 0.3)
			pool.position = Vector2((x0 + x) * W / 2.0, FLOOR * W + 32)
			_add(hazards, pool, "Pit%d" % (hazards.get_child_count() + 1))
		x += 1
	for s in r.get("signs", []):
		_add(signs, _label(s[2], Vector2(s[0] * W, s[1] * W), 16, Color(0.75, 1.0, 0.85), 6), "Sign%d" % (signs.get_child_count() + 1))
	if not root.has_node("BossSpawn"):
		var m := Marker2D.new()
		m.position = Vector2(_w * W / 2.0, 200)
		_add(root, m, "BossSpawn")
	root.move_child(actors, -1)
	_save(root, "res://scenes/rooms/%s.tscn" % r["file"])


# ------------------------------------------------------------------ UI

func _ui_scenes() -> void:
	# --- HUD
	var h := CanvasLayer.new()
	h.name = "HUD"
	h.set_script(load("res://scripts/hud.gd"))
	var bars := Control.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(h, bars, "Bars")
	_add(h, _label("", Vector2(16, 64), 15, Color.WHITE, 5), "Info")
	var rn := _label("", Vector2(880, 14), 18, Color.WHITE, 5)
	rn.size = Vector2(384, 30)
	rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(h, rn, "RoomName")
	var msg := _label("", Vector2(0, 150), 32, Color.WHITE, 5)
	msg.size = Vector2(1280, 100)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(h, msg, "Msg")
	_add(h, _label("", Vector2(16, 670), 18, Color.WHITE, 5), "Toast")
	_save(h, "res://scenes/ui/HUD.tscn")

	# --- Slot
	var s := Control.new()
	s.name = "Slot"
	s.set_script(load("res://scripts/slot.gd"))
	s.size = Vector2(64, 64)
	s.custom_minimum_size = Vector2(64, 64)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	_add(s, _frame(Vector2(64, 64)), "Frame")
	var ic := TextureRect.new()
	ic.position = Vector2(8, 4)
	ic.size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(s, ic, "Icon")
	var cnt := _label("", Vector2(32, 40), 12)
	cnt.size = Vector2(28, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(s, cnt, "Count")
	var nm := _label("", Vector2(-10, 64), 10, Color(0.88, 0.92, 0.97), 3)
	nm.size = Vector2(84, 16)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(s, nm, "Name")
	_save(s, "res://scenes/ui/Slot.tscn")

	_inventory_screen()
	_level_up_screen()
	_dev_menu()


func _slot(parent: Node, nm: String, pos: Vector2, role: String, accepts: String, key: String, hint: String = "", index: int = 0) -> void:
	var s: Control = load("res://scenes/ui/Slot.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	s.position = pos
	s.role = role
	s.accepts = accepts
	s.item_key = key
	s.hint = hint
	s.index = index
	_add(parent, s, nm)
	s.add_to_group("kit_slot", true)


func _inventory_screen() -> void:
	var NAT := "res://assets/nature/tileset.png"
	var root := CanvasLayer.new()
	root.name = "InventoryScreen"
	root.layer = 10
	root.set_script(load("res://scripts/inventory.gd"))

	# ---- scenery: Stringstar background_0 + trees, ground and vines from tileset.png
	var k := 1280.0 / 288.0
	var sc := _add(root, Node2D.new(), "Scenery")
	sc.scale = Vector2(k, k)
	var sky := _sprite("res://assets/nature/background_0.png", Rect2(), 1.0)
	sky.centered = false
	_add(sc, sky, "Sky")
	var vines := _add(sc, Node2D.new(), "Vines")
	var vine_parts := [Rect2(0, 31, 16, 34), Rect2(16, 31, 16, 18), Rect2(32, 31, 16, 46)]
	var vx := [-2, 22, 44, 60, 86, 120, 150, 178, 236, 258, 276]
	for i in vx.size():
		var v := _sprite(NAT, vine_parts[i % 3], 1.0)
		v.centered = false
		v.position = Vector2(vx[i], -1)
		_add(vines, v, "Vine%d" % (i + 1))
	var tl := _sprite(NAT, Rect2(2, 78, 58, 68), 1.0)
	tl.centered = false
	tl.position = Vector2(-18, 64)
	_add(sc, tl, "TreeLeft")
	var trr := _sprite(NAT, Rect2(172, 8, 112, 138), 1.0)
	trr.centered = false
	trr.position = Vector2(214, -6)
	_add(sc, trr, "TreeRight")
	var gr := _sprite(NAT, Rect2(0, 136, 288, 40), 1.0)
	gr.centered = false
	gr.position = Vector2(0, 122)
	_add(sc, gr, "Ground")
	var gr2 := _sprite(NAT, Rect2(0, 160, 128, 16), 1.0)
	gr2.centered = false
	gr2.position = Vector2(160, 146)
	_add(sc, gr2, "GroundFill")

	# ---- the kit, between the trees
	var kit := Control.new()
	kit.set_anchors_preset(Control.PRESET_FULL_RECT)
	kit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, kit, "Kit")
	var fr := _frame(Vector2(750, 524))
	fr.position = Vector2(185, 16)
	fr.self_modulate = Color(1, 1, 1, 0.94)
	_add(kit, fr, "Frame")
	var head := Color(0.7, 1.0, 0.45)
	var soft := Color(0.85, 0.9, 0.95)
	_add(kit, _label("LAB KIT", Vector2(205, 26), 26, head), "Title")
	_add(kit, _label("Drag into the BUILD · drag back or right-click to remove · TAB to close", Vector2(340, 36), 11, soft), "Hint")

	_add(kit, _label("ABILITIES", Vector2(205, 82), 15, head), "AbilitiesTitle")
	var ab := _add(kit, Control.new(), "Abilities")
	var names := ["Slash  [LMB / J]", "Slime Bubble  [RMB / K]", "Dash  [Shift]", "Absorb Loot"]
	var icons := ["slash", "bubble", "dash", "heal"]
	for i in 4:
		var card := Control.new()
		card.position = Vector2(205, 104 + i * 68)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add(ab, card, "Ability%d" % i)
		_add(card, _frame(Vector2(215, 62)), "Frame")
		var ai := TextureRect.new()
		ai.texture = load("res://assets/icons/%s.png" % icons[i])
		ai.position = Vector2(8, 10)
		ai.size = Vector2(40, 40)
		ai.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ai.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_add(card, ai, "Icon")
		_add(card, _label(names[i], Vector2(54, 6), 12), "Name")
		var st := _label("", Vector2(54, 26), 10, soft, 3)
		st.size = Vector2(156, 30)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_add(card, st, "Stats")

	# info pop-up (free space under the abilities)
	var info := Control.new()
	info.position = Vector2(205, 380)
	info.size = Vector2(215, 150)
	info.pivot_offset = Vector2(107, 75)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(kit, info, "Info")
	var inf := _frame(Vector2(215, 150))
	inf.self_modulate = Color(0.85, 1.15, 0.8)
	_add(info, inf, "Frame")
	var ii := TextureRect.new()
	ii.position = Vector2(10, 10)
	ii.size = Vector2(48, 48)
	ii.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ii.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_add(info, ii, "Icon")
	_add(info, _label("", Vector2(66, 10), 10, head, 3), "Kind")
	_add(info, _label("", Vector2(66, 26), 16), "Title")
	var body := _label("", Vector2(10, 64), 11, soft, 3)
	body.size = Vector2(196, 80)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(info, body, "Body")

	# build
	_add(kit, _label("BUILD", Vector2(440, 82), 15, head), "BuildTitle")
	_add(kit, _label("Chemical      Catalyst       Reagents (slime materials)", Vector2(440, 104), 10, soft, 3), "BuildLabels")
	var bd := _add(kit, Control.new(), "Build")
	_slot(bd, "Chem", Vector2(440, 122), "build", "chem", "", "Chemical")
	_slot(bd, "Catalyst", Vector2(516, 122), "build", "catalyst", "", "No catalyst")
	for i in 3:
		_slot(bd, "Reagent%d" % i, Vector2(600 + i * 76, 122), "build", "material", "", "Empty", i)
	var stats := _label("", Vector2(836, 108), 11, head, 3)
	_add(kit, stats, "Stats")

	_add(kit, _label("MATERIALS  (dropped by slimes)", Vector2(440, 212), 15, head), "MaterialsTitle")
	var mats := _add(kit, Control.new(), "Materials")
	var order := ["acid_gel", "etch_wing", "vitriol_gland", "slime_core", "corrosion_heart"]
	for i in order.size():
		_slot(mats, order[i], Vector2(440 + i * 76, 234), "bag", "material", order[i])
	_add(kit, _label("CATALYSTS", Vector2(440, 320), 15, head), "CatalystsTitle")
	var cats := _add(kit, Control.new(), "Catalysts")
	for i in range(1, 8):
		_slot(cats, "C%d" % i, Vector2(440 + (i - 1) * 68, 342), "bag", "catalyst", str(i))
	_add(kit, _label("BASE CHEMICALS", Vector2(440, 428), 15, head), "ChemicalsTitle")
	var chs := _add(kit, Control.new(), "Chemicals")
	for i in 4:
		_slot(chs, "H%d" % i, Vector2(440 + i * 76, 450), "bag", "chem", str(i))
	_save(root, "res://scenes/ui/InventoryScreen.tscn")


# ------------------------------------------------------------------ Main

func _dev_menu() -> void:
	var root := CanvasLayer.new()
	root.name = "DevMenu"
	root.layer = 70
	root.set_script(load("res://scripts/dev_menu.gd"))
	var panel := Panel.new()
	panel.position = Vector2(340, 40)
	panel.size = Vector2(600, 640)
	_add(root, panel, "Panel")
	var t := _label("DEV: ROOM SELECT   (Shift + = or Esc to close)", Vector2(16, 10), 16, Color(1, 0.85, 0.4))
	_add(panel, t, "Title")
	var sc := ScrollContainer.new()
	sc.position = Vector2(16, 44)
	sc.size = Vector2(568, 580)
	_add(panel, sc, "Scroll")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(sc, list, "List")
	_save(root, "res://scenes/ui/DevMenu.tscn")


func _level_up_screen() -> void:
	var root := CanvasLayer.new()
	root.name = "LevelUpScreen"
	root.layer = 60          # above the black fader
	root.set_script(load("res://scripts/level_up.gd"))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, dim, "Dim")
	var panel := Control.new()
	panel.position = Vector2(290, 80)
	panel.size = Vector2(700, 560)
	_add(root, panel, "Panel")
	_add(panel, _frame(Vector2(700, 560)), "Frame")
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = load("res://frames/fx_boom_0.tres")
	burst.position = Vector2(350, 56)
	burst.scale = Vector2(10, 10)
	burst.modulate = Color(1, 1, 1, 0.35)
	_add(panel, burst, "Burst")
	var head := Color(0.7, 1.0, 0.45)
	var soft := Color(0.85, 0.9, 0.95)
	var t := _label("FLOOR CLEARED", Vector2(0, 22), 30, head, 6)
	t.size = Vector2(700, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(panel, t, "Title")
	var sb := _label("LEVEL UP!", Vector2(0, 66), 22, Color(1, 0.9, 0.35), 5)
	sb.size = Vector2(700, 30)
	sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(panel, sb, "Sub")
	var rows := _add(panel, Control.new(), "Rows")
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var row := Control.new()
		row.position = Vector2(110, 116 + i * 40)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add(rows, row, "Row%d" % i)
		_add(row, _label("Stat", Vector2(0, 0), 18, soft), "Name")
		_add(row, _label("0", Vector2(230, 0), 18, Color(0.6, 0.65, 0.7)), "Old")
		_add(row, _label("→", Vector2(310, 0), 18, soft), "Arrow")
		_add(row, _label("0", Vector2(350, 0), 18), "New")
		_add(row, _label("", Vector2(440, 2), 15, Color(0.5, 1.0, 0.5)), "Gain")
	var rs := _label("HP and stamina fully restored", Vector2(0, 322), 14, Color(0.6, 0.95, 1.0))
	rs.size = Vector2(700, 20)
	rs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(panel, rs, "Restored")
	var nx := Control.new()
	nx.position = Vector2(40, 352)
	nx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(panel, nx, "Next")
	var nf := _frame(Vector2(620, 124))
	nf.self_modulate = Color(0.85, 1.1, 1.2)
	_add(nx, nf, "Frame")
	_add(nx, _label("NEXT:", Vector2(18, 12), 16, head), "Title")
	var nb := _label("", Vector2(18, 38), 13, soft, 3)
	nb.size = Vector2(590, 80)
	nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(nx, nb, "Body")
	var btn := Button.new()
	btn.text = "Continue   [Space]"
	btn.position = Vector2(250, 494)
	btn.size = Vector2(200, 42)
	btn.add_theme_font_size_override("font_size", 18)
	_add(panel, btn, "Continue")
	_save(root, "res://scenes/ui/LevelUpScreen.tscn")


func _main() -> void:
	var g := Node2D.new()
	g.name = "Main"
	g.set_script(load("res://scripts/game.gd"))
	g.rooms = room_files
	g.room_titles = room_titles
	g.room_floors = room_floors
	_add(g, Node2D.new(), "World")
	_add(g, load("res://scenes/ui/HUD.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), "HUD")
	var f := CanvasLayer.new()
	f.layer = 50
	_add(g, f, "Fader")
	var blk := ColorRect.new()
	blk.color = Color.BLACK
	blk.set_anchors_preset(Control.PRESET_FULL_RECT)
	blk.size = Vector2(1280, 720)
	blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(f, blk, "Black")
	_save(g, "res://scenes/Main.tscn")
