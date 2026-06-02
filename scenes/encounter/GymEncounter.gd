extends Control
## Gym (boss) encounter: several students at once. Pick a TARGET student, then a move.
## Helping one student calms them but the others grow restless (orchestration under load).
## Resolve every student before your Composure runs out. Reuses persona win_moves + lines.
## See GAME_ROADMAP.md #13.

const Art = preload("res://scripts/Art.gd")
const PixelUi = preload("res://scripts/PixelUi.gd")
const UI_SCALE := 2.0
const WIN_U := 0.80
const MOVES := [
	["Elicit", "elicit"], ["Extend", "extend"], ["Revoice", "revoice"],
	["Tell", "tell"], ["Praise", "praise"], ["Redir.", "redirect"], ["Wait", "wait"],
]

var scenario: Dictionary = {}
var students: Array = []      # per-student runtime dicts
var sel: int = 0
var composure := 100.0
var order := 100.0
var _ready_ms := 0
var _over := false
var _llm_busy := false
var _turns := 0
var _dialogue_tail: Array = []
var _move_history: Array = []
var _next_input_mode := "menu"
var _next_free_text := ""
var _last_turn_payload: Dictionary = {}
var _last_targets := false

var _http: HTTPRequest
var _layer: Control
var _backdrop: TextureRect
var _title: Label
var _comp_fill: ColorRect
var _order_fill: ColorRect
var _dialogue: Label
var _coach: Label
var _result: Label
var _highlight: ColorRect
var _buttons: Array = []
var _text_input: LineEdit = null
var _send_btn: Button = null
var _mic_btn: Button = null
var _type_toggle: Button = null
var _type_mode := false
var _item_buttons: Array = []
var _wait_item_ready := false
var _practice_goal_active := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 16.0
	add_child(_http)
	_http.request_completed.connect(_on_llm_reply)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.modulate = Color(1, 1, 1, 0.15)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	add_child(_backdrop)
	_layer = Control.new()
	_layer.scale = Vector2.ONE
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

func setup(data: Dictionary) -> void:
	scenario = data.get("scenario", {})
	composure = GameState.max_composure()
	_refresh_backdrop()
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
			"opening_line": str(ov.get("opening_line", base.get("opening_line", ""))),
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

func _refresh_backdrop() -> void:
	if _backdrop == null:
		return
	var tex := Art.tex(Art.scenario_backdrop_path(scenario, str(Game.current_scenario_id), false))
	_backdrop.texture = tex
	_backdrop.visible = tex != null

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
	var dialogue_box := Rect2(Vector2(10, 162), Vector2(460, 42))
	var dialogue_text := Rect2(Vector2(18, 168), Vector2(444, 24))
	dbg.name = "DialogueBubble"
	dbg.position = dialogue_box.position; dbg.size = dialogue_box.size
	dbg.color = Color(0.12, 0.15, 0.26); dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(dbg)
	_dialogue = _label("", dialogue_text.position, 9, Color(0.96, 0.96, 0.92))
	_dialogue.name = "DialogueText"
	_dialogue.size = dialogue_text.size
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.set_meta("qa_container_rect", dialogue_box)
	_dialogue.set_meta("qa_text_rect", dialogue_text)
	_dialogue.set_meta("qa_min_padding", 6.0)
	_result = _label("Current target: pick the highlighted student, then choose the move that fits their need.", Vector2(16, 204), 7, Color(0.96, 0.86, 0.50))
	_result.size = Vector2(448, 10)
	_coach = _label("Coach Vee: pick a student, then a move. Help one, but watch the others drift.", Vector2(16, 210), 7, Color(0.72, 0.92, 0.78))
	_coach.size = Vector2(448, 12)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Move menu
	var button_widths := [55.0, 72.0, 78.0, 52.0, 66.0, 64.0, 54.0]
	var x := 10.0
	for i in range(MOVES.size()):
		var b := Button.new()
		b.text = MOVES[i][0]
		b.position = Vector2(x, 230)
		b.size = Vector2(button_widths[i], 32)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 7)
		b.pressed.connect(_on_move.bind(str(MOVES[i][1])))
		_layer.add_child(b)
		_buttons.append(b)
		x += button_widths[i] + 3.0

	_text_input = LineEdit.new()
	_text_input.position = Vector2(10, 230)
	_text_input.size = Vector2(300, 32)
	_text_input.placeholder_text = "Type what you would say to the selected student."
	_text_input.add_theme_font_size_override("font_size", 8)
	_text_input.visible = false
	_text_input.text_submitted.connect(func(_t): _on_type_submit())
	_layer.add_child(_text_input)

	_mic_btn = Button.new()
	_mic_btn.text = "Mic"
	_mic_btn.position = Vector2(314, 230)
	_mic_btn.size = Vector2(46, 32)
	_mic_btn.add_theme_font_size_override("font_size", 7)
	_mic_btn.visible = false
	_mic_btn.disabled = not VoiceInput.is_supported()
	_mic_btn.tooltip_text = "Speak teacher talk" if VoiceInput.is_supported() else "Voice input is not supported in this browser."
	_mic_btn.pressed.connect(_start_voice_input)
	_layer.add_child(_mic_btn)

	_send_btn = Button.new()
	_send_btn.text = "Say"
	_send_btn.position = Vector2(364, 230)
	_send_btn.size = Vector2(48, 32)
	_send_btn.add_theme_font_size_override("font_size", 8)
	_send_btn.visible = false
	_send_btn.pressed.connect(_on_type_submit)
	_layer.add_child(_send_btn)

	_type_toggle = Button.new()
	_type_toggle.text = "Type"
	_type_toggle.position = Vector2(408, 24)
	_type_toggle.size = Vector2(60, 24)
	_type_toggle.add_theme_font_size_override("font_size", 8)
	_type_toggle.pressed.connect(_toggle_input_mode)
	_layer.add_child(_type_toggle)

	_build_item_row()
	PixelUi.scale_tree(_layer, UI_SCALE)

