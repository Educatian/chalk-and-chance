extends RefCounted
const UiKit = preload("res://scripts/UiKit.gd")

static func apply(button: Button, font_size: int = 7, _accent: bool = false) -> void:
	# v2 kit: every compact move/item button uses the paper button face + pixel face.
	UiKit.style_button(button, font_size, 2)
	button.clip_text = true

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
