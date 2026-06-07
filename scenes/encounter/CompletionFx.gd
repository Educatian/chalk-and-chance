extends RefCounted

static func add_completion_burst(parent: Node, rect: Rect2, won: bool = true) -> void:
	var root := Control.new()
	root.name = "CompletionBurst"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var palette := _win_palette() if won else _retry_palette()
	var top := _bar(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 4), palette[0])
	root.add_child(top)
	var bottom := _bar(rect.position + Vector2(8, rect.size.y - 14), Vector2(rect.size.x - 16, 3), palette[1])
	root.add_child(bottom)

	for i in range(10):
		var spark := ColorRect.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := rect.position.x + rect.size.x * 0.5 + side * (42.0 + float(i / 2) * 28.0)
		var y := rect.position.y + 26.0 + float(i % 5) * 24.0
		spark.position = Vector2(x, y)
		spark.size = Vector2(10 + (i % 3) * 3, 10 + ((i + 1) % 3) * 2)
		spark.color = palette[i % palette.size()]
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(spark)

	for i in range(5):
		var chip := ColorRect.new()
		chip.position = rect.position + Vector2(rect.size.x - 92 + i * 16, 22)
		chip.size = Vector2(10, 10)
		chip.color = palette[(i + 2) % palette.size()]
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(chip)

	if not bool(GameState.get_setting("reduced_motion", false)):
		root.modulate.a = 0.0
		var tw := root.create_tween()
		tw.tween_property(root, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(root, "scale", Vector2(1.015, 1.015), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "scale", Vector2.ONE, 0.10)

static func _bar(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.position = pos
	bar.size = size
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

static func _win_palette() -> Array:
	return [
		Color(0.98, 0.86, 0.42, 0.92),
		Color(0.30, 0.92, 0.86, 0.74),
		Color(0.38, 0.72, 0.48, 0.82),
		Color(0.62, 0.88, 0.95, 0.80),
		Color(0.96, 0.58, 0.25, 0.74),
	]

static func _retry_palette() -> Array:
	return [
		Color(0.96, 0.42, 0.34, 0.82),
		Color(0.98, 0.74, 0.32, 0.74),
		Color(0.62, 0.68, 0.80, 0.70),
		Color(0.77, 0.63, 0.98, 0.68),
		Color(0.42, 0.72, 0.86, 0.70),
	]
