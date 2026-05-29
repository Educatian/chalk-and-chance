extends Control
## Gym (boss) encounter: several students at once. Pick a TARGET student, then a move.
## Helping one student calms them but the others grow restless (orchestration under load).
## Resolve every student before your Composure runs out. Reuses persona win_moves + lines.
## See GAME_ROADMAP.md #13.

const UI_SCALE := 2.0
const WIN_U := 0.80
const MOVES := [
	["Elicit", "elicit"], ["Extend", "extend"], ["Revoice", "revoice"],
	["Tell", "tell"], ["Praise", "praise"], ["Redirect", "redirect"], ["Wait", "wait"],
]

var scenario: Dictionary = {}
var students: Array = []      # per-student runtime dicts
var sel: int = 0
var composure := 100.0
var order := 100.0
var _ready_ms := 0
var _over := false

var _layer: Control
var _title: Label
var _comp_fill: ColorRect
var _order_fill: ColorRect
var _dialogue: Label
var _coach: Label
var _highlight: ColorRect
var _buttons: Array = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_layer = Control.new()
	_layer.scale = Vector2(UI_SCALE, UI_SCALE)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

func setup(data: Dictionary) -> void:
	scenario = data.get("scenario", {})
	_load_students()
	_build_ui()
	_arm_turn()
	_refresh()

# --- data --------------------------------------------------------------------

func _load_students() -> void:
	var overrides: Dictionary = scenario.get("persona_overrides", {})
	for entry in scenario.get("roster", []):
		var pid: String = str(entry.get("id", ""))
		var base := _read_json("res://data/persona_library/%s.json" % pid)
		var ov: Dictionary = overrides.get(pid, {})
		students.append({
			"pid": pid,
			"name": str(entry.get("name", base.get("display_name", "Student"))),
			"u": 0.15, "resolved": false, "restless": 0.0,
			"win_moves": ov.get("win_moves", base.get("win_moves", ["elicit", "extend"])),
			"win_line": str(ov.get("win_line", base.get("win_line", "Oh, I get it now!"))),
			"target_label": str(ov.get("target_label", base.get("target_label", ""))),
		})

func _read_json(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				return d
	return {}

# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	_title = _label("GYM: %s" % str(scenario.get("title", "Capstone")), Vector2(10, 6), 11, Color(0.97, 0.93, 0.85))
	_title.size = Vector2(460, 14)

	_label("Composure", Vector2(10, 24), 8, Color(0.95, 0.8, 0.85))
	_comp_fill = _bar(Vector2(86, 26), Color(0.90, 0.45, 0.55))
	_label("Class Order", Vector2(10, 42), 8, Color(0.85, 0.9, 0.95))
	_order_fill = _bar(Vector2(86, 44), Color(0.35, 0.65, 0.95))

	# Student panels with select buttons + understanding/restless bars + portrait.
	var n := students.size()
	var pw := 460.0 / float(max(1, n))
	_highlight = ColorRect.new()
	_highlight.color = Color(0.98, 0.85, 0.35, 0.25)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_highlight)
	for i in range(n):
		var px := 10.0 + i * pw
		var py := 64.0
		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(px, py)
		btn.size = Vector2(pw - 6, 96)
		btn.pressed.connect(_select.bind(i))
		_layer.add_child(btn)
		students[i]["x"] = px
		students[i]["y"] = py
		students[i]["w"] = pw - 6

		var tex := _tex("res://assets/portraits/%s_neutral.png" % students[i]["pid"])
		if tex != null:
			# Sprite2D with explicit scale renders at a guaranteed, consistent size.
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = true
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var psc := 50.0 / float(tex.get_height())
			spr.scale = Vector2(psc, psc)
			spr.position = Vector2(px + (pw - 6) / 2.0, py + 27)
			_layer.add_child(spr)
		var nm := _label(students[i]["name"], Vector2(px, py + 56), 8, Color.WHITE)
		nm.size = Vector2(pw - 6, 12)
		students[i]["ufill"] = _bar_at(Vector2(px + 8, py + 72), pw - 22, Color(0.30, 0.80, 0.40))
		students[i]["rfill"] = _bar_at(Vector2(px + 8, py + 80), pw - 22, Color(0.90, 0.35, 0.30))

	# Dialogue + coach
	var dbg := ColorRect.new()
	dbg.position = Vector2(10, 172); dbg.size = Vector2(460, 30)
	dbg.color = Color(0.12, 0.15, 0.26); dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(dbg)
	_dialogue = _label("", Vector2(16, 174), 9, Color(0.96, 0.96, 0.92))
	_dialogue.size = Vector2(448, 26)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach = _label("Coach Vee: pick a student, then a move. Help one, but watch the others drift.", Vector2(16, 204), 8, Color(0.72, 0.92, 0.78))
	_coach.size = Vector2(448, 16)

	# Move menu
	var bw := 460.0 / MOVES.size()
	for i in range(MOVES.size()):
		var b := Button.new()
		b.text = MOVES[i][0]
		b.position = Vector2(10 + i * bw, 226)
		b.size = Vector2(bw - 3, 36)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(_on_move.bind(str(MOVES[i][1])))
		_layer.add_child(b)
		_buttons.append(b)

