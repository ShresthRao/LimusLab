extends CanvasLayer
## scenes/ui/InventoryScreen.tscn — the LAB KIT. game.gd fades into it (only when the room has no
## enemies left) and pauses the world; TAB / I / Esc fades back out.
##
## Scene layout:
##   Scenery   Node2D at 4.44x: Sky (Stringstar background_0), TreeLeft + TreeRight + Ground
##             (Stringstar tileset.png) and hanging Vines from the same sheet.
##   Kit       the inventory panel between the two trees:
##     Abilities/Ability0..3   ability cards (Icon, Name, Stats)
##     Build/Chem, Build/Catalyst, Build/Reagent0..2   build slots (Slot.tscn, role "build")
##     Materials/*, Catalysts/*, Chemicals/*           bag slots (Slot.tscn, role "bag")
##     Stats                    Max HP / stamina / chemical summary
##     Info                     description pop-up for whatever is dragged or hovered
## Every slot is in group "kit_slot"; drag & drop calls on_drop() / clear_slot() below.

var player
var hover = null           # slot under the mouse
var info_key := ""

@onready var build_chem = $Kit/Build/Chem
@onready var build_cat = $Kit/Build/Catalyst
@onready var build_reagents := [$Kit/Build/Reagent0, $Kit/Build/Reagent1, $Kit/Build/Reagent2]
@onready var bag_mats: Array = $Kit/Materials.get_children()
@onready var bag_cats: Array = $Kit/Catalysts.get_children()
@onready var bag_chems: Array = $Kit/Chemicals.get_children()
@onready var ability_labels := [$Kit/Abilities/Ability0/Stats, $Kit/Abilities/Ability1/Stats, $Kit/Abilities/Ability2/Stats, $Kit/Abilities/Ability3/Stats]
@onready var stats_lbl: Label = $Kit/Stats
@onready var info_box: Control = $Kit/Info
@onready var info_icon: TextureRect = $Kit/Info/Icon
@onready var info_title: Label = $Kit/Info/Title
@onready var info_kind: Label = $Kit/Info/Kind
@onready var info_body: Label = $Kit/Info/Body


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sl in get_tree().get_nodes_in_group("kit_slot"):
		sl.inv = self
	info_box.visible = false
	refresh()
	# a gentle sway on the hanging vines
	var t := 0.0
	for v in $Scenery/Vines.get_children():
		var tw := v.create_tween().set_loops()
		tw.tween_property(v, "rotation", 0.04, 1.6 + t).set_trans(Tween.TRANS_SINE)
		tw.tween_property(v, "rotation", -0.04, 1.6 + t).set_trans(Tween.TRANS_SINE)
		t += 0.3


## Name, type line, description and slot hint for an item.
func describe(type: String, id) -> Dictionary:
	match type:
		"chem":
			var strong: String = Chem.NAMES[Chem.WEAK_TO[id]]
			return {"icon": Chem.icon("chem_%d" % id), "title": "%s flask" % Chem.NAMES[id], "kind": "BASE CHEMICAL",
				"body": "Your attacks deal x2 damage to %s enemies, x0.5 to %s ones.\nGoes in the Chemical slot." % [strong, Chem.NAMES[id]]}
		"catalyst":
			var c: Dictionary = Chem.CATALYSTS[id]
			return {"icon": Chem.icon(c["icon"]), "title": c["name"], "kind": "CATALYST",
				"body": "%s.\nGoes in the Catalyst slot." % c["desc"]}
		"material":
			var m: Dictionary = Chem.MATERIALS[id]
			return {"icon": Chem.icon(id), "title": m["name"], "kind": "REAGENT MATERIAL",
				"body": "%s.\nOwned %d (%d free) · heals +%d HP on pickup.\nGoes in a Reagent slot." % [m["desc"], int(player.materials.get(id, 0)), player.available(id), int(Chem.LOOT_HEAL.get(id, 10))]}
	return {}


func _update_info() -> void:
	var data = null
	var dragging := false
	var vp := get_viewport()
	if vp.gui_is_dragging():
		var dd = vp.gui_get_drag_data()
		if typeof(dd) == TYPE_DICTIONARY and dd.has("type"):
			data = dd
			dragging = true
	elif hover and is_instance_valid(hover) and not hover.is_empty():
		data = {"type": hover.accepts, "id": hover.item_id}
	if data == null:
		info_box.visible = false
		info_key = ""
		return
	var key := "%s:%s:%s" % [data["type"], str(data["id"]), dragging]
	if key == info_key:
		return
	info_key = key
	var dsc := describe(data["type"], data["id"])
	info_icon.texture = dsc["icon"]
	info_title.text = dsc["title"]
	info_kind.text = ("DRAGGING  ·  " if dragging else "") + dsc["kind"]
	info_body.text = dsc["body"]
	info_box.visible = true
	info_box.scale = Vector2(0.85, 0.85)   # pop-up
	info_box.modulate.a = 0.0
	var tw := info_box.create_tween().set_parallel(true)
	tw.tween_property(info_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(info_box, "modulate:a", 1.0, 0.12)


func _process(_d: float) -> void:
	_update_info()


# ---------------- drag & drop logic ----------------

func on_drop(target, data: Dictionary) -> void:
	target.scale = Vector2(1.25, 1.25)
	target.create_tween().tween_property(target, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
	var b: Dictionary = player.build
	var from = data["from"]
	if target.role == "build":
		match target.accepts:
			"chem":
				b["chem"] = data["id"]
			"catalyst":
				b["catalyst"] = data["id"]
			"material":
				if from.role == "build":  # move / swap between reagent slots
					var tmp = b["reagents"][target.index]
					b["reagents"][target.index] = b["reagents"][from.index]
					b["reagents"][from.index] = tmp
				elif player.available(data["id"]) > 0:
					b["reagents"][target.index] = data["id"]
	elif from.role == "build":
		clear_slot(from)
		return
	player.apply_build(false)
	refresh()


func clear_slot(s) -> void:
	var b: Dictionary = player.build
	match s.accepts:
		"catalyst":
			b["catalyst"] = 0
		"material":
			b["reagents"][s.index] = ""
		"chem":
			return  # Limus always has a chemical
	player.apply_build(false)
	refresh()


func refresh() -> void:
	var b: Dictionary = player.build
	build_chem.item_id = b["chem"]
	build_cat.item_id = b["catalyst"]
	for i in 3:
		build_reagents[i].item_id = b["reagents"][i]
	for s in bag_mats:
		s.count = player.available(s.item_id)
	for s in [build_chem, build_cat] + build_reagents + bag_mats + bag_cats + bag_chems:
		s.refresh()
	ability_labels[0].text = "Damage %.1f   Cooldown %.2fs" % [player.melee_dmg, player.attack_cd]
	ability_labels[1].text = "Dmg %.1f  Radius %d  Cost %d HP" % [player.range_dmg, int(player.bubble_radius), int(player.THROW_COST)]
	ability_labels[2].text = "Cost %d of %d stamina  (+%.2f/s)" % [int(player.dash_cost), int(player.max_stamina), player.stamina_regen]
	ability_labels[3].text = "+%d HP per drop, overheal max %d" % [10 * player.loot_mult + player.loot_bonus, int(player.max_overheal)]
	stats_lbl.text = "Max HP  %d\nStamina  %d\nChemical  %s\nStrong vs  %s" % [player.max_hp, int(player.max_stamina), Chem.NAMES[player.chem], Chem.NAMES[Chem.WEAK_TO[player.chem]]]
