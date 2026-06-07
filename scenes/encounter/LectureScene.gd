extends Control
## Lecture (direct-instruction) mode: the rhythm of PRESENT vs CHECK-FOR-UNDERSTANDING.
## Students REACT (portrait affect swap + emote bubble + bob) to your pacing, questions, and
## whether they follow. See LECTURE_DESIGN.md.

const Art = preload("res://scripts/Art.gd")
const PixelUi = preload("res://scripts/PixelUi.gd")
const CompletionFx = preload("res://scenes/encounter/CompletionFx.gd")
const UI_SCALE := 2.0
const MOVES := [
	["Present", "present"], ["Question", "ask"], ["Wait", "wait"],
	["Repair", "reexplain"], ["Check", "poll"],
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
var _scenario_context: Dictionary = {}
var _lecture_history: Array = []
var _move_history: Array = []
var _llm_busy := false
var _next_input_mode := "menu"
var _next_free_text := ""
var _last_turn_payload: Dictionary = {}

var _http: HTTPRequest
var _layer: Control
var _backdrop: TextureRect
var _title: Label
var _bars := {}            # key -> ColorRect fill
var _dialogue: Label
var _coach: Label
var _result: Label
var _wait_label: Label
var _wait_fill: ColorRect
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
var _target_comprehension := 60.0

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 16.0
	add_child(_http)
	_http.request_completed.connect(_on_lecture_reply)
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
	_scenario_context = _build_scenario_context(-1)
	_refresh_backdrop()
	for entry in scenario.get("roster", []):
		students.append({"pid": str(entry.get("id", "")), "name": str(entry.get("name", "?")),
			"comp": 0.3, "called": false})
	_apply_adaptive_difficulty()
	_build_ui()
	_arm_turn()
	_refresh()

func _apply_adaptive_difficulty() -> void:
	var d := Game.adaptive_difficulty(["formative_check", "wait_time", "restraint"])
	var level := str(d.get("level", "standard"))
	if level == "scaffold":
		comprehension = clampf(comprehension + 6.0, 0.0, 100.0)
		attention = clampf(attention + 4.0, 0.0, 100.0)
		_target_comprehension = 55.0
	elif level == "challenge":
		comprehension = clampf(comprehension - 5.0, 0.0, 100.0)
		attention = clampf(attention - 7.0, 0.0, 100.0)
		_target_comprehension = 68.0
	else:
		_target_comprehension = 60.0

func _build_scenario_context(selected_index: int) -> Dictionary:
	var objective_labels: Array = []
	for o in scenario.get("objectives", []):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			objective_labels.append(str(o.get("label", "")))
	var roster_briefs: Array = []
	for entry in scenario.get("roster", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pid := str(entry.get("id", ""))
		var base := _read_persona(pid)
		roster_briefs.append({
			"persona_id": pid,
			"name": str(entry.get("name", base.get("display_name", "Student"))),
			"target_label": str(base.get("target_label", "")),
			"opening_line": str(base.get("opening_line", "")),
		})
	var active := {}
	if selected_index >= 0 and selected_index < students.size():
		var s: Dictionary = students[selected_index]
		var base2 := _read_persona(str(s.get("pid", "")))
		active = {
			"persona_id": str(s.get("pid", "")),
			"name": str(s.get("name", "Student")),
			"target_label": str(base2.get("target_label", "")),
			"opening_line": str(base2.get("opening_line", "")),
		}
	return {
		"id": str(scenario.get("id", Game.current_scenario_id)),
		"title": str(scenario.get("title", "Current lecture")),
		"format": str(scenario.get("format", "lecture")),
		"arrangement": str(scenario.get("arrangement", "rows")),
		"objectives": objective_labels,
		"backdrop": str(scenario.get("backdrop", "")),
		"story_hook": str(scenario.get("story_hook", "")),
		"lecture_focus": scenario.get("lecture_focus", {}),
		"roster": roster_briefs,
		"active_student": active,
	}

func _read_persona(pid: String) -> Dictionary:
	var path := "res://data/persona_library/%s.json" % pid
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
	_title = _label("LECTURE: %s" % str(scenario.get("title", "Lesson")), Vector2(10, 6), 11, Color(0.97, 0.93, 0.85))
	_title.size = Vector2(460, 14)

	_make_bar("progress", "Lesson Progress", 26, Color(0.30, 0.80, 0.40))
	_make_bar("comp", "Comprehension", 42, Color(0.35, 0.65, 0.95))
	_make_bar("attn", "Attention", 58, Color(0.95, 0.78, 0.30))
	_make_bar("composure", "Composure", 74, Color(0.90, 0.45, 0.55))

	_wait_label = _label(_wait_label_text(false), Vector2(284, 42), 7, Color(0.8, 0.85, 0.95))
	var wbg := ColorRect.new()
	wbg.position = Vector2(284, 58)
	wbg.size = Vector2(90, 8)
	wbg.color = Color(0, 0, 0, 0.5)
	wbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(wbg)
	_wait_fill = ColorRect.new()
	_wait_fill.position = Vector2(284, 58)
	_wait_fill.size = Vector2(0, 8)
	_wait_fill.color = Color(0.55, 0.56, 0.62)
	_wait_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_wait_fill)

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

	var dialogue_box := Rect2(Vector2(10, 162), Vector2(460, 42))
	var dialogue_text := Rect2(Vector2(18, 166), Vector2(444, 24))
	var dbg := ColorRect.new()
	dbg.name = "DialogueBubble"
	dbg.position = dialogue_box.position
	dbg.size = dialogue_box.size
	dbg.color = Color(0.12, 0.15, 0.26, 0.88)
	dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(dbg)
	_dialogue = _label("", dialogue_text.position, 9, Color(0.96, 0.96, 0.92))
	_dialogue.name = "DialogueText"
	_dialogue.size = dialogue_text.size
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.set_meta("qa_container_rect", dialogue_box)
	_dialogue.set_meta("qa_text_rect", dialogue_text)
	_dialogue.set_meta("qa_min_padding", 4.0)
	_result = _label("Guide: Present -> Wait -> Question/Check. Repair when comprehension lags.", Vector2(12, 204), 7, Color(0.96, 0.86, 0.50))
	_result.size = Vector2(456, 10)
	_coach = _label("Coach Vee: press Repair if progress outruns comprehension; otherwise Check.", Vector2(12, 210), 7, Color(0.72, 0.92, 0.78))
	_coach.size = Vector2(456, 18)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bw := 92.0
	for i in range(MOVES.size()):
		var b := Button.new()
		b.text = MOVES[i][0]
		b.position = Vector2(10 + i * bw, 230)
		b.size = Vector2(bw - 4, 32)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 7)
		b.pressed.connect(_on_move.bind(str(MOVES[i][1])))
		_layer.add_child(b)
		_buttons.append(b)

	_text_input = LineEdit.new()
	_text_input.position = Vector2(10, 230)
	_text_input.size = Vector2(300, 32)
	_text_input.placeholder_text = "Type what you would say to the class."
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
	_type_toggle.position = Vector2(426, 40)
	_type_toggle.size = Vector2(48, 24)
	_type_toggle.add_theme_font_size_override("font_size", 8)
	_type_toggle.pressed.connect(_toggle_input_mode)
	_layer.add_child(_type_toggle)

	_build_item_row()
	PixelUi.scale_tree(_layer, UI_SCALE)

