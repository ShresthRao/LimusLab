extends CanvasLayer
## scenes/ui/LevelUpScreen.tscn — the pop-up shown between floors (on top of the black fade).
## game.gd calls setup() after player.level_up(); each stat row counts up from its old value to the
## new one, then the next-floor briefing appears. SPACE / ENTER / click "Continue" emits `continued`.
## Final mode (after the Prime Catalyst) shows the victory card instead and offers R to play again.
## Child nodes: Dim, Panel (Frame, Burst, Title, Sub, Rows/Row0..4, Restored, Next/Title, Next/Body, Continue).

signal continued

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/Title
@onready var sub: Label = $Panel/Sub
@onready var rows: Array = $Panel/Rows.get_children()
@onready var restored: Label = $Panel/Restored
@onready var next_title: Label = $Panel/Next/Title
@onready var next_body: Label = $Panel/Next/Body
@onready var cont: Button = $Panel/Continue
@onready var burst: AnimatedSprite2D = $Panel/Burst

var ready_to_go := false
var final := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cont.pressed.connect(_go)
	cont.visible = false


## before/after are player.stat_snapshot() dictionaries.
func setup(cleared_floor: int, next_floor: int, before: Dictionary, after: Dictionary, is_final: bool = false) -> void:
	final = is_final
	if final:
		title.text = "THE PRIME CATALYST IS NEUTRALIZED"
		sub.text = "Limus escaped the lab!   Level %d" % after["level"]
	else:
		title.text = "FLOOR %d CLEARED" % (cleared_floor + 1)
		sub.text = "LEVEL UP!   Lv %d  →  Lv %d" % [before["level"], after["level"]]
	var defs := [
		["Max HP", "hp", "%d"],
		["Slash damage", "slash", "%.1f"],
		["Bubble damage", "bubble", "%.1f"],
		["Stamina", "stamina", "%d"],
		["Stamina regen", "regen", "%.2f /s"],
	]
	for i in rows.size():
		var d: Array = defs[i]
		rows[i].get_node("Name").text = d[0]
		rows[i].get_node("Old").text = d[2] % before[d[1]]
		rows[i].get_node("New").text = d[2] % before[d[1]]
		rows[i].modulate.a = 0.0
	restored.modulate.a = 0.0
	if final:
		next_title.text = "THANK YOU FOR PLAYING"
		next_body.text = "All four floors and the Prime Reactor are clear.\nPress R to play again."
	else:
		var nf: Dictionary = Chem.FLOORS[next_floor]
		if next_floor == Chem.FINAL_FLOOR:
			next_title.text = "NEXT:  THE PRIME REACTOR — FINAL BOSS"
			next_body.text = "The Prime Catalyst shifts between ALL FOUR chemicals every few seconds.\nWhatever flask you carry, it will be weak to you some of the time —\nstrike hardest when the warning names your chemical."
			$Panel/Next.modulate.a = 0.0
			_animate(before, after, defs)
			return
		var c: int = nf["chem"]
		next_title.text = "NEXT:  " + nf["name"].to_upper()
		next_body.text = "Its monsters are %s — they are weak to %s.\nUse the calm at each room's entrance: TAB opens the Lab Kit,\nso you can drag the %s flask into your Chemical slot." % [
			Chem.NAMES[c].to_upper(), Chem.NAMES[Chem.WEAK_TO[c]].to_upper(), Chem.NAMES[Chem.WEAK_TO[c]]]
	$Panel/Next.modulate.a = 0.0
	_animate(before, after, defs)


func _animate(before: Dictionary, after: Dictionary, defs: Array) -> void:
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.chain().tween_callback(func(): burst.play("default"))
	for i in rows.size():
		var row: Control = rows[i]
		var key: String = defs[i][1]
		var fmt: String = defs[i][2]
		tw.chain().tween_property(row, "modulate:a", 1.0, 0.12)
		var counter := func(v: float): row.get_node("New").text = fmt % v
		tw.chain().tween_method(counter, float(before[key]), float(after[key]), 0.35)
		var gain: float = after[key] - before[key]
		tw.tween_callback(func():
			if gain > 0.001:
				row.get_node("Gain").text = "+" + (fmt % gain).replace(" /s", "")
				row.get_node("New").add_theme_color_override("font_color", Color(1.0, 0.9, 0.35)))
	tw.chain().tween_property(restored, "modulate:a", 1.0, 0.2)
	tw.chain().tween_property($Panel/Next, "modulate:a", 1.0, 0.3)
	tw.chain().tween_callback(func():
		ready_to_go = true
		cont.visible = not final
		if not final:
			cont.grab_focus())


func _unhandled_input(e: InputEvent) -> void:
	if not ready_to_go:
		return
	if final and e.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif not final and (e.is_action_pressed("jump") or e.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_go()


func _go() -> void:
	if not ready_to_go or final:
		return
	ready_to_go = false
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): continued.emit())
