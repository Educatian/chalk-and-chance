extends Control
const UiText = preload("res://scripts/UiText.gd")
const UiKit = preload("res://scripts/UiKit.gd")
const BrandLogo = preload("res://scripts/BrandLogo.gd")
## Landing and learner sign-in. The demo path stays one click, while class sign-in remains
## available for saved course progress.

var _class_in: LineEdit
var _name_in: LineEdit
var _pw_in: LineEdit
var _status: Label
var _btn: Button
var _class_box: VBoxContainer
var _class_label: Label
var _logo: Control
var _tagline: Label
var _menu: VBoxContainer

const COURSE_CODES := {
	"UA-CAT531-SUMMER26": "CAT531",
	"UA-CAT100-SUMMER26": "CAT100",
}

func _ready() -> void:
	var course_code := _web_course_code()
	var is_course := COURSE_CODES.has(course_code)
	var course_label: String = str(COURSE_CODES.get(course_code, ""))
	var vp := get_viewport_rect().size
	_add_landing_background(vp)
	_add_language_switch(vp)

	# Left column over the key art's dark side: logo, tagline, then the menu.
	var col_x := 48.0 if vp.x >= 760.0 else 24.0
	var col_w := minf(400.0, vp.x - col_x * 2.0)
	_logo = BrandLogo.new(3 if vp.x >= 760.0 else 2)
	_logo.position = Vector2(col_x - 6.0, 34.0)
	add_child(_logo)

	_tagline = Label.new()
	_tagline.text = tr("Practice the moments you can't plan.")
	_tagline.position = Vector2(col_x, 34.0 + 96.0 + 10.0)
	_tagline.add_theme_font_size_override("font_size", UiText.fs(18))
	_tagline.add_theme_color_override("font_color", Color("f2eedd"))
	add_child(_tagline)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(col_x, 196.0)
	_menu.custom_minimum_size = Vector2(col_w, 0)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)

	var demo := Button.new()
	demo.text = "Play"
	demo.visible = not is_course
	if OS.has_feature("web") and TTSClient.voice_gate_required and not TTSClient.voice_gate_unlocked:
		_add_voice_off_icon(vp)
	demo.custom_minimum_size = Vector2(col_w, 44)
	demo.add_theme_font_size_override("font_size", UiText.fs(18))
	_apply_button_style(demo, true)
	demo.pressed.connect(_go_hub)
	_menu.add_child(demo)

	var open_form := Button.new()
	open_form.text = "Sign in with your class"
	open_form.custom_minimum_size = Vector2(col_w, 38)
	open_form.visible = not is_course
	_apply_button_style(open_form, false)
	_menu.add_child(open_form)

	# The class form folds away until asked for (course links open it straight away).
	_class_box = VBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 6)
	_class_box.visible = is_course
	_menu.add_child(_class_box)
	open_form.pressed.connect(func():
		_class_box.visible = not _class_box.visible
		if _class_box.visible:
			(_class_in if _class_in.visible else _name_in).grab_focus())

	if is_course:
		var course_head := Label.new()
		course_head.text = "%s sign in" % course_label
		course_head.add_theme_font_size_override("font_size", UiText.fs(18))
		course_head.add_theme_color_override("font_color", Color("ffd34e"))
		_class_box.add_child(course_head)
	_class_in = _field(_class_box, "Class code", "e.g. UA-CAT531-SUMMER26", false)
	_name_in = _field(_class_box, "Your name", "First Last", false)
	_pw_in = _field(_class_box, "Course passcode", "enter course passcode", true)
	if course_code != "":
		_class_in.text = course_code
	if is_course:
		_class_label.visible = false
		_class_in.visible = false
	_pw_in.text_submitted.connect(func(_t): _on_sign_in())

	_btn = Button.new()
	_btn.text = "Sign in / Join"
	if is_course:
		_btn.text = "Sign in to %s" % course_label
	_btn.custom_minimum_size = Vector2(0, 36)
	_apply_button_style(_btn, false)
	_btn.pressed.connect(_on_sign_in)
	_class_box.add_child(_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(col_w, 0)
	_status.add_theme_font_size_override("font_size", UiText.fs(12))
	_status.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55))
	_menu.add_child(_status)

	Auth.login_ok.connect(_go_hub)
	Auth.login_failed.connect(func(m): _set_status(m, true); if _btn != null: _btn.disabled = false)
	if is_course:
		_set_status("Enter your name and the course passcode.", false)

	# Intro: the ring fills, then the tagline and menu fade in. Any press skips it.
	_tagline.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_logo.animate(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_tagline, "modulate:a", 1.0, 0.25 if Juice.motion_ok() else 0.0)
		tw.tween_property(_menu, "modulate:a", 1.0, 0.25 if Juice.motion_ok() else 0.0)
		# Keyboard/gamepad players start on the main action; course builds start on the name field.
		if demo.visible:
			demo.grab_focus()
		else:
			_name_in.grab_focus())

