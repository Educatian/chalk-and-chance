extends Control
const Art = preload("res://scripts/Art.gd")
## Group check-in: a DISTINCT mechanic from the 1:1 encounter. You sample a pod, reveal
## its hidden collective state (observe/probe), press the group's shared reasoning, and
## rebalance who participates (redistribute) - breadth + group dynamics, then move on.
## Backend: POST /group_turn (collective LLM utterance + monitoring judge).

const MOVES := [
	["Observe", "observe"], ["Probe", "probe"], ["Press", "press"],
	["Redistribute", "redistribute"], ["Move on", "move_on"],
]

var members: Array = []          # [{persona_id,name,talkativeness}]
var shared_concept := "comparing fractions"
var collective_status := "shared_misconception"
var collective_reasoning := "the group thinks 1/8 is bigger than 1/4 because 8 > 4"
var scenario_context: Dictionary = {}

var understanding := 0.2
var participation := 0.3
var revealed := false
var _busy := false
var _done := false

var _http: HTTPRequest
var _layer: Control
var _u_bar: ColorRect
var _p_bar: ColorRect
var _status_lbl: Label
var _dialogue: Label
var _coach: Label
var _member_box: HBoxContainer
var _buttons: Array = []

func setup(data: Dictionary) -> void:
	if data.has("members") and not (data["members"] as Array).is_empty():
		members = data["members"]
	shared_concept = str(data.get("shared_concept", shared_concept))
	collective_status = str(data.get("collective_status", collective_status))
	collective_reasoning = str(data.get("collective_reasoning", collective_reasoning))
	scenario_context = data.get("scenario_context", {})
	if is_inside_tree() and _member_box != null:
		_populate_members()
		_refresh()

func _ready() -> void:
	if members.is_empty():
		members = [{"persona_id": "talia_dominator", "name": "Talia", "talkativeness": 0.9},
			{"persona_id": "sam_withdrawn", "name": "Sam", "talkativeness": 0.2},
			{"persona_id": "noah_g5_fractions", "name": "Noah", "talkativeness": 0.4}]
	_http = HTTPRequest.new()
	_http.timeout = 16.0
	add_child(_http)
	_http.request_completed.connect(_on_reply)
	_build_ui()
	_refresh()
	_set_dialogue("You crouch by the table. The group is mid-task. Sample them: observe first, then surface their thinking.")
	_set_coach("Coach Vee: this is monitoring, not a duel. Listen, surface, press, rebalance - then move to the next pod.")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_layer = Control.new()
	add_child(_layer)

	var title := _label("Group check-in  -  %s" % shared_concept, Vector2(20, 14), 18, Color(0.96, 0.86, 0.55))
	title.size = Vector2(900, 22)

	# member portraits + participation cue (populated by _populate_members; rebuilt on setup)
	_member_box = HBoxContainer.new()
	_member_box.position = Vector2(20, 48)
	_member_box.add_theme_constant_override("separation", 16)
	_layer.add_child(_member_box)
	_populate_members()

	# group state bars (below the member portraits row, which ends ~y170)
	_status_lbl = _label("Status: hidden (observe or probe to surface it)", Vector2(20, 188), 13, Color(0.8, 0.84, 0.9))
	_status_lbl.size = Vector2(920, 16)
	_label("Group understanding", Vector2(20, 214), 12, Color(0.86, 0.9, 0.96)).size = Vector2(210, 14)
	_u_bar = _bar(Vector2(250, 216), Color(0.35, 0.78, 0.42))
	_label("Participation balance", Vector2(20, 238), 12, Color(0.86, 0.9, 0.96)).size = Vector2(210, 14)
	_p_bar = _bar(Vector2(250, 240), Color(0.55, 0.72, 0.95))

	# dialogue + coach (their own clear band)
	var dialogue_box := Rect2(Vector2(16, 264), Vector2(928, 76))
	var dialogue_text := Rect2(Vector2(28, 276), Vector2(904, 48))
	var dbg := ColorRect.new()
	dbg.name = "DialogueBubble"
	dbg.position = dialogue_box.position
	dbg.size = dialogue_box.size
	dbg.color = Color(0.10, 0.13, 0.23, 0.88)
	dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(dbg)
	_dialogue = _label("", dialogue_text.position, 15, Color(0.97, 0.97, 0.93))
	_dialogue.name = "DialogueText"
	_dialogue.size = dialogue_text.size
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.set_meta("qa_container_rect", dialogue_box)
	_dialogue.set_meta("qa_text_rect", dialogue_text)
	_dialogue.set_meta("qa_min_padding", 8.0)
	_coach = _label("", Vector2(20, 346), 12, Color(0.62, 0.86, 0.62))
	_coach.size = Vector2(920, 44)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# moves
	var x := 20.0
	for mv in MOVES:
		var b := Button.new()
		b.text = mv[0]
		b.position = Vector2(x, 402)
		b.size = Vector2(170, 42)
		b.pressed.connect(_on_move.bind(mv[1]))
		_layer.add_child(b)
		_buttons.append(b)
		x += 178

