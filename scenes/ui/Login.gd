extends Control
## Landing and learner sign-in. The demo path stays one click, while class sign-in remains
## available for saved course progress.

var _class_in: LineEdit
var _name_in: LineEdit
var _pw_in: LineEdit
var _status: Label
var _btn: Button
var _class_box: VBoxContainer

func _ready() -> void:
	var vp := get_viewport_rect().size
	_add_landing_background(vp)

	var logo_x := 48.0
	var logo_y := 44.0
	if vp.x < 760.0:
		logo_x = 30.0
		logo_y = 24.0

	var mark := Panel.new()
	mark.position = Vector2(logo_x, logo_y)
	mark.size = Vector2(74, 58)
	mark.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.18, 0.16, 0.86), Color(0.96, 0.76, 0.36, 0.92), 4))
	add_child(mark)

	var mark_text := Label.new()
	mark_text.text = "C&C"
	mark_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark_text.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	mark_text.add_theme_font_size_override("font_size", 14)
	mark_text.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	mark.add_child(mark_text)

	var title := Label.new()
	title.text = "CHALK & CHANCE"
	title.position = Vector2(logo_x, logo_y + 72)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.95))
	title.add_theme_constant_override("outline_size", 7)
	add_child(title)

	var sub := Label.new()
	sub.text = "Teach. Listen. Adapt."
	sub.position = Vector2(logo_x + 4, logo_y + 122)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.85, 0.94, 0.92))
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.9))
	sub.add_theme_constant_override("outline_size", 4)
	add_child(sub)

	var panel_w := minf(390.0, vp.x - 56.0)
	var panel_h := minf(510.0, vp.y - 32.0)
	var panel_x := vp.x - panel_w - 46.0
	if vp.x < 760.0:
		panel_x = (vp.x - panel_w) * 0.5
	var panel_y := maxf(18.0, (vp.y - panel_h) * 0.5)

	_add_landing_characters(vp, panel_x)

	var panel := Panel.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.08, 0.11, 0.83), Color(0.96, 0.86, 0.55, 0.34), 3))
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(panel_x + 22, panel_y + 20)
	scroll.size = Vector2(panel_w - 44, panel_h - 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(panel_w - 44, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var demo := Button.new()
	demo.text = "Play demo"
	if OS.has_feature("web") and TTSClient.voice_gate_required and not TTSClient.voice_gate_unlocked:
		demo.text = "Play demo (voice off)"
	demo.custom_minimum_size = Vector2(0, 42)
	demo.add_theme_font_size_override("font_size", 18)
	_apply_button_style(demo, true)
	demo.pressed.connect(_go_hub)
	box.add_child(demo)

	var demo_hint := Label.new()
	demo_hint.text = "Demo path: choose a mission, rehearse teacher moves, then review evidence."
	demo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_hint.add_theme_font_size_override("font_size", 12)
	demo_hint.add_theme_color_override("font_color", Color(0.76, 0.86, 0.88))
	box.add_child(demo_hint)

	var divider := Label.new()
	divider.text = "Class sign in"
	divider.add_theme_font_size_override("font_size", 16)
	divider.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	box.add_child(divider)

	var signin_hint := Label.new()
	signin_hint.text = "Class sign in keeps progress tied to a course account."
	signin_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	signin_hint.add_theme_font_size_override("font_size", 11)
	signin_hint.add_theme_color_override("font_color", Color(0.70, 0.78, 0.84))
	box.add_child(signin_hint)

	_class_box = VBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 8)
	box.add_child(_class_box)

	_class_in = _field(_class_box, "Class code", "e.g. UA-CAT531-SUMMER26", false)
	_name_in = _field(_class_box, "Your name", "First Last", false)
	_pw_in = _field(_class_box, "Password", "choose / enter your password", true)
	_pw_in.text_submitted.connect(func(_t): _on_sign_in())

	_btn = Button.new()
	_btn.text = "Sign in / Join"
	_btn.custom_minimum_size = Vector2(0, 36)
	_apply_button_style(_btn, false)
	_btn.pressed.connect(_on_sign_in)
	_class_box.add_child(_btn)

	var skip := Button.new()
	skip.text = "Skip sign in"
	skip.custom_minimum_size = Vector2(0, 34)
	_apply_button_style(skip, false)
	skip.pressed.connect(_go_hub)
	_class_box.add_child(skip)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55))
	box.add_child(_status)

	Auth.login_ok.connect(_go_hub)
	Auth.login_failed.connect(func(m): _set_status(m, true))
	if not Auth.configured():
		_set_status("Offline mode is ready.", false)
	elif OS.has_feature("web") and TTSClient.voice_gate_required and not TTSClient.voice_gate_unlocked:
		_set_status("Public demo ready. Voice is off to prevent ElevenLabs overuse.", false)

func _add_landing_background(vp: Vector2) -> void:
	var art := TextureRect.new()
	art.texture = load("res://ui/art/landing_classroom.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(art)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var left_readability := ColorRect.new()
	left_readability.color = Color(0.01, 0.05, 0.05, 0.36)
	left_readability.position = Vector2.ZERO
	left_readability.size = Vector2(vp.x * 0.62, vp.y)
	add_child(left_readability)

func _add_landing_characters(vp: Vector2, panel_x: float) -> void:
	if vp.x < 760.0:
		return
	var texture: Texture2D = load("res://ui/art/landing_characters.png")
	if texture == null:
		return
	var chars := Sprite2D.new()
	chars.texture = texture
	var w := clampf(panel_x - 190.0, 280.0, 330.0)
	var h := w * float(texture.get_height()) / float(texture.get_width())
	var s := w / float(texture.get_width())
	chars.position = Vector2(28.0 + w * 0.5, vp.y - h - 2.0 + h * 0.5)
	chars.scale = Vector2(s, s)
	add_child(chars)

func _panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	return style

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _apply_button_style(btn: Button, primary: bool) -> void:
	var base := _button_style(Color(0.17, 0.28, 0.24, 0.96) if primary else Color(0.08, 0.15, 0.18, 0.94), Color(0.96, 0.80, 0.38, 0.92) if primary else Color(0.48, 0.68, 0.70, 0.58))
	var hover := _button_style(Color(0.23, 0.38, 0.31, 0.98) if primary else Color(0.12, 0.22, 0.26, 0.96), Color(1.0, 0.88, 0.50, 1.0) if primary else Color(0.68, 0.86, 0.86, 0.78))
	var pressed := _button_style(Color(0.10, 0.20, 0.17, 1.0), Color(0.96, 0.70, 0.28, 1.0))
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.76) if primary else Color(0.86, 0.94, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _field(parent: Node, label: String, placeholder: String, secret: bool) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	parent.add_child(l)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 30)
	parent.add_child(e)
	return e

func _on_sign_in() -> void:
	if not Auth.configured():
		_go_hub()
		return
	if _class_in.text.strip_edges() == "" or _name_in.text.strip_edges() == "" or _pw_in.text == "":
		_set_status("Enter class code, name, and password.", true)
		return
	_btn.disabled = true
	_set_status("Signing in...", false)
	Auth.login(_class_in.text, _name_in.text, _pw_in.text)

func _set_status(msg: String, err: bool) -> void:
	if _status != null:
		_status.text = msg
		_status.add_theme_color_override("font_color",
			Color(0.95, 0.6, 0.55) if err else Color(0.7, 0.9, 0.7))
	if _btn != null:
		_btn.disabled = false

func _go_hub() -> void:
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")