## Voice is off in the public build: a small speaker-off icon in the corner says so.
func _add_voice_off_icon(vp: Vector2) -> void:
	var ic := TextureRect.new()
	ic.texture = load("res://assets/brand/ui/voice_off.png")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.tooltip_text = "Voice is off"
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(ic)
	ic.size = Vector2(24, 24)
	ic.position = Vector2(vp.x - 40, 14)

## Language switch on the first screen, named in the language it switches to.
func _add_language_switch(vp: Vector2) -> void:
	var b := Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = "English" if str(GameState.get_setting("language", "en")) == "ko" else "한국어"
	b.add_theme_font_size_override("font_size", UiText.fs(12))
	UiKit.style_board_button(b, UiText.fs(12))
	b.pressed.connect(func():
		GameState.set_language("en" if str(GameState.get_setting("language", "en")) == "ko" else "ko")
		SceneRouter.change_scene("res://scenes/ui/Login.tscn"))
	add_child(b)
	b.size = Vector2(84, 28)
	b.position = Vector2(vp.x - 136, 12)

func _input(event: InputEvent) -> void:
	if _logo != null and not _logo.done and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton) and event.is_pressed():
		_logo.skip()
		get_viewport().set_input_as_handled()

func _add_landing_background(vp: Vector2) -> void:
	var art := TextureRect.new()
	art.texture = load("res://assets/brand/keyart/key_art_960x540.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = vp   # the root has no size of its own under the scene stack
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	# Wider-than-16:9 screens: fill the left with the art's own navy so the column stays clean.
	var bg := ColorRect.new()
	bg.color = Color("24304f")
	bg.size = vp
	add_child(bg)
	move_child(bg, 0)

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
	# v2 kit: the primary action is a paper button, the rest chalkboard buttons.
	if primary:
		UiKit.style_button(btn, btn.get_theme_font_size("font_size"))
	else:
		UiKit.style_board_button(btn)

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
	if label == "Class code":
		_class_label = l
	return e

func _web_course_code() -> String:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var raw := str(JavaScriptBridge.eval("(() => { const q = new URLSearchParams(window.location.search); const h = new URLSearchParams(window.location.hash.slice(1)); const flag = (k) => q.get(k) === '1' || h.get(k) === '1'; return q.get('class_code') || h.get('class_code') || (flag('cat531') ? 'UA-CAT531-SUMMER26' : '') || (flag('cat100') ? 'UA-CAT100-SUMMER26' : ''); })()", true)).strip_edges()
	var code := raw.to_upper()
	if COURSE_CODES.has(code):
		return code
	return ""

func _on_sign_in() -> void:
	if not Auth.configured():
		_go_hub()
		return
	if _class_in.text.strip_edges() == "" or _name_in.text.strip_edges() == "" or _pw_in.text == "":
		if COURSE_CODES.has(_class_in.text.strip_edges()):
			_set_status("Enter your name and course passcode.", true)
		else:
			_set_status("Enter your class code, name, and passcode.", true)
		return
	_btn.disabled = true
	_set_status("Signing in...", false)
	Auth.login(_class_in.text, _name_in.text, _pw_in.text)

func _set_status(msg: String, err: bool) -> void:
	if _status != null:
		_status.text = msg
		_status.add_theme_color_override("font_color",
			Color(0.95, 0.6, 0.55) if err else Color(0.7, 0.9, 0.7))

func _go_hub() -> void:
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")
