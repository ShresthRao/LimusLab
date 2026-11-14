extends Sprite2D
## scenes/fx/Ghost.tscn — a frozen copy of another sprite's current frame.
## mode "fade":  afterimage that fades out (dash / boss dive trails).
## mode "splat": death splat — flash white, flatten, sink and fade.

func setup(src: AnimatedSprite2D, pos: Vector2, tint: Color, mode: String) -> void:
	texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	flip_h = src.flip_h
	scale = src.scale
	global_position = pos
	var tw := create_tween()
	if mode == "fade":
		z_index = -1
		modulate = tint
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
	else:
		z_index = 2
		modulate = Color(3, 3, 3) * tint
		tw.tween_property(self, "modulate", tint, 0.06)
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector2(scale.x * 1.6, scale.y * 0.25), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "position:y", position.y + scale.y * 6, 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.1)
		tw.chain()
	tw.tween_callback(queue_free)
