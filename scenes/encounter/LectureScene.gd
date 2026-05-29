extends Control
## Lecture (direct-instruction) mode: the rhythm of PRESENT vs CHECK-FOR-UNDERSTANDING.
## Students REACT (portrait affect swap + emote bubble + bob) to your pacing, questions, and
## whether they follow. See LECTURE_DESIGN.md.

const UI_SCALE := 2.0
const MOVES := [
	["Present", "present"], ["Question", "ask"], ["Wait", "wait"],
	["Re-explain", "reexplain"], ["Class Check", "poll"],
]

var scenario: Dictionary = {}
var students: Array = []          # {pid,name,comp,called,reacted, spr, emote, x,y}
var sel := 0
var progress := 0.0
var comprehension := 35.0
var attention := 100.0
var composure := 100.0
var consec_present := 0
var _ready_ms := 0
var _over := false

var _layer: Control
var _title: Label
var _bars := {}            # key -> ColorRect fill
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
	for entry in scenario.get("roster", []):
		students.append({"pid": str(entry.get("id", "")), "name": str(entry.get("name", "?")),
			"comp": 0.3, "called": false})
	_build_ui()
	_arm_turn()
	_refresh()

# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	_title = _label("LECTURE: %s" % str(scenario.get("title", "Lesson")), Vector2(10, 6), 11, Color(0.97, 0.93, 0.85))
	_title.size = Vector2(460, 14)

	_make_bar("progress", "Lesson Progress", 26, Color(0.30, 0.80, 0.40))
	_make_bar("comp", "Comprehension", 42, Color(0.35, 0.65, 0.95))
	_make_bar("attn", "Attention", 58, Color(0.95, 0.78, 0.30))
	_make_bar("composure", "Composure", 74, Color(0.90, 0.45, 0.55))

	# Student row, reactive portraits.
	var n := students.size()
	var slot := 460.0 / float(max(1, n))
	_highlight = ColorRect.new()
	_highlight.color = Color(0.98, 0.85, 0.35, 0.22)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_highlight)
	var psize := minf(54.0, slot - 6.0)
	for i in range(n):
		var cx := 10.0 + i * slot + slot / 2.0
		var py := 100.0
		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(10.0 + i * slot, py - 4)
		btn.size = Vector2(slot - 2, psize + 28)
		btn.pressed.connect(_select.bind(i))
		_layer.add_child(btn)
		students[i]["x"] = 10.0 + i * slot
		students[i]["y"] = py - 4
		students[i]["slot"] = slot
		var spr := Sprite2D.new()
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex := _portrait(students[i]["pid"], "neutral")
		if tex != null:
			spr.texture = tex
			spr.scale = Vector2(psize / float(tex.get_height()), psize / float(tex.get_height()))
		spr.position = Vector2(cx, py + psize / 2.0)
		_layer.add_child(spr)
		students[i]["spr"] = spr
		var emo := Sprite2D.new()
		emo.centered = true
		emo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		emo.visible = false
		emo.position = Vector2(cx + psize * 0.32, py)
		_layer.add_child(emo)
		students[i]["emote"] = emo
		var nm := _label(students[i]["name"], Vector2(10.0 + i * slot, py + psize + 2), 8, Color.WHITE)
		nm.size = Vector2(slot - 2, 12)
		nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		nm.add_theme_constant_override("outline_size", 4)

	_dialogue = _label("", Vector2(12, 176), 9, Color(0.96, 0.96, 0.92))
	_dialogue.size = Vector2(456, 16)
	_coach = _label("Coach Vee: present a little, then check. Spread your questions across the room.", Vector2(12, 196), 8, Color(0.72, 0.92, 0.78))
	_coach.size = Vector2(456, 24)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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

func _make_bar(key: String, name_txt: String, y: float, c: Color) -> void:
	if name_txt != "":
		_label(name_txt, Vector2(10, y - 2), 8, Color(0.85, 0.88, 0.95))
	var bgr := ColorRect.new()
	bgr.position = Vector2(120, y); bgr.size = Vector2(150, 11)
	bgr.color = Color(0, 0, 0, 0.5); bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bgr)
	var fill := ColorRect.new()
	fill.position = Vector2(120, y); fill.size = Vector2(150, 11)
	fill.color = c; fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(fill)
	_bars[key] = fill

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	return null

## Portrait for an affect, with a fallback chain (some students only have 3 affects).
func _portrait(pid: String, affect: String) -> Texture2D:
	for a in [affect, "thinking", "neutral", "excited"]:
		var t := _tex("res://assets/portraits/%s_%s.png" % [pid, a])
		if t != null:
			return t
	return null

# --- reactions ---------------------------------------------------------------

func _react(i: int, affect: String, emote_key: String) -> void:
	var s: Dictionary = students[i]
	var spr: Sprite2D = s.get("spr")
	if spr != null:
		var t := _portrait(s["pid"], affect)
		if t != null:
			spr.texture = t
		var y0: float = spr.position.y
		var tw := create_tween()
		tw.tween_property(spr, "position:y", y0 - 4.0, 0.12)
		tw.tween_property(spr, "position:y", y0, 0.18)
	var emo: Sprite2D = s.get("emote")
	if emo != null:
		if emote_key == "":
			emo.visible = false
		else:
			var et := _tex("res://assets/ui/emote_%s.png" % emote_key)
			if et != null:
				emo.texture = et
				emo.scale = Vector2(18.0 / float(et.get_width()), 18.0 / float(et.get_width()))
				emo.visible = true

