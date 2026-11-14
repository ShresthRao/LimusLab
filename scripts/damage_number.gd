extends Label
## scenes/fx/DamageNumber.tscn — pops up, floats upward and fades.

func show_number(pos: Vector2, txt: String, col: Color, big: bool) -> void:
	text = txt
	add_theme_color_override("font_color", col)
	add_theme_font_size_override("font_size", 22 if big else 16)
	position = pos + Vector2(randf_range(-14, 4), 0)
	pivot_offset = Vector2(8, 10)
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 36, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.chain().tween_callback(queue_free)