func _build_item_row() -> void:
	var x := 252.0
	var y := 24.0
	for id in GameState.equipped_item_ids():
		var item_id := str(id)
		var b := Button.new()
		b.position = Vector2(x, y)
		b.size = Vector2(34, 34)
		b.set_meta("item_id", item_id)
		b.tooltip_text = "%s x%d\n%s" % [Items.name_for(item_id), GameState.item_count(item_id), Items.desc_for(item_id)]
		b.disabled = not GameState.can_use_item(item_id, "gym")
		b.pressed.connect(_use_item.bind(item_id))
		var tex := Art.tex(Items.icon_for(item_id))
		if tex != null:
			b.icon = tex
			b.expand_icon = true
		else:
			b.text = Items.short_name_for(item_id)
			b.add_theme_font_size_override("font_size", 6)
		_layer.add_child(b)
		_item_buttons.append(b)
		x += 38.0

func _refresh_item_buttons() -> void:
	for b in _item_buttons:
		var id := str(b.get_meta("item_id", ""))
		if id != "":
			b.disabled = not GameState.can_use_item(id, "gym") or _over
			b.tooltip_text = "%s x%d\n%s" % [Items.name_for(id), GameState.item_count(id), Items.desc_for(id)]

func _use_item(id: String) -> void:
	if _over:
		return
	var result := GameState.use_item(id, "gym", {"scenario_id": str(Game.current_scenario_id), "selected": sel, "turn": _turns})
	Telemetry.log_event({"event": "item_used" if bool(result.get("ok", false)) else "item_blocked",
		"item_id": id, "scope": "gym", "selected": sel, "turn": _turns,
		"remaining": int(result.get("remaining", GameState.item_count(id)))})
	if not bool(result.get("ok", false)):
		_result.text = "Item unavailable."
		return
	match id:
		"breathing_reset":
			composure = clampf(composure + 18.0, 0.0, GameState.max_composure())
			_result.text = "Breathing Reset  |  Composure +18"
			_coach.text = "Coach Vee: you regulated while managing the room. Now pick the highest-need student."
		"quiet_signal":
			order = clampf(order + 18.0, 0.0, 100.0)
			for s in students:
				s["restless"] = maxf(0.0, float(s.get("restless", 0.0)) - 0.12)
			_result.text = "Quiet Signal  |  Order +18"
			_coach.text = "Coach Vee: a known signal lowered noise without shaming any student."
		"student_profile_card":
			var s0: Dictionary = students[sel] if sel >= 0 and sel < students.size() else {}
			_result.text = "Student Profile Card  |  %s need revealed" % str(s0.get("name", "Student"))
			_coach.text = "Coach Vee: %s's current need is %s. Useful moves: %s." % [str(s0.get("name", "Student")), str(s0.get("target_label", "")), ", ".join(s0.get("win_moves", []))]
		"noticing_lens":
			var s1: Dictionary = students[sel] if sel >= 0 and sel < students.size() else {}
			_result.text = "Noticing Lens  |  inspect target cue"
			_coach.text = "Coach Vee: %s is at %d%% understanding and %d%% restless. Choose a move that fits that state." % [str(s1.get("name", "Student")), int(float(s1.get("u", 0.0)) * 100.0), int(float(s1.get("restless", 0.0)) * 100.0)]
		"equity_snapshot":
			var best := sel
			var best_score := -1.0
			for i in range(students.size()):
				if bool(students[i].get("resolved", false)):
					continue
				var score := float(students[i].get("restless", 0.0)) - float(students[i].get("u", 0.0))
				if score > best_score:
					best_score = score
					best = i
			_select(best)
			_result.text = "Equity Snapshot  |  highlighted the most at-risk unresolved student"
			_coach.text = "Coach Vee: this is participation monitoring. Use it before the room drifts."
		"wait_meter_pin":
			_wait_item_ready = true
			_result.text = "Wait Meter Pin  |  next move gets full wait-time credit"
			_coach.text = "Coach Vee: use the guaranteed pause before pressing a learner under load."
		"lesson_map":
			for s2 in students:
				s2["restless"] = maxf(0.0, float(s2.get("restless", 0.0)) - 0.08)
			composure = clampf(composure + 3.0, 0.0, GameState.max_composure())
			_result.text = "Lesson Map  |  room drift reduced"
			_coach.text = "Coach Vee: you re-centered the task structure. Now target one learner deliberately."
		"practice_goal_card":
			_practice_goal_active = true
			_result.text = "Practice Goal set  |  clear the capstone for bonus XP"
			_coach.text = "Coach Vee: goal focus: reach every student without overusing Tell."
	_refresh()
	_refresh_item_buttons()