func _build_item_row() -> void:
	var x := 276.0
	var y := 62.0
	for id in GameState.equipped_item_ids():
		var item_id := str(id)
		var b := Button.new()
		b.position = Vector2(x, y)
		b.size = Vector2(34, 34)
		b.set_meta("item_id", item_id)
		b.tooltip_text = "%s x%d\n%s" % [Items.name_for(item_id), GameState.item_count(item_id), Items.desc_for(item_id)]
		b.disabled = not GameState.can_use_item(item_id, "lecture")
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
			b.disabled = not GameState.can_use_item(id, "lecture") or _over
			b.tooltip_text = "%s x%d\n%s" % [Items.name_for(id), GameState.item_count(id), Items.desc_for(id)]

func _use_item(id: String) -> void:
	if _over:
		return
	var result := GameState.use_item(id, "lecture", {"scenario_id": str(Game.current_scenario_id), "selected": sel})
	Telemetry.log_event({"event": "item_used" if bool(result.get("ok", false)) else "item_blocked",
		"item_id": id, "scope": "lecture", "selected": sel, "remaining": int(result.get("remaining", GameState.item_count(id)))})
	if not bool(result.get("ok", false)):
		_result.text = "Item unavailable."
		return
	match id:
		"breathing_reset":
			var gain := 22.0 if GameState.teacher_profile_id == "steady" else 18.0
			composure = clampf(composure + gain, 0.0, GameState.max_composure())
			_result.text = "Breathing Reset  |  Composure +%d%s" % [int(gain), " profile bonus" if gain > 18.0 else ""]
			_coach.text = "Coach Vee: you reset before continuing. Now choose a smaller, more diagnostic next move."
		"quiet_signal":
			var signal_gain := 22.0 if GameState.teacher_profile_id == "steady" else 18.0
			attention = clampf(attention + signal_gain, 0.0, 100.0)
			_result.text = "Quiet Signal  |  Attention +%d%s" % [int(signal_gain), " profile bonus" if signal_gain > 18.0 else ""]
			_coach.text = "Coach Vee: a practiced attention signal restores the room without escalating."
			_react_many("thinking", "dots", students.size())
		"noticing_lens":
			var s: Dictionary = students[sel] if sel >= 0 and sel < students.size() else {}
			_result.text = "Noticing Lens  |  check the highlighted learner"
			_coach.text = "Coach Vee: look at %s. If progress is ahead of comprehension, repair before asking harder questions." % str(s.get("name", "the highlighted student"))
		"equity_snapshot":
			for i in range(students.size()):
				if not bool(students[i].get("called", false)):
					_select(i)
					break
			var equity_gain := 6.0 if GameState.teacher_profile_id == "equity" else 0.0
			attention = clampf(attention + equity_gain, 0.0, 100.0)
			_result.text = "Equity Snapshot  |  highlighted a student who has not spoken%s" % ("  |  Attention +6" if equity_gain > 0.0 else "")
			_coach.text = "Coach Vee: equitable participation is a design move, not just a fairness slogan. Ask the highlighted student next."
		"wait_meter_pin":
			_wait_item_ready = true
			_result.text = "Wait Meter Pin  |  next move gets full wait-time credit"
			_coach.text = "Coach Vee: use this pause before asking so more students can enter the question."
		"lesson_map":
			comprehension = clampf(comprehension + 5.0, 0.0, 100.0)
			composure = clampf(composure + 3.0, 0.0, GameState.max_composure())
			_result.text = "Lesson Map  |  Comprehension +5  |  Composure +3"
			_coach.text = "Coach Vee: you realigned the chunk with the objective. Now check before advancing."
		"practice_goal_card":
			_practice_goal_active = true
			_result.text = "Practice Goal set  |  clear this lecture for bonus XP"
			_coach.text = "Coach Vee: goal focus: check understanding before presenting two more chunks."
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
				emo.scale = Vector2(18.0 * UI_SCALE / float(et.get_width()), 18.0 * UI_SCALE / float(et.get_width()))
				emo.visible = true

