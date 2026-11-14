extends CanvasLayer
## scenes/ui/DevMenu.tscn — DEVELOPER ONLY. Shift + = toggles it (handled in game.gd).
## Lists every room grouped by floor (bosses marked) and jumps there on click.
## The world is paused while it is open. Child nodes: Panel, Panel/Title, Panel/Scroll/List.

signal picked(index: int)
signal closed

var game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	sb.border_color = Color(1, 0.85, 0.4)
	sb.set_border_width_all(2)
	$Panel.add_theme_stylebox_override("panel", sb)
	var list: VBoxContainer = $Panel/Scroll/List
	var last_floor := -1
	for i in game.rooms.size():
		var fl: int = game.room_floors[i]
		if fl != last_floor:
			last_floor = fl
			var h := Label.new()
			h.text = Chem.FLOORS[fl]["name"]
			h.add_theme_color_override("font_color", Chem.COLORS[Chem.FLOORS[fl]["chem"]] if fl != Chem.FINAL_FLOOR else Color(1, 0.8, 0.3))
			list.add_child(h)
		var b := Button.new()
		var title: String = game.room_titles[i]
		b.text = ("   %2d.  %s" % [i, title]) + ("   ← you are here" if i == game.room_index else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if title.begins_with("BOSS") or title.begins_with("FINAL"):
			b.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
		b.pressed.connect(func(): picked.emit(i))
		list.add_child(b)
	await get_tree().process_frame
	if list.get_child_count() > 1:
		list.get_child(1).grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