func _label(t: String, pos: Vector2, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t; l.position = pos
	l.add_theme_font_size_override("font_size", fs + GameState.ui_font_delta())
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
	_refresh_item_buttons()

func _select(i: int) -> void:
	sel = i
	_refresh()
	if _result != null and sel >= 0 and sel < students.size():
		var s: Dictionary = students[sel]
		_result.text = "Current target: %s. Need: %s." % [s["name"], s.get("target_label", "")]

func _toggle_input_mode() -> void:
	_type_mode = not _type_mode
	if _type_toggle != null:
		_type_toggle.text = "Menu" if _type_mode else "Type"
	for b in _buttons:
		b.visible = not _type_mode
	if _text_input != null:
		_text_input.visible = _type_mode
	if _send_btn != null:
		_send_btn.visible = _type_mode
	if _mic_btn != null:
		_mic_btn.visible = _type_mode
	if _type_mode:
		_result.text = "Type mode: write teacher talk to the selected student."
		_text_input.grab_focus()
	elif not _buttons.is_empty():
		_buttons[0].grab_focus()

func _start_voice_input() -> void:
	if _text_input == null:
		return
	if VoiceInput.start_for_line_edit(_text_input):
		_result.text = "Listening... speak your teacher talk."
	else:
		_result.text = "Voice input is not available in this browser."

func _on_type_submit() -> void:
	if _over or _text_input == null:
		return
	var line := _text_input.text.strip_edges()
	if line == "":
		return
	_text_input.clear()
	_next_input_mode = "free_text"
	_next_free_text = line
	_on_move(_classify_gym_text(line))

func _classify_gym_text(text: String) -> String:
	var t := text.to_lower()
	if t.find("walk me through") >= 0 or t.find("how did") >= 0 or t.find("how are you thinking") >= 0 or t.find("why do you") >= 0:
		return "elicit"
	if t.find("what if") >= 0 or t.find("what happens") >= 0 or t.find("push") >= 0 or t.find("another way") >= 0:
		return "extend"
	if t.find("so you") >= 0 or t.find("what i hear") >= 0 or t.find("you are saying") >= 0 or t.find("sounds like") >= 0:
		return "revoice"
	if t.find("good") >= 0 or t.find("nice") >= 0 or t.find("i like") >= 0 or t.find("you did") >= 0:
		return "praise"
	if t.find("focus") >= 0 or t.find("back to") >= 0 or t.find("eyes") >= 0 or t.find("voice") >= 0:
		return "redirect"
	if t.find("wait") >= 0 or t.find("take your time") >= 0 or t.find("think") >= 0:
		return "wait"
	if t.find("answer is") >= 0 or t.find("let me show") >= 0 or t.find("actually") >= 0:
		return "tell"
	return "elicit"

func _on_move(tag: String) -> void:
	if _over:
		return
	var input_mode := _next_input_mode
	var free_text := _next_free_text
	_next_input_mode = "menu"
	_next_free_text = ""
	Sfx.play("click")
	_turns += 1
	var s: Dictionary = students[sel]
	if s.get("resolved", false):
		_result.text = "%s is already resolved. Pick another student." % s["name"]
		_coach.text = "Coach Vee: %s is already with you. Turn to someone who needs you." % s["name"]
		return
	var raw_wait_ms := Time.get_ticks_msec() - _ready_ms
	var wait_ms := GameState.effective_wait_ms(raw_wait_ms)
	var wait_ok := raw_wait_ms >= GameState.wait_threshold_ms()
	if _wait_item_ready:
		wait_ms = max(wait_ms, GameState.wait_threshold_ms())
		wait_ok = true
		_wait_item_ready = false
	var wm: Array = s.get("win_moves", [])
	var targets := false
	if tag == "wait":
		targets = ("wait" in wm) and wait_ok
	elif tag != "tell":
		targets = tag in wm

	# Effect on the targeted student.
	if targets:
		var old_u := float(s["u"])
		s["u"] = clampf(float(s["u"]) + 0.18, 0.0, 1.0)
		s["restless"] = maxf(0.0, float(s["restless"]) - 0.35)
		composure = clampf(composure + 1.0, 0.0, GameState.max_composure())
		_dialogue.text = "%s: \"...okay, that helps.\"" % s["name"]
		_result.text = "%s +%d understanding  |  correct move for this student" % [s["name"], int(round((float(s["u"]) - old_u) * 100.0))]
		Sfx.play("good")
		_coach.text = "Coach Vee: good move for %s." % s["name"]
	elif tag == "tell":
		s["restless"] = minf(1.0, float(s["restless"]) + 0.1)
		composure = clampf(composure - 4.0, 0.0, GameState.max_composure())
		_dialogue.text = "%s: \"Oh... okay, I guess.\"" % s["name"]
		_result.text = "Composure -4  |  telling did not build %s's reasoning" % s["name"]
		Sfx.play("bad")
		_coach.text = "Coach Vee: telling took over %s's thinking." % s["name"]
	else:
		composure = clampf(composure - 2.0, 0.0, GameState.max_composure())
		_dialogue.text = "%s: \"...\"" % s["name"]
		_result.text = "Composure -2  |  not the move %s needs yet" % s["name"]
		Sfx.play("bad")
		_coach.text = "Coach Vee: that is not the move %s needs (try: %s)." % [s["name"], s.get("target_label", "")]

	# Resolve?
	if float(s["u"]) >= WIN_U and targets:
		s["resolved"] = true
		s["restless"] = 0.0
		_dialogue.text = "%s: \"%s\"" % [s["name"], s["win_line"]]
		TTSClient.speak(str(s.get("pid", "")), str(s.get("win_line", "")), "excited")

	# Everyone else drifts while you attend to one (orchestration cost).
	for j in range(students.size()):
		if j == sel or students[j].get("resolved", false):
			continue
		students[j]["restless"] = minf(1.0, float(students[j]["restless"]) + 0.12)
		if float(students[j]["restless"]) >= 1.0:
			order = clampf(order - 8.0, 0.0, 100.0)
			composure = clampf(composure - 3.0, 0.0, GameState.max_composure())
			students[j]["restless"] = 0.55

	_arm_turn()
	_refresh()
	_check_end()
	if not _over and not bool(s.get("resolved", false)):
		_request_llm_turn(tag, wait_ms, wait_ok, targets, s, input_mode, free_text)
	else:
		_log_gym_turn(tag, input_mode, free_text, wait_ms, wait_ok, targets, s, {}, "")

func _request_llm_turn(tag: String, wait_ms: int, wait_ok: bool, targets: bool, student: Dictionary, input_mode: String, free_text: String) -> void:
	if _http == null or _llm_busy:
		return
	_dialogue_tail.append({"speaker": "Teacher", "text": _move_gloss(tag, input_mode, free_text)})
	_move_history.append({"tag": tag, "targets": targets})
	var payload := {
		"session_id": "gym",
		"scenario_id": str(Game.current_scenario_id),
		"scenario_context": _gym_scenario_context(student),
		"target_behavior": str(student.get("target_label", "")),
		"active_persona_id": str(student.get("pid", "")),
		"runtime_state": {
			"understanding": float(student.get("u", 0.0)),
			"engagement": 1.0 - float(student.get("restless", 0.0)),
			"trust_in_teacher": composure / GameState.max_composure(),
			"misconception_resolved": bool(student.get("resolved", false)),
			"turns_elapsed": _turns,
		},
		"teacher_move": {"input_mode": input_mode, "menu_tag": tag, "text": free_text, "wait_time_ms": wait_ms},
		"win_moves": student.get("win_moves", []),
		"dialogue_tail": _dialogue_tail.slice(maxi(0, _dialogue_tail.size() - 6)),
		"move_history": _move_history.slice(maxi(0, _move_history.size() - 6)),
		"model_profile": "openrouter_gemini",
	}
	_last_turn_payload = payload
	_last_targets = targets
	var err := _http.request(LLMClient.endpoint, PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		return
	_llm_busy = true

func _on_llm_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_llm_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var resp = JSON.parse_string(body.get_string_from_utf8())
	if typeof(resp) != TYPE_DICTIONARY:
		return
	var utter: Dictionary = resp.get("student_utterance", {})
	var text := str(utter.get("text", ""))
	var speaker := str(utter.get("speaker", students[sel].get("name", "Student") if sel >= 0 and sel < students.size() else "Student"))
	if text != "":
		_dialogue.text = "%s: \"%s\"" % [speaker, text]
		_dialogue_tail.append({"speaker": speaker, "text": text})
	var tip := str(resp.get("coach_tip", ""))
	if tip != "":
		_coach.text = "Coach Vee: " + tip
	if sel >= 0 and sel < students.size():
		TTSClient.speak(str(students[sel].get("pid", "")), text, str(utter.get("emotion_shown", "thinking")))
		var move: Dictionary = _last_turn_payload.get("teacher_move", {})
		_log_gym_turn(
			str(move.get("menu_tag", "")),
			str(move.get("input_mode", "menu")),
			str(move.get("text", "")),
			int(move.get("wait_time_ms", 0)),
			int(move.get("wait_time_ms", 0)) >= 3000,
			_last_targets,
			students[sel],
			resp,
			text
		)

func _log_gym_turn(tag: String, input_mode: String, free_text: String, wait_ms: int, wait_ok: bool, targets: bool, student: Dictionary, resp: Dictionary, student_text: String) -> void:
	Telemetry.log_event({
		"event": "gym_turn",
		"scenario_id": str(Game.current_scenario_id),
		"persona_id": str(student.get("pid", "")),
		"turn": _turns,
		"move": {"tag": tag, "input_mode": input_mode, "text": free_text, "wait_ms": wait_ms},
		"judge": {"targets": targets, "wait_ok": wait_ok},
		"student_state": {
			"understanding": float(student.get("u", 0.0)),
			"restless": float(student.get("restless", 0.0)),
			"resolved": bool(student.get("resolved", false)),
			"target_label": str(student.get("target_label", "")),
		},
		"room_state": {"composure": composure, "order": order},
		"student_text": student_text,
		"llm_response": resp,
	})

func _gym_scenario_context(active_student: Dictionary) -> Dictionary:
	var objective_labels: Array = []
	for o in scenario.get("objectives", []):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			objective_labels.append(str(o.get("label", "")))
	var targets: Array = []
	for s in students:
		targets.append({
			"persona_id": str(s.get("pid", "")),
			"name": str(s.get("name", "Student")),
			"target_label": str(s.get("target_label", "")),
			"opening_line": str(s.get("opening_line", "")),
			"win_moves": s.get("win_moves", []),
			"resolved": bool(s.get("resolved", false)),
			"understanding": float(s.get("u", 0.0)),
			"restless": float(s.get("restless", 0.0)),
		})
	return {
		"id": str(scenario.get("id", Game.current_scenario_id)),
		"title": str(scenario.get("title", "Current capstone")),
		"format": str(scenario.get("format", "discussion")),
		"arrangement": str(scenario.get("arrangement", "")),
		"objectives": objective_labels,
		"backdrop": str(scenario.get("backdrop", "")),
		"story_hook": str(scenario.get("story_hook", "")),
		"pod_targets": targets,
		"active_student": {
			"persona_id": str(active_student.get("pid", "")),
			"name": str(active_student.get("name", "Student")),
			"target_label": str(active_student.get("target_label", "")),
			"opening_line": str(active_student.get("opening_line", "")),
			"win_moves": active_student.get("win_moves", []),
			"understanding": float(active_student.get("u", 0.0)),
			"restless": float(active_student.get("restless", 0.0)),
		},
	}

func _move_gloss(tag: String, input_mode: String = "menu", free_text: String = "") -> String:
	if input_mode == "free_text" and free_text.strip_edges() != "":
		return free_text
	match tag:
		"elicit":
			return "Can you walk me through how you are thinking?"
		"extend":
			return "What happens if you push that idea one step further?"
		"revoice":
			return "So what I hear you saying is..."
		"tell":
			return "Let me show you the answer directly."
		"praise":
			return "I name what you did well."
		"redirect":
			return "Let's bring our focus back to the task."
		"wait":
			return "(waits quietly)"
	return "I address the student."

func _set_move_buttons_disabled(disabled: bool) -> void:
	for b in _buttons:
		b.disabled = disabled
	if _send_btn != null:
		_send_btn.disabled = disabled
	if _mic_btn != null:
		_mic_btn.disabled = disabled or not VoiceInput.is_supported()
	if _text_input != null:
		_text_input.editable = not disabled
	if _type_toggle != null:
		_type_toggle.disabled = disabled
	for b in _item_buttons:
		b.disabled = disabled or not GameState.can_use_item(str(b.get_meta("item_id", "")), "gym")

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
		var reward := {}
		if badge != "":
			reward = GameState.award_badge(badge)
			if bool(reward.get("level_up", false)):
				_result.text = "Level %d reached. Upgrade point earned." % int(reward.get("level_after", GameState.teacher_level))
		if _practice_goal_active:
			GameState.add_teacher_xp(50, "practice_goal:%s" % str(Game.current_scenario_id))
		var score := resolved * 60 + int(round(composure + order))
		var run_record := GameState.record_leaderboard({
			"scenario_id": str(Game.current_scenario_id),
			"title": str(scenario.get("title", "Capstone")),
			"mode": "Gym",
			"badge": badge,
			"score": score,
			"detail": "%d/%d reached  Order %d%%  Composure %d%%" % [resolved, students.size(), int(order), int(composure)],
			"level_up": bool(reward.get("level_up", false)),
		})
		Sfx.play("badge")
		_coach.text = "Coach Vee: you held the whole room and reached every student. Capstone cleared!"
		_show_complete_panel(true, resolved, reward, run_record)
	else:
		_coach.text = "Coach Vee: the room got away from you (%d/%d reached). Circulate faster next time." % [resolved, students.size()]
		_show_complete_panel(false, resolved, {}, {})

func _show_complete_panel(won: bool, resolved: int, reward: Dictionary, run_record: Dictionary) -> void:
	for b in _buttons:
		b.visible = false
	for b in _item_buttons:
		b.visible = false
	if _text_input != null:
		_text_input.visible = false
	if _send_btn != null:
		_send_btn.visible = false
	if _mic_btn != null:
		_mic_btn.visible = false
	if _type_toggle != null:
		_type_toggle.visible = false
	if _dialogue != null:
		_dialogue.visible = false
	if _result != null:
		_result.visible = false
	if _coach != null:
		_coach.visible = false
	var overlay := Control.new()
	overlay.name = "GymComplete"
	_layer.add_child(overlay)
	var panel := Panel.new()
	panel.position = Vector2(34, 78)
	panel.size = Vector2(436, 184)
	overlay.add_child(panel)
	_overlay_label(overlay, "GYM DEBRIEF", Vector2(48, 94), 10, Color(0.97, 0.95, 0.86), Vector2(404, 16))
	var score := int(run_record.get("score", resolved * 60 + int(round(composure + order))))
	var rank := str(run_record.get("rank", GameState._rank_for_score(score)))
	_overlay_label(overlay, "%s   |   Score %03d   |   Rank %s" % ["CLEARED" if won else "TRY AGAIN", score, rank], Vector2(48, 118), 7, Color(0.96, 0.86, 0.50), Vector2(404, 14))
	var reward_line := "Reached %d/%d | Order %d%% | Composure %d%%" % [resolved, students.size(), int(order), int(composure)]
	if bool(reward.get("level_up", false)):
		reward_line += " | +upgrade"
	_overlay_label(overlay, reward_line, Vector2(48, 136), 7, Color(0.72, 0.82, 0.96), Vector2(404, 14))
	_overlay_label(overlay, "Drivers: Reach%d Order%d Calm%d" % [resolved * 60, int(order), int(composure)], Vector2(48, 154), 7, Color(0.72, 0.82, 0.96), Vector2(390, 14))
	_overlay_label(overlay, "Focus: switch, monitor, support.", Vector2(48, 178), 7, Color(0.72, 0.78, 0.88), Vector2(340, 16))
	_overlay_label(overlay, _gym_next_step(won, resolved), Vector2(48, 196), 7, Color(0.72, 0.92, 0.78), Vector2(250, 16))
	var cont := Button.new()
	cont.text = "Continue"
	cont.position = Vector2(360, 224)
	cont.size = Vector2(92, 30)
	cont.add_theme_font_size_override("font_size", 8)
	cont.pressed.connect(func(): SceneRouter.change_scene("res://scenes/ui/Hub.tscn"))
	overlay.add_child(cont)
	PixelUi.scale_tree(overlay, UI_SCALE)
	cont.grab_focus()

func _overlay_label(parent: Node, text: String, pos: Vector2, fs: int, color: Color, size: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.add_theme_font_size_override("font_size", fs + GameState.ui_font_delta())
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _gym_next_step(won: bool, resolved: int) -> String:
	if resolved < students.size():
		return "Next: switch targets earlier."
	if order < 70.0:
		return "Next: signal before drift."
	if won:
		return "Next: balance target and room."
	return "Next: highest-need first."

# --- view --------------------------------------------------------------------

func _refresh() -> void:
	_set_fill(_comp_fill, composure / GameState.max_composure())
	_set_fill(_order_fill, order / 100.0)
	for s in students:
		_set_fill(s["ufill"], float(s["u"]))
		_set_fill(s["rfill"], float(s["restless"]))
	if sel >= 0 and sel < students.size():
		var s2: Dictionary = students[sel]
		_highlight.position = Vector2(float(s2["x"]) - 2.0, float(s2["y"]) - 2.0) * UI_SCALE
		_highlight.size = Vector2((float(s2["w"]) + 4.0) * UI_SCALE, 100.0 * UI_SCALE)
		_title.text = "GYM: target = %s  (%s)" % [s2["name"], s2.get("target_label", "")]

func _set_fill(fill: ColorRect, frac: float) -> void:
	if fill == null:
		return
	var w: float = fill.get_meta("w", 150.0)
	fill.size = Vector2(w * UI_SCALE * clampf(frac, 0.0, 1.0), fill.size.y)
