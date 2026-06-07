extends RefCounted

static func apply(button: Button, font_size: int = 7, accent: bool = false) -> void:
	var base := Color(0.105, 0.13, 0.24, 0.98)
	var border := Color(0.22, 0.29, 0.46, 0.92)
	if accent:
		base = Color(0.14, 0.16, 0.24, 0.98)
		border = Color(0.98, 0.80, 0.28, 0.96)
	button.add_theme_stylebox_override("normal", _box(base, border))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.10), border.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.08), Color(0.30, 0.92, 0.86, 0.98)))
	button.add_theme_stylebox_override("focus", _box(base.lightened(0.05), Color(0.30, 0.92, 0.86, 1.0)))
	button.add_theme_stylebox_override("disabled", _box(Color(0.06, 0.07, 0.11, 0.92), Color(0.18, 0.22, 0.32, 0.82)))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("minimum_width", 0)
	button.add_theme_constant_override("minimum_height", 0)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.96))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.54, 0.66))

static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
