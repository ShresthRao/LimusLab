extends CanvasLayer
## scenes/ui/HUD.tscn — HP + overheal bar (with white damage trail), stamina (H2) with dash pips,
## chemical/catalyst line, Lab Kit availability, room name, centre messages, pickup toasts and the
## boss bar. Child nodes: Bars (Control the bars are drawn on), Info, RoomName, Msg, Toast (Labels).

var player
var boss
var room_name := ""
var msg_t := 0.0
var shown_hp := 100.0   # smoothed HP for the bar
var ghost_hp := 100.0   # white "damage taken" trail
var toast_t := 0.0

@onready var panel: Control = $Bars
@onready var msg: Label = $Msg
@onready var info: Label = $Info
@onready var room_label: Label = $RoomName
@onready var toast_lbl: Label = $Toast


func _ready() -> void:
	add_to_group("hud")
	panel.draw.connect(_draw_hud)


func show_msg(text: String, dur: float) -> void:
	msg.text = text
	msg_t = dur
	msg.pivot_offset = msg.size / 2
	msg.scale = Vector2(1.4, 1.4)
	msg.modulate.a = 0.0
	var tw := msg.create_tween().set_parallel(true)
	tw.tween_property(msg, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(msg, "modulate:a", 1.0, 0.15)


func toast(text: String) -> void:
	toast_lbl.text = text
	toast_t = 1.8


func _process(d: float) -> void:
	if is_instance_valid(player):
		shown_hp = lerp(shown_hp, float(player.hp), clamp(18.0 * d, 0.0, 1.0))
		ghost_hp = shown_hp if ghost_hp < shown_hp else move_toward(ghost_hp, shown_hp, 40.0 * d)
	toast_t -= d
	toast_lbl.visible = toast_t > 0
	panel.queue_redraw()
	msg_t -= d
	msg.visible = msg_t > 0
	room_label.text = room_name
	if is_instance_valid(player):
		var c: Dictionary = Chem.CATALYSTS[player.build["catalyst"]]
		var n := 0
		for k in player.materials:
			n += player.materials[k]
		var game = get_parent()
		var kit := "[TAB / I]  Lab Kit" if game.has_method("can_open_inventory") and game.can_open_inventory() else "Lab Kit sealed — clear the room"
		info.text = "Lv %d    Chemical: %s    Catalyst: %s    Materials: %d\n%s" % [player.level, Chem.NAMES[player.chem], c["name"], n, kit]


func _draw_hud() -> void:
	if not is_instance_valid(player):
		return
	var f := ThemeDB.fallback_font
	# HP bar: 3 px per HP point, overheal shown in gold after the red/green fill
	var px := 2.6
	var w: float = player.max_hp * px
	panel.draw_string(f, Vector2(16, 31), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	panel.draw_rect(Rect2(52, 16, w, 18), Color(0, 0, 0, 0.65))
	var frac: float = shown_hp / float(player.max_hp)
	var col := Color(0.35, 0.9, 0.35).lerp(Color(0.95, 0.2, 0.2), 1.0 - frac)
	if ghost_hp > shown_hp:
		panel.draw_rect(Rect2(52, 16, ghost_hp * px, 18), Color(1, 1, 1, 0.75))
	panel.draw_rect(Rect2(52, 16, shown_hp * px, 18), col)
	if player.overheal > 0:
		panel.draw_rect(Rect2(52 + w, 16, player.overheal * px, 18), Color(1.0, 0.82, 0.25))
		panel.draw_rect(Rect2(52 + w, 16, player.overheal * px, 18), Color(1, 1, 1), false, 1.0)
	panel.draw_rect(Rect2(52, 16, w, 18), Color(1, 1, 1, 0.6), false, 1.0)
	var t := "%d / %d" % [int(ceil(player.hp)), player.max_hp]
	if player.overheal > 0:
		t += "   +%d overheal" % int(ceil(player.overheal))
	panel.draw_string(f, Vector2(60, 30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	# stamina: 4 dash pips
	var y := 44
	panel.draw_string(f, Vector2(16, y + 11), "H2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	panel.draw_rect(Rect2(52, y, 200, 12), Color(0, 0, 0, 0.6))
	panel.draw_rect(Rect2(52, y, 200 * player.stamina / player.max_stamina, 12), Color(1.0, 0.75, 0.2))
	var dashes: int = int(player.max_stamina / player.dash_cost)
	for i in range(1, dashes):
		var x: float = 52 + 200.0 * i * player.dash_cost / player.max_stamina
		panel.draw_line(Vector2(x, y), Vector2(x, y + 12), Color(0, 0, 0, 0.8), 2)
	# SUPER: timer bar while active, prompt when available
	if player.super_charge > 0:
		var k: float = 1.0 - player.super_charge / player.SUPER_CHARGE
		panel.draw_string(f, Vector2(270, 55), "CHARGING", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.8, 0.35))
		panel.draw_rect(Rect2(350, 44, 160 * k, 12), Color(1.0, 0.6, 0.2))
	elif player.super_t > 0:
		panel.draw_string(f, Vector2(270, 55), "SUPER %ds" % ceil(player.super_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.35))
		panel.draw_rect(Rect2(350, 44, 160, 12), Color(0, 0, 0, 0.6))
		panel.draw_rect(Rect2(350, 44, 160 * player.super_t / player.SUPER_TIME, 12), Color(1.0, 0.75, 0.2))
	elif player.can_super():
		var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
		panel.draw_string(f, Vector2(270, 55), "SUPER READY  [Q]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.8, 0.3, a))
	if is_instance_valid(boss):
		panel.draw_string(f, Vector2(340, 660), boss.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		panel.draw_rect(Rect2(340, 668, 600, 16), Color(0, 0, 0, 0.7))
		panel.draw_rect(Rect2(340, 668, 600 * max(boss.hp, 0) / boss.max_hp, 16), Chem.COLORS[boss.chem])