# --- turn logic --------------------------------------------------------------

func _arm_turn() -> void:
	_ready_ms = Time.get_ticks_msec()
	_refresh_item_buttons()

func _process(_delta: float) -> void:
	if _over:
		return
	var elapsed := float(Time.get_ticks_msec() - _ready_ms)
	var frac := clampf(elapsed / float(GameState.wait_threshold_ms()), 0.0, 1.0)
	if _wait_fill != null:
		_wait_fill.size = Vector2(90.0 * UI_SCALE * frac, 8.0 * UI_SCALE)
		_wait_fill.color = Color(0.30, 0.80, 0.40) if frac >= 1.0 else Color(0.55, 0.56, 0.62)
	if _wait_label != null:
		_wait_label.text = _wait_label_text(frac >= 1.0)

func _wait_label_text(ready: bool) -> String:
	var seconds := float(GameState.wait_threshold_ms()) / 1000.0
	return ("Wait %.2fs: READY" if ready else "Wait %.2fs before Question") % seconds

func _select(i: int) -> void:
	sel = i
	_refresh()

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
		_result.text = "Type mode: write your teacher talk; the game maps it to a lecture move."
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
	_on_move(_classify_lecture_text(line))

func _classify_lecture_text(text: String) -> String:
	var t := text.to_lower()
	if t.find("?") >= 0 or t.find("who can") >= 0 or t.find("what do you") >= 0 or t.find("why") >= 0 or t.find("show me") >= 0:
		return "ask"
	if t.find("wait") >= 0 or t.find("take a moment") >= 0 or t.find("think time") >= 0 or t.find("pause") >= 0:
		return "wait"
	if t.find("thumb") >= 0 or t.find("poll") >= 0 or t.find("everyone") >= 0 or t.find("show your") >= 0:
		return "poll"
	if t.find("another way") >= 0 or t.find("let me try again") >= 0 or t.find("different way") >= 0 or t.find("re-explain") >= 0:
		return "reexplain"
	return "present"

