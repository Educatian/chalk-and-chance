extends Control
## Easy, guided learner sign-in: class code + your name + a password. First time in an
## open class auto-enrolls (sets your password); after that it signs you in. On success
## every lesson uploads under your name. "Play offline" skips it (local-only telemetry).

var _class_in: LineEdit
var _name_in: LineEdit
var _pw_in: LineEdit
var _status: Label
var _btn: Button

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(270, 70)
	box.size = Vector2(420, 400)
	add_child(box)

	var title := Label.new()
	title.text = "Chalk & Chance"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Sign in to save your progress and competencies."
	sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	box.add_child(sub)

	_class_in = _field(box, "Class code", "e.g. UA-CAT531-SUMMER26", false)
	_name_in = _field(box, "Your name", "First Last", false)
	_pw_in = _field(box, "Password", "choose / enter your password", true)
	_pw_in.text_submitted.connect(func(_t): _on_sign_in())

	_btn = Button.new()
	_btn.text = "Sign in / Join"
	_btn.custom_minimum_size = Vector2(0, 40)
	_btn.pressed.connect(_on_sign_in)
	box.add_child(_btn)

	var skip := Button.new()
	skip.text = "Skip  -  play as guest  >"
	skip.custom_minimum_size = Vector2(0, 36)
	skip.pressed.connect(_go_hub)
	box.add_child(skip)
	var skip_hint := Label.new()
	skip_hint.text = "(no class code / name / password needed to play)"
	skip_hint.add_theme_font_size_override("font_size", 11)
	skip_hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	box.add_child(skip_hint)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55))
	box.add_child(_status)

	Auth.login_ok.connect(_go_hub)
	Auth.login_failed.connect(func(m): _set_status(m, true))
	if not Auth.configured():
		_set_status("Login not set up yet — playing offline.", false)

func _field(parent: Node, label: String, placeholder: String, secret: bool) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	parent.add_child(l)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 34)
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
