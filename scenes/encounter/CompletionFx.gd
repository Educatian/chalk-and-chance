extends RefCounted
## Debrief "juice": accent bars, a rank stamp, a confetti burst that clears off the
## text, a panel entrance, and a score count-up. Callers may run PixelUi.scale_tree
## on the overlay right after this, so all motion is started one frame later and
## measured from the (possibly scaled) nodes instead of the authored rect.

static func add_completion_burst(parent: Node, rect: Rect2, won: bool = true, rank: String = "") -> void:
	if parent is CanvasItem:
		(parent as CanvasItem).z_index = 10

	var root := Control.new()
	root.name = "CompletionBurst"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var palette := _win_palette() if won else _retry_palette()
	var top := _bar(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 4), palette[0])
	top.name = "TopBar"
	root.add_child(top)
	var bottom := _bar(rect.position + Vector2(8, rect.size.y - 14), Vector2(rect.size.x - 16, 3), palette[1])
	root.add_child(bottom)

	var stamp: Label = null
	if rank != "" and rank != "-":
		stamp = Label.new()
		stamp.name = "RankStamp"
		stamp.text = rank
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var d := minf(rect.size.y * 0.42, 84.0)
		stamp.size = Vector2(d, d)
		stamp.position = rect.position + Vector2(rect.size.x - d - 18.0, 20.0)
		stamp.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
		stamp.add_theme_font_size_override("font_size", int(d * 0.5))
		stamp.add_theme_color_override("font_color", _rank_color(rank))
		stamp.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1))
		stamp.add_theme_constant_override("outline_size", 6)
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0.06, 0.07, 0.13, 0.92)
		ring.border_color = _rank_color(rank)
		ring.set_border_width_all(3)
		ring.set_corner_radius_all(int(d))
		stamp.add_theme_stylebox_override("normal", ring)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(stamp)

	_animate_later(parent, root, top, rect, palette, stamp, won)

## Replace "{score}" in `template` with a number that counts up from 0.
static func count_up(label: Label, template: String, score: int, duration: float = 0.7) -> void:
	if label == null:
		return
	if bool(GameState.get_setting("reduced_motion", false)) or score <= 0:
		label.text = template.replace("{score}", "%03d" % score)
		return
	label.text = template.replace("{score}", "000")
	var tw := label.create_tween()
	tw.tween_interval(0.25)
	var last := [-1]
	tw.tween_method(func(v: float):
		var n := int(round(v))
		label.text = template.replace("{score}", "%03d" % n)
		if n / 12 != last[0]:
			last[0] = n / 12
			Sfx.blip("tick"),
		0.0, float(score), duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

static func _animate_later(parent: Node, root: Control, top: ColorRect, rect: Rect2, palette: Array, stamp: Label, won: bool) -> void:
	await parent.get_tree().process_frame
	if not is_instance_valid(root):
		return
	var factor := top.size.x / maxf(1.0, rect.size.x - 16.0)
	if parent is CanvasItem:
		var dim := ColorRect.new()
		dim.name = "DebriefDim"
		dim.color = Color(0.02, 0.03, 0.07, 0.62)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := (parent as CanvasItem).get_viewport_rect().size
		var origin := (parent as CanvasItem).get_global_transform().affine_inverse() * Vector2.ZERO
		dim.position = origin
		dim.size = vp
		parent.add_child(dim)
		parent.move_child(dim, 0)
	var r := Rect2(rect.position * factor, rect.size * factor)
	var reduced := bool(GameState.get_setting("reduced_motion", false))
	var overlay := parent as Control
	if overlay != null and not reduced:
		overlay.pivot_offset = r.get_center()
		overlay.modulate.a = 0.0
		overlay.scale = Vector2(0.94, 0.94)
		overlay.position.y += 14.0 * factor
		var tw := overlay.create_tween().set_parallel(true)
		tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
		tw.tween_property(overlay, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(overlay, "position:y", overlay.position.y - 14.0 * factor, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", -6.0)

	if not reduced and won:
		_confetti(root, r, palette, factor)
	if stamp != null:
		if reduced:
			Sfx.play("stamp")
		else:
			stamp.pivot_offset = stamp.size * 0.5
			stamp.scale = Vector2(2.6, 2.6)
			stamp.modulate.a = 0.0
			stamp.rotation = -0.5
			var st := stamp.create_tween()
			st.tween_interval(0.95)
			st.tween_callback(func(): Sfx.play("stamp"))
			st.tween_property(stamp, "modulate:a", 1.0, 0.08)
			st.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			st.parallel().tween_property(stamp, "rotation", -0.12, 0.16)
			st.tween_callback(func():
				_shake(overlay if overlay != null else root, 6.0 * factor)
				if won and stamp.text in ["S", "A"]:
					Sfx.play("badge", -2.0))

static func _confetti(root: Control, r: Rect2, palette: Array, factor: float) -> void:
	var origin := r.position + Vector2(r.size.x * 0.5, 10.0 * factor)
	for i in range(24):
		var spark := ColorRect.new()
		spark.size = Vector2(5 + (i % 3) * 2, 5 + ((i + 1) % 3) * 2) * factor
		spark.position = origin
		spark.pivot_offset = spark.size * 0.5
		spark.color = palette[i % palette.size()]
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(spark)
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := r.size.x * (0.08 + 0.035 * float(i / 2)) * randf_range(0.8, 1.2)
		var peak := origin + Vector2(side * spread, (-24.0 - float(i % 5) * 12.0) * factor)
		var fall := peak + Vector2(side * 20.0 * factor, (80.0 + float(i % 4) * 26.0) * factor)
		var st := spark.create_tween()
		st.tween_interval(0.12 + 0.01 * i)
		st.tween_property(spark, "position", peak, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(spark, "rotation", side * 4.0, 1.0)
		st.tween_property(spark, "position", fall, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.parallel().tween_property(spark, "modulate:a", 0.0, 0.7)
		st.tween_callback(spark.queue_free)

static func _shake(node: Control, amount: float) -> void:
	if node == null:
		return
	var base := node.position
	var tw := node.create_tween()
	for i in range(5):
		var k := 1.0 - float(i) / 5.0
		tw.tween_property(node, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * k, 0.03)
	tw.tween_property(node, "position", base, 0.03)

static func _bar(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.position = pos
	bar.size = size
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

static func _rank_color(rank: String) -> Color:
	match rank:
		"S":
			return Color(1.0, 0.84, 0.30)
		"A":
			return Color(0.40, 0.95, 0.72)
		"B":
			return Color(0.50, 0.78, 1.0)
		"C":
			return Color(0.82, 0.70, 1.0)
	return Color(0.95, 0.55, 0.45)

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