func _label(t: String, pos: Vector2, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t; l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l

func _bar(pos: Vector2, c: Color) -> ColorRect:
	return _bar_at(pos, 150.0, c)

func _bar_at(pos: Vector2, w: float, c: Color) -> ColorRect:
	var bgr := ColorRect.new()
	bgr.position = pos; bgr.size = Vector2(w, 6)
	bgr.color = Color(0, 0, 0, 0.5); bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bgr)
	var fill := ColorRect.new()
	fill.position = pos; fill.size = Vector2(w, 6)
	fill.color = c; fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_meta("w", w)
	_layer.add_child(fill)
	return fill

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	return null

# --- turn logic --------------------------------------------------------------

func _arm_turn() -> void:
	_ready_ms = Time.get_ticks_msec()

func _select(i: int) -> void:
	sel = i
	_refresh()

func _on_move(tag: String) -> void:
	if _over:
		return
	var s: Dictionary = students[sel]
	if s.get("resolved", false):
		_coach.text = "Coach Vee: %s is already with you. Turn to someone who needs you." % s["name"]
		return
	var wait_ms := Time.get_ticks_msec() - _ready_ms
	var wait_ok := wait_ms >= 3000
	var wm: Array = s.get("win_moves", [])
	var targets := false
	if tag == "wait":
		targets = ("wait" in wm) and wait_ok
	elif tag != "tell":
		targets = tag in wm

	# Effect on the targeted student.
	if targets:
		s["u"] = clampf(float(s["u"]) + 0.18, 0.0, 1.0)
		s["restless"] = maxf(0.0, float(s["restless"]) - 0.35)
		composure = clampf(composure + 1.0, 0.0, 100.0)
		_dialogue.text = "%s: \"...okay, that helps.\"" % s["name"]
		_coach.text = "Coach Vee: good move for %s." % s["name"]
	elif tag == "tell":
		s["restless"] = minf(1.0, float(s["restless"]) + 0.1)
		composure = clampf(composure - 4.0, 0.0, 100.0)
		_dialogue.text = "%s: \"Oh... okay, I guess.\"" % s["name"]
		_coach.text = "Coach Vee: telling took over %s's thinking." % s["name"]
	else:
		composure = clampf(composure - 2.0, 0.0, 100.0)
		_dialogue.text = "%s: \"...\"" % s["name"]
		_coach.text = "Coach Vee: that is not the move %s needs (try: %s)." % [s["name"], s.get("target_label", "")]

	# Resolve?
	if float(s["u"]) >= WIN_U and targets:
		s["resolved"] = true
		s["restless"] = 0.0
		_dialogue.text = "%s: \"%s\"" % [s["name"], s["win_line"]]

	# Everyone else drifts while you attend to one (orchestration cost).
	for j in range(students.size()):
		if j == sel or students[j].get("resolved", false):
			continue
		students[j]["restless"] = minf(1.0, float(students[j]["restless"]) + 0.12)
		if float(students[j]["restless"]) >= 1.0:
			order = clampf(order - 8.0, 0.0, 100.0)
			composure = clampf(composure - 3.0, 0.0, 100.0)
			students[j]["restless"] = 0.55

	_arm_turn()
	_refresh()
	_check_end()

func _check_end() -> void:
	var all_resolved := true
	for s in students:
		if not s.get("resolved", false):
			all_resolved = false
	if all_resolved:
		_finish(true)
	elif composure <= 0.0 or order <= 0.0:
		_finish(false)

func _finish(won: bool) -> void:
	_over = true
	for b in _buttons:
		b.disabled = true
	var resolved := 0
	for s in students:
		if s.get("resolved", false):
			resolved += 1
	if won:
		var badge := str(scenario.get("badge", ""))
		if badge != "":
			GameState.award_badge(badge)
		_coach.text = "Coach Vee: you held the whole room and reached every student. Capstone cleared!"
	else:
		_coach.text = "Coach Vee: the room got away from you (%d/%d reached). Circulate faster next time." % [resolved, students.size()]
	var t := get_tree().create_timer(3.2)
	await t.timeout
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

# --- view --------------------------------------------------------------------

func _refresh() -> void:
	_set_fill(_comp_fill, composure / 100.0)
	_set_fill(_order_fill, order / 100.0)
	for s in students:
		_set_fill(s["ufill"], float(s["u"]))
		_set_fill(s["rfill"], float(s["restless"]))
	if sel >= 0 and sel < students.size():
		var s2: Dictionary = students[sel]
		_highlight.position = Vector2(float(s2["x"]) - 2, float(s2["y"]) - 2)
		_highlight.size = Vector2(float(s2["w"]) + 4, 100)
		_title.text = "GYM: target = %s  (%s)" % [s2["name"], s2.get("target_label", "")]

func _set_fill(fill: ColorRect, frac: float) -> void:
	if fill == null:
		return
	var w: float = fill.get_meta("w", 150.0)
	fill.size = Vector2(w * clampf(frac, 0.0, 1.0), fill.size.y)