func _on_move(tag: String) -> void:
	if _over:
		return
	var input_mode := _next_input_mode
	var free_text := _next_free_text
	_next_input_mode = "menu"
	_next_free_text = ""
	Sfx.play("click")
	var raw_wait_ms := Time.get_ticks_msec() - _ready_ms
	var wait_ms := GameState.effective_wait_ms(raw_wait_ms)
	var wait_ok := raw_wait_ms >= GameState.wait_threshold_ms()
	if _wait_item_ready:
		wait_ms = max(wait_ms, GameState.wait_threshold_ms())
		wait_ok = true
		_wait_item_ready = false
	var gap := progress - comprehension
	match tag:
		"present":
			var old_attention := attention
			progress = clampf(progress + 12.0, 0.0, 100.0)
			consec_present += 1
			attention = clampf(attention - (5.0 + 4.0 * float(consec_present)), 0.0, 100.0)
			_dialogue.text = "You present the next part of the lesson."
			_result.text = "Progress +12  |  Attention %s" % _signed(int(round(attention - old_attention)))
			if gap > 28.0:
				attention = clampf(attention - 8.0, 0.0, 100.0)
				composure = clampf(composure - 3.0, 0.0, GameState.max_composure())
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
			var old_comp := comprehension
			var old_attn := attention
			attention = clampf(attention + 14.0, 0.0, 100.0)
			var s: Dictionary = students[sel]
			if s.get("called", false):
				comprehension = clampf(comprehension + 2.0, 0.0, 100.0)
				_result.text = "Question -> %s  |  Comprehension +2  |  repeated call" % s["name"]
				_coach.text = "Coach Vee: you've already heard from %s. Spread it to the back rows." % s["name"]
			else:
				s["called"] = true
				var bonus := 0.0
				if wait_ok:
					bonus = 4.0
				comprehension = clampf(comprehension + 6.0 + bonus, 0.0, 100.0)
				_result.text = "Question -> %s  |  Comprehension %s  |  Attention %s" % [s["name"], _signed(int(round(comprehension - old_comp))), _signed(int(round(attention - old_attn)))]
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
			_result.text = "Wait-Time ready: ask a question after the pause."
			_coach.text = "Coach Vee: wait time lets more of them think. Now pose a question."
		"reexplain":
			var old_comp2 := comprehension
			consec_present = 0
			comprehension = clampf(comprehension + 12.0, 0.0, 100.0)
			attention = clampf(attention + 6.0, 0.0, 100.0)
			composure = clampf(composure + 2.0, 0.0, GameState.max_composure())
			_dialogue.text = "You re-explain the tricky step a different way."
			_result.text = "Comprehension %s  |  responsive repair" % _signed(int(round(comprehension - old_comp2)))
			_coach.text = "Coach Vee: closing the gap. That's responsive teaching."
			_react_many("excited", "exclaim", 3)
		"poll":
			var old_comp3 := comprehension
			consec_present = 0
			comprehension = clampf(comprehension + 16.0, 0.0, 100.0)
			attention = clampf(attention + 20.0, 0.0, 100.0)
			_dialogue.text = "Whole-class check: everyone shows their answer."
			_result.text = "Whole-class check  |  Comprehension %s  |  everyone accountable" % _signed(int(round(comprehension - old_comp3)))
			_coach.text = "Coach Vee: a whole-class check holds everyone accountable at once."
			_react_many("thinking", "exclaim", students.size())
	_observe_lecture_competency(tag, wait_ok, gap)
	_move_history.append({"turn": _move_history.size() + 1, "tag": tag, "targets": _lecture_move_productive(tag, wait_ok, gap),
		"construct": _lecture_construct(tag), "reaction": _dialogue.text, "meter": _result.text})
	Telemetry.log_event({
		"event": "lecture_move",
		"scenario_id": str(Game.current_scenario_id),
		"construct_id": _lecture_construct(tag),
		"move": {"tag": tag, "input_mode": input_mode, "text": free_text, "wait_ms": wait_ms},
		"wait_ok": wait_ok,
		"class_state": {"progress": progress, "comprehension": comprehension, "attention": attention, "composure": composure},
	})
	_refresh()
	_check_end()
	if not _over:
		_request_lecture_turn(tag, wait_ms, wait_ok, input_mode, free_text)
	_arm_turn()

