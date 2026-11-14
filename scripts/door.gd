extends Area2D
## scenes/rooms/parts/ExitDoor.tscn — the lab door at the end of a room.
## Locked (red lamp, closed shutter) until the room is cleared; then the shutter slides up,
## the lamp turns green and touching the door asks the game to fade into the next room.
## Child nodes: Frame / Shutter (Sprite2D, lab tiles), Lamp (Sprite2D), Arrow (Label), Shape.

signal entered

var locked := true
var used := false

@onready var shutter: Sprite2D = $Shutter
@onready var lamp: Sprite2D = $Lamp
@onready var arrow: Label = $Arrow


func _ready() -> void:
	body_entered.connect(_on_body)
	arrow.visible = false
	lamp.modulate = Color(1.6, 0.4, 0.4)


func unlock() -> void:
	if not locked:
		return
	locked = false
	lamp.modulate = Color(0.5, 1.8, 0.6)
	arrow.visible = true
	var tw := create_tween()
	tw.tween_property(shutter, "position:y", shutter.position.y - 48, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shutter, "modulate:a", 0.0, 0.6)
	var a := create_tween().set_loops()
	a.tween_property(arrow, "position:x", arrow.position.x + 8, 0.4)
	a.tween_property(arrow, "position:x", arrow.position.x, 0.4)
	# the player may already be standing in the doorway
	for b in get_overlapping_bodies():
		_on_body(b)


func _on_body(b) -> void:
	if locked or used or not b.is_in_group("player"):
		return
	used = true
	entered.emit()
