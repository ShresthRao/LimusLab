extends Control
## scenes/ui/Slot.tscn — one Lab Kit slot. Uses Godot's built-in drag & drop.
## role "bag" = a source list entry; role "build" = an equipped build slot.
## accepts = "chem" | "catalyst" | "material".  item_key = which item a bag slot holds
## (material id, or the chemical / catalyst index as text). index = reagent slot number.
## Child nodes: Frame (NinePatchRect, Mini Dungeon stone frame at 2x), Icon, Count, Name.

@export_enum("bag", "build") var role := "bag"
@export_enum("chem", "catalyst", "material") var accepts := "material"
@export var item_key := ""
@export var index := 0
@export var hint := ""

var inv            # InventoryScreen (inventory.gd), set in its _ready
var item_id = null # int for chem/catalyst, String for material
var count := -1    # bag materials: how many are free to drag (-1 = no counter)

@onready var bg: NinePatchRect = $Frame
@onready var icon: TextureRect = $Icon
@onready var lbl: Label = $Count
@onready var name_lbl: Label = $Name


func _ready() -> void:
	if item_key != "":
		item_id = item_key if accepts == "material" else int(item_key)
	mouse_entered.connect(func():
		if inv:
			inv.hover = self
		create_tween().tween_property(self, "scale", Vector2(1.06, 1.06), 0.08))
	mouse_exited.connect(func():
		if inv and inv.hover == self:
			inv.hover = null
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.08))
	pivot_offset = size / 2
	refresh()


func is_empty() -> bool:
	return item_id == null or (accepts == "material" and item_id == "") or (accepts == "catalyst" and item_id == 0 and role == "build")


func refresh() -> void:
	if not is_node_ready():
		return
	icon.modulate = Color.WHITE
	lbl.text = ""
	if is_empty():
		icon.texture = null
		name_lbl.text = hint
		tooltip_text = hint
		bg.self_modulate = Color(0.7, 0.75, 0.8) if role == "build" else Color.WHITE
		return
	bg.self_modulate = Color(0.8, 1.3, 0.6) if role == "build" else Color.WHITE
	match accepts:
		"chem":
			icon.texture = Chem.icon("chem_%d" % item_id)
			name_lbl.text = Chem.NAMES[item_id]
			tooltip_text = "%s chemical\nWeak to %s. Strong vs %s." % [Chem.NAMES[item_id], Chem.NAMES[Chem.WEAK_TO[item_id]], Chem.NAMES[Chem.WEAK_TO[item_id]]]
		"catalyst":
			var c: Dictionary = Chem.CATALYSTS[item_id]
			icon.texture = Chem.icon(c["icon"])
			name_lbl.text = c["name"]
			tooltip_text = "%s\n%s" % [c["name"], c["desc"]]
		"material":
			var m: Dictionary = Chem.MATERIALS[item_id]
			icon.texture = Chem.icon(item_id)
			name_lbl.text = m["name"]
			tooltip_text = "%s\n%s" % [m["name"], m["desc"]]
			if count >= 0:
				lbl.text = "x%d" % count
				if count == 0:
					icon.modulate = Color(1, 1, 1, 0.3)


func _get_drag_data(_pos: Vector2):
	if is_empty() or (role == "bag" and count == 0):
		return null
	var prev := TextureRect.new()
	prev.texture = icon.texture
	prev.modulate = icon.modulate
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.size = Vector2(48, 48)
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = Vector2(-24, -24)
	set_drag_preview(holder)
	return {"type": accepts, "id": item_id, "from": self}


func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("type") or data["type"] != accepts:
		return false
	if role == "build":
		return true
	# dropping an equipped item back onto the bag = unequip
	return data["from"].role == "build"


func _drop_data(_pos: Vector2, data) -> void:
	inv.on_drop(self, data)


func _gui_input(e: InputEvent) -> void:
	if role == "build" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		inv.clear_slot(self)