func _observe_lecture_competency(tag: String, wait_ok: bool, gap_before: float) -> void:
	match tag:
		"ask":
			Competency.observe_skill("elicit_reasoning", "lecture::ask", comprehension >= 55.0 or gap_before <= 25.0)
			if wait_ok:
				Competency.observe_skill("wait_time", "lecture::ask_wait", true)
		"wait":
			Competency.observe_skill("wait_time", "lecture::wait", wait_ok)
		"reexplain":
			Competency.observe_skill("formative_check", "lecture::repair", gap_before >= 18.0 or comprehension >= 60.0)
		"poll":
			Competency.observe_skill("formative_check", "lecture::poll", true)
		"present":
			Competency.observe_skill("restraint", "lecture::present_pacing", consec_present <= 2 and gap_before <= 28.0)

func _lecture_construct(tag: String) -> String:
	match tag:
		"ask":
			return "elicit_reasoning"
		"wait":
			return "wait_time"
		"reexplain", "poll":
			return "formative_check"
		"present":
			return "restraint"
	return ""

func _lecture_move_productive(tag: String, wait_ok: bool, gap_before: float) -> bool:
	match tag:
		"ask":
			return comprehension >= 55.0 or gap_before <= 25.0
		"wait":
			return wait_ok
		"reexplain":
			return gap_before >= 18.0 or comprehension >= 60.0
		"poll":
			return true
		"present":
			return consec_present <= 2 and gap_before <= 28.0
	return false

