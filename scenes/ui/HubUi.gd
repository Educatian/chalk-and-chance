extends RefCounted

static func add_hub_backdrop(parent: Node, vp: Vector2) -> void:
	var top_band := ColorRect.new()
	top_band.position = Vector2.ZERO
	top_band.size = Vector2(vp.x, 164)
	top_band.color = Color(0.07, 0.085, 0.16, 0.92)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_band)
	for x in range(0, int(vp.x), 32):
		var line := ColorRect.new()
		line.position = Vector2(x, 0)
		line.size = Vector2(1, vp.y)
		line.color = Color(0.55, 0.78, 0.95, 0.035)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
	for y in range(0, int(vp.y) + 1, 32):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(vp.x, 1)
		line.color = Color(0.55, 0.78, 0.95, 0.028)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
	var rule := ColorRect.new()
	rule.position = Vector2(42, 160)
	rule.size = Vector2(vp.x - 84, 2)
	rule.color = Color(0.98, 0.86, 0.42, 0.58)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func plate_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

static func apply_button_style(button: Button, accent: bool = false) -> void:
	var base := Color(0.105, 0.13, 0.24, 0.98)
	var border := Color(0.24, 0.33, 0.50, 0.90)
	if accent:
		base = Color(0.16, 0.17, 0.23, 0.98)
		border = Color(0.98, 0.80, 0.28, 0.96)
	button.add_theme_stylebox_override("normal", button_style(base, border))
	button.add_theme_stylebox_override("hover", button_style(base.lightened(0.10), border.lightened(0.18)))
	button.add_theme_stylebox_override("pressed", button_style(base.darkened(0.10), Color(0.30, 0.92, 0.86, 0.98)))
	button.add_theme_stylebox_override("focus", button_style(base.lightened(0.06), Color(0.30, 0.92, 0.86, 1.0)))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.055, 0.065, 0.10, 0.92), Color(0.18, 0.22, 0.32, 0.82)))
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.96))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.54, 0.66))

static func card_style(is_next: bool, locked: bool, earned: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.095, 0.115, 0.20, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.98, 0.86, 0.42, 0.86) if is_next else Color(0.24, 0.34, 0.48, 0.84)
	if locked:
		style.bg_color = Color(0.075, 0.082, 0.12, 0.98)
		style.border_color = Color(0.34, 0.38, 0.48, 0.82)
	if earned:
		style.border_color = Color(0.38, 0.72, 0.48, 0.78)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

static func add_report_chrome(parent: Node, origin: Vector2 = Vector2(108, 54), size: Vector2 = Vector2(744, 426)) -> void:
	# Clean frame: one gold header rule, one teal accent rail, a soft drop shadow.
	var shadow := ColorRect.new()
	shadow.position = origin + Vector2(6, 8)
	shadow.size = size
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)
	if parent.get_child_count() > 2:
		parent.move_child(shadow, 1) # behind the panel, above the dim

	var header := ColorRect.new()
	header.position = origin
	header.size = Vector2(size.x, 4)
	header.color = Color(0.98, 0.82, 0.28, 0.95)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)

	var left := ColorRect.new()
	left.position = origin + Vector2(0, 4)
	left.size = Vector2(3, size.y - 8)
	left.color = Color(0.30, 0.92, 0.86, 0.55)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(left)

## Modal entrance: fade the dim + scale the content up from 96%. Skipped for reduced motion.
static func pop_in(overlay: Control, duration: float = 0.18) -> void:
	if overlay == null or bool(GameState.get_setting("reduced_motion", false)):
		return
	var vp := overlay.get_viewport_rect().size if overlay.is_inside_tree() else Vector2(960, 540)
	overlay.pivot_offset = vp * 0.5
	overlay.modulate.a = 0.0
	overlay.scale = Vector2(0.96, 0.96)
	var tw := overlay.create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, duration * 0.8)
	tw.tween_property(overlay, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("open")