func _populate_members() -> void:
	if _member_box == null:
		return
	for c in _member_box.get_children():
		c.queue_free()
	for m in members:
		var col := VBoxContainer.new()
		var tex := Art.tex("res://assets/portraits/%s_neutral.png" % m.get("persona_id", ""))
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(72, 72)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # cap to the box, don't grow to 128
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			col.add_child(tr)
		var nm := Label.new()
		nm.text = str(m.get("name", "?"))
		nm.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(nm)
		_member_box.add_child(col)

func _on_move(tag: String) -> void:
	if _busy or _done:
		return
	if tag == "move_on":
		_leave()
		return
	_busy = true
	var payload := {
		"session_id": "grp",
		"members": members,
		"shared_concept": shared_concept,
		"collective_status": collective_status,
		"collective_reasoning": collective_reasoning,
		"scenario_context": scenario_context,
		"group_state": {"understanding": understanding, "participation_balance": participation, "revealed": revealed},
		"teacher_move": {"menu_tag": tag},
		"model_profile": "openrouter_gemini",
	}
	var ep := LLMClient.endpoint.replace("/turn", "/group_turn")
	var err := _http.request(ep, PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_busy = false
		_local_fallback(tag)

func _on_reply(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_local_fallback("observe")
		return
	var resp = JSON.parse_string(body.get_string_from_utf8())
	if typeof(resp) != TYPE_DICTIONARY:
		return
	var j: Dictionary = resp.get("judge", {})
	_apply(j)
	var u: Dictionary = resp.get("group_utterance", {})
	_set_dialogue("%s (group): \"%s\"" % [str(u.get("speaker", "Group")), str(u.get("text", "..."))])
	_speak_group_line(str(u.get("speaker", "Group")), str(u.get("text", "")), str(u.get("emotion_shown", "thinking")))
	_set_coach("Coach Vee: " + str(resp.get("coach_tip", "")))
	# telemetry/ECD: log the monitoring move under its group construct
	var tag: String = str(j.get("move_tag", ""))
	Telemetry.log_event({"event": "group_turn", "move": tag, "construct_id": str(j.get("construct", "")),
		"targets": bool(j.get("targets", false)), "understanding": understanding, "participation": participation})
	if "current_scenario_id" in Game:
		Competency.observe_group(tag, bool(j.get("targets", false)))
	_refresh()
	_check_win()

func _apply(j: Dictionary) -> void:
	understanding = clampf(understanding + float(j.get("understanding_delta", 0.0)), 0.0, 1.0)
	participation = clampf(participation + float(j.get("participation_delta", 0.0)), 0.0, 1.0)
	if bool(j.get("reveal", false)):
		revealed = true

func _local_fallback(tag: String) -> void:
	# offline: apply deterministic group effects so the mode still plays
	match tag:
		"observe": revealed = true
		"probe": revealed = true; understanding = clampf(understanding + 0.03, 0, 1)
		"press": if revealed: understanding = clampf(understanding + 0.12, 0, 1)
		"redistribute": participation = clampf(participation + 0.2, 0, 1); understanding = clampf(understanding + 0.02, 0, 1)
	_set_dialogue("(group keeps working)")
	_refresh()
	_check_win()

func _check_win() -> void:
	if understanding >= 0.7 and participation >= 0.6:
		_done = true
		for b in _buttons:
			b.disabled = true
		_set_dialogue("This pod is on track - they reasoned past their shared error AND everyone is in it.")
		_set_coach("Coach Vee: you surfaced their thinking, pressed the crack, and rebalanced the talk. That is monitoring done right.")
		var t := get_tree().create_timer(3.2)
		await t.timeout
		_leave()

func _leave() -> void:
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _refresh() -> void:
	if _u_bar != null:
		_u_bar.size.x = 220.0 * understanding
	if _p_bar != null:
		_p_bar.size.x = 220.0 * participation
	if _status_lbl != null:
		_status_lbl.text = ("Status: %s  (concept: %s)" % [collective_status, shared_concept]) if revealed else "Status: hidden (observe or probe to surface it)"

func _label(txt: String, pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	_layer.add_child(l)
	return l

func _bar(pos: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = pos
	bg.size = Vector2(220, 12)
	bg.color = Color(0, 0, 0, 0.5)
	_layer.add_child(bg)
	var fill := ColorRect.new()
	fill.position = pos
	fill.size = Vector2(0, 12)
	fill.color = col
	_layer.add_child(fill)
	return fill

func _set_dialogue(t: String) -> void:
	if _dialogue != null:
		_dialogue.text = t

func _set_coach(t: String) -> void:
	if _coach != null:
		_coach.text = t

func _speak_group_line(speaker: String, text: String, emotion: String = "thinking") -> void:
	if text.strip_edges() == "":
		return
	var pid := _persona_id_for_speaker(speaker)
	if pid != "":
		TTSClient.speak(pid, text, emotion)

func _persona_id_for_speaker(speaker: String) -> String:
	var clean := speaker.strip_edges().to_lower()
	for m in members:
		if str(m.get("name", "")).strip_edges().to_lower() == clean:
			return str(m.get("persona_id", ""))
	if not members.is_empty():
		return str((members[0] as Dictionary).get("persona_id", ""))
	return ""

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_leave()