func _request_lecture_turn(tag: String, wait_ms: int, wait_ok: bool, input_mode: String, free_text: String) -> void:
	if _http == null or _llm_busy:
		return
	if LLMClient.use_stub:
		return
	_scenario_context = _build_scenario_context(sel)
	_lecture_history.append({"speaker": "Teacher", "text": _lecture_move_gloss(tag, input_mode, free_text)})
	var active: Dictionary = _scenario_context.get("active_student", {})
	var payload := {
		"session_id": "lecture",
		"scenario_id": str(Game.current_scenario_id),
		"scenario_context": _scenario_context,
		"selected_student": active,
		"class_state": {
			"progress": progress,
			"comprehension": comprehension,
			"attention": attention,
			"composure": composure,
			"consecutive_present": consec_present,
			"wait_ms": wait_ms,
			"wait_ok": wait_ok,
		},
		"teacher_move": {"input_mode": input_mode, "menu_tag": tag, "text": free_text, "wait_time_ms": wait_ms},
		"dialogue_tail": _lecture_history.slice(maxi(0, _lecture_history.size() - 6)),
		"model_profile": "openrouter_gemini",
	}
	_last_turn_payload = payload
	var ep := LLMClient.endpoint.replace("/turn", "/lecture_turn")
	var err := _http.request(ep, PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		return
	_llm_busy = true

func _on_lecture_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_llm_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var resp = JSON.parse_string(body.get_string_from_utf8())
	if typeof(resp) != TYPE_DICTIONARY:
		return
	var reaction: Dictionary = resp.get("reaction", {})
	var speaker := str(reaction.get("speaker", "Class"))
	var text := str(reaction.get("text", ""))
	if text != "":
		_dialogue.text = "%s: \"%s\"" % [speaker, text]
		_lecture_history.append({"speaker": speaker, "text": text})
	var tip := str(resp.get("coach_tip", ""))
	if tip != "":
		_coach.text = "Coach Vee: " + tip
	var emotion := str(reaction.get("emotion_shown", "thinking"))
	if str(reaction.get("scope", "class")) == "student" and sel >= 0 and sel < students.size():
		_react(sel, _lecture_affect(emotion), _lecture_emote(emotion))
	var speaker_pid := _persona_id_for_speaker(speaker)
	if speaker_pid != "" and text != "":
		TTSClient.speak(speaker_pid, text, emotion)
	Telemetry.log_event({
		"event": "lecture_turn",
		"scenario_id": str(Game.current_scenario_id),
		"move": _last_turn_payload.get("teacher_move", {}),
		"selected_student": _last_turn_payload.get("selected_student", {}),
		"class_state": _last_turn_payload.get("class_state", {}),
		"reaction": reaction,
		"coach_tip": tip,
	})

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
		b.disabled = disabled or not GameState.can_use_item(str(b.get_meta("item_id", "")), "lecture")

func _lecture_move_gloss(tag: String, input_mode: String = "menu", free_text: String = "") -> String:
	if input_mode == "free_text" and free_text.strip_edges() != "":
		return free_text
	match tag:
		"present":
			return "I present the next part of the lesson."
		"ask":
			return "I ask the highlighted student to show their thinking."
		"wait":
			return "I pause and give the class think time."
		"reexplain":
			return "I re-explain the tricky step another way."
		"poll":
			return "I run a whole-class check."
	return "I continue the lecture."

func _lecture_affect(emotion: String) -> String:
	match emotion.strip_edges().to_lower():
		"excited":
			return "excited"
		"engaged":
			return "thinking"
		"withdrawn":
			return "withdrawn"
		"confused":
			return "confused"
	return "thinking"

func _lecture_emote(emotion: String) -> String:
	match emotion.strip_edges().to_lower():
		"excited":
			return "exclaim"
		"confused":
			return "question"
		"withdrawn":
			return "dots"
	return "dots"

func _persona_id_for_speaker(speaker: String) -> String:
	var clean := speaker.strip_edges().to_lower()
	if clean == "" or clean == "class":
		return ""
	for s in students:
		if str(s.get("name", "")).strip_edges().to_lower() == clean:
			return str(s.get("pid", ""))
	if sel >= 0 and sel < students.size() and clean.find(str(students[sel].get("name", "")).to_lower()) >= 0:
		return str(students[sel].get("pid", ""))
	return ""

func _react_many(affect: String, emote_key: String, count: int) -> void:
	var done := 0
	for i in range(students.size()):
		if done >= count:
			break
		_react(i, affect, emote_key)
		done += 1

func _check_end() -> void:
	if progress >= 100.0:
		_finish(comprehension >= _target_comprehension and attention >= 25.0)
	elif attention <= 0.0 or composure <= 0.0:
		_finish(false)

func _finish(won: bool) -> void:
	_over = true
	for b in _buttons:
		b.disabled = true
	Telemetry.log_event({"event": "lecture_resolve", "scenario_id": str(Game.current_scenario_id),
		"won": won, "progress": progress, "comprehension": comprehension, "attention": attention})
	Telemetry.upload_competency()
	Telemetry.flush()
	if won:
		var badge := str(scenario.get("badge", ""))
		var reward := {}
		if badge != "":
			reward = GameState.award_badge(badge)
			if bool(reward.get("level_up", false)):
				_result.text = "Level %d reached. Upgrade point earned." % int(reward.get("level_after", GameState.teacher_level))
		if _practice_goal_active:
			GameState.add_teacher_xp(35, "practice_goal:%s" % str(Game.current_scenario_id))
		var score := int(round(comprehension + attention + composure * 0.5 + progress * 0.5))
		var run_record := GameState.record_leaderboard({
			"scenario_id": str(Game.current_scenario_id),
			"title": str(scenario.get("title", "Lecture")),
			"mode": "Lecture",
			"badge": badge,
			"score": score,
			"detail": "Comp %d%%  Attention %d%%  Progress %d%%" % [int(comprehension), int(attention), int(progress)],
			"level_up": bool(reward.get("level_up", false)),
			"trace": Game.evidence_trace_from_moves(_move_history),
			"trace_steps": Game.evidence_trace_steps_from_moves(_move_history),
		})
		Sfx.play("badge")
		_coach.text = "Coach Vee: you delivered the lesson AND kept them with you. Comprehension %d%%. Well paced!" % int(comprehension)
		for i in range(students.size()):
			_react(i, "excited", "exclaim")
		_show_complete_panel(true, reward, run_record)
	else:
		Sfx.play("bad")
		if attention <= 0.0:
			_coach.text = "Coach Vee: you lost the room. Present in smaller chunks and check more often."
		else:
			_coach.text = "Coach Vee: the lesson ended but comprehension was low (%d%%). Check understanding as you go." % int(comprehension)
		_show_complete_panel(false, {}, {})

func _show_complete_panel(won: bool, reward: Dictionary, run_record: Dictionary) -> void:
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
	overlay.name = "LectureComplete"
	_layer.add_child(overlay)
	var panel := Panel.new()
	panel.position = Vector2(34, 78)
	panel.size = Vector2(436, 184)
	overlay.add_child(panel)
	CompletionFx.add_completion_burst(overlay, Rect2(panel.position, panel.size), won)
	_overlay_label(overlay, "LECTURE DEBRIEF", Vector2(48, 94), 10, Color(0.97, 0.95, 0.86), Vector2(404, 16))
	var score := int(run_record.get("score", int(round(comprehension + attention + composure * 0.5 + progress * 0.5))))
	var rank := str(run_record.get("rank", GameState._rank_for_score(score)))
	_overlay_label(overlay, "%s   |   Score %03d   |   Rank %s" % ["CLEARED" if won else "TRY AGAIN", score, rank], Vector2(48, 118), 7, Color(0.96, 0.86, 0.50), Vector2(404, 14))
	var reward_line := "Comp %d%% | Attention %d%% | Progress %d%%" % [int(comprehension), int(attention), int(progress)]
	if bool(reward.get("level_up", false)):
		reward_line += " | +upgrade"
	_overlay_label(overlay, reward_line, Vector2(48, 136), 7, Color(0.72, 0.82, 0.96), Vector2(404, 14))
	_overlay_label(overlay, "Drivers: C%d A%d Calm%d Pace%d" % [
		int(comprehension), int(attention), int(round(composure * 0.5)), int(round(progress * 0.5))
	], Vector2(48, 154), 7, Color(0.72, 0.82, 0.96), Vector2(390, 14))
	var trace_line := str(run_record.get("evidence_trace", ""))
	_overlay_label(overlay, "Trace: " + (trace_line if trace_line != "" else "no scored move trace"), Vector2(48, 178), 7, Color(0.72, 0.78, 0.88), Vector2(340, 16))
	_overlay_label(overlay, Game.evidence_practice_target(false), Vector2(48, 196), 7, Color(0.72, 0.92, 0.78), Vector2(308, 16))
	var cont := Button.new()
	cont.text = "Return to hub"
	cont.position = Vector2(326, 224)
	cont.size = Vector2(126, 30)
	cont.add_theme_font_size_override("font_size", 7)
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

# --- view --------------------------------------------------------------------

func _refresh() -> void:
	_set_fill("progress", progress / 100.0)
	_set_fill("comp", comprehension / 100.0)
	_set_fill("attn", attention / 100.0)
	_set_fill("composure", composure / GameState.max_composure())
	if sel >= 0 and sel < students.size():
		var s: Dictionary = students[sel]
		_highlight.position = Vector2(float(s["x"]), float(s["y"])) * UI_SCALE
		_highlight.size = Vector2((float(s["slot"]) - 2.0) * UI_SCALE, 78.0 * UI_SCALE)
		_title.text = "LECTURE: %s   (Question asks -> %s)" % [str(scenario.get("title", "Lesson")), s["name"]]

func _set_fill(key: String, frac: float) -> void:
	var fill: ColorRect = _bars.get(key, null)
	if fill != null:
		fill.size = Vector2(150.0 * UI_SCALE * clampf(frac, 0.0, 1.0), 11.0 * UI_SCALE)

func _signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)