# --- turn logic --------------------------------------------------------------

func _arm_turn() -> void:
	_ready_ms = Time.get_ticks_msec()

func _select(i: int) -> void:
	sel = i
	_refresh()

func _on_move(tag: String) -> void:
	if _over:
		return
	var wait_ms := Time.get_ticks_msec() - _ready_ms
	var wait_ok := wait_ms >= 3000
	var gap := progress - comprehension
	match tag:
		"present":
			progress = clampf(progress + 12.0, 0.0, 100.0)
			consec_present += 1
			attention = clampf(attention - (5.0 + 4.0 * float(consec_present)), 0.0, 100.0)
			_dialogue.text = "You present the next part of the lesson."
			if gap > 28.0:
				attention = clampf(attention - 8.0, 0.0, 100.0)
				composure = clampf(composure - 3.0, 0.0, 100.0)
				_coach.text = "Coach Vee: you're getting ahead of them. Stop and check."
				_react_many("confused", "question", 3)
			elif consec_present >= 3:
				_coach.text = "Coach Vee: that's a lot of talking. They're tuning out, ask a question."
				_react_many("withdrawn", "dots", 3)
			else:
				_coach.text = "Coach Vee: good chunk. Check in before moving on."
				_react_many("neutral", "dots", 2)
		"ask":
			consec_present = 0
			attention = clampf(attention + 14.0, 0.0, 100.0)
			var s: Dictionary = students[sel]
			if s.get("called", false):
				comprehension = clampf(comprehension + 2.0, 0.0, 100.0)
				_coach.text = "Coach Vee: you've already heard from %s. Spread it to the back rows." % s["name"]
			else:
				s["called"] = true
				var bonus := 0.0
				if wait_ok:
					bonus = 4.0
				comprehension = clampf(comprehension + 6.0 + bonus, 0.0, 100.0)
				if gap > 25.0:
					_dialogue.text = "%s: \"Wait... I'm not sure I followed that part.\"" % s["name"]
					_coach.text = "Coach Vee: %s is behind. Re-explain before pressing on." % s["name"]
					_react(sel, "confused", "question")
				else:
					_dialogue.text = "%s answers, and it shows they're with you." % s["name"]
					_coach.text = "Coach Vee: nice check%s." % (" (good wait time)" if wait_ok else "")
					_react(sel, "excited", "exclaim")
		"wait":
			attention = clampf(attention + 3.0, 0.0, 100.0)
			_dialogue.text = "You pause and give them a few seconds."
			_coach.text = "Coach Vee: wait time lets more of them think. Now pose a question."
		"reexplain":
			consec_present = 0
			comprehension = clampf(comprehension + 12.0, 0.0, 100.0)
			attention = clampf(attention + 6.0, 0.0, 100.0)
			composure = clampf(composure + 2.0, 0.0, 100.0)
			_dialogue.text = "You re-explain the tricky step a different way."
			_coach.text = "Coach Vee: closing the gap. That's responsive teaching."
			_react_many("excited", "exclaim", 3)
		"poll":
			consec_present = 0
			comprehension = clampf(comprehension + 16.0, 0.0, 100.0)
			attention = clampf(attention + 20.0, 0.0, 100.0)
			_dialogue.text = "Whole-class check: everyone shows their answer."
			_coach.text = "Coach Vee: a whole-class check holds everyone accountable at once."
			_react_many("thinking", "exclaim", students.size())
	_arm_turn()
	_refresh()
	_check_end()

func _react_many(affect: String, emote_key: String, count: int) -> void:
	var done := 0
	for i in range(students.size()):
		if done >= count:
			break
		_react(i, affect, emote_key)
		done += 1

func _check_end() -> void:
	if progress >= 100.0:
		_finish(comprehension >= 60.0 and attention >= 25.0)
	elif attention <= 0.0 or composure <= 0.0:
		_finish(false)

func _finish(won: bool) -> void:
	_over = true
	for b in _buttons:
		b.disabled = true
	if won:
		var badge := str(scenario.get("badge", ""))
		if badge != "":
			GameState.award_badge(badge)
		_coach.text = "Coach Vee: you delivered the lesson AND kept them with you. Comprehension %d%%. Well paced!" % int(comprehension)
		for i in range(students.size()):
			_react(i, "excited", "exclaim")
	else:
		if attention <= 0.0:
			_coach.text = "Coach Vee: you lost the room. Present in smaller chunks and check more often."
		else:
			_coach.text = "Coach Vee: the lesson ended but comprehension was low (%d%%). Check understanding as you go." % int(comprehension)
	var t := get_tree().create_timer(3.4)
	await t.timeout
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

# --- view --------------------------------------------------------------------

func _refresh() -> void:
	_set_fill("progress", progress / 100.0)
	_set_fill("comp", comprehension / 100.0)
	_set_fill("attn", attention / 100.0)
	_set_fill("composure", composure / 100.0)
	if sel >= 0 and sel < students.size():
		var s: Dictionary = students[sel]
		_highlight.position = Vector2(float(s["x"]), float(s["y"]))
		_highlight.size = Vector2(float(s["slot"]) - 2, 78)
		_title.text = "LECTURE: %s   (ask -> %s)" % [str(scenario.get("title", "Lesson")), s["name"]]

func _set_fill(key: String, frac: float) -> void:
	var fill: ColorRect = _bars.get(key, null)
	if fill != null:
		fill.size = Vector2(150.0 * clampf(frac, 0.0, 1.0), 11)
