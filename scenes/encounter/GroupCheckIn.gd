extends Control
const GroupDebriefPanel = preload("res://scenes/encounter/GroupDebriefPanel.gd")
const GroupCheckInUi = preload("res://scenes/encounter/GroupCheckInUi.gd")
const ReactionCue = preload("res://scenes/encounter/ReactionCue.gd")
## Group check-in: a DISTINCT mechanic from the 1:1 encounter. You sample a pod, reveal
## its hidden collective state (observe/probe), press the group's shared reasoning, and
## rebalance who participates (redistribute) - breadth + group dynamics, then move on.
## Backend: POST /group_turn (collective LLM utterance + monitoring judge).

var members: Array = []          # [{persona_id,name,talkativeness}]
var shared_concept := "comparing fractions"
var collective_status := "shared_misconception"
var collective_reasoning := "the group thinks 1/8 is bigger than 1/4 because 8 > 4"
var scenario_context: Dictionary = {}
var target_badge := ""

var understanding := 0.2
var participation := 0.3
var revealed := false
var _busy := false
var _done := false
var _pending_move_tag := ""

var _http: HTTPRequest
var _layer: Control
var _u_bar: ColorRect
var _p_bar: ColorRect
var _status_lbl: Label
var _dialogue: Label
var _coach: Label
var _member_box: HBoxContainer
var _reaction_cue: Control
var _buttons: Array = []
var _move_history: Array = []

func setup(data: Dictionary) -> void:
	if data.has("members") and not (data["members"] as Array).is_empty():
		members = data["members"]
	shared_concept = str(data.get("shared_concept", shared_concept))
	collective_status = str(data.get("collective_status", collective_status))
	collective_reasoning = str(data.get("collective_reasoning", collective_reasoning))
	scenario_context = data.get("scenario_context", {})
	target_badge = str(data.get("badge", scenario_context.get("badge", target_badge)))
	_apply_adaptive_difficulty()
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
	_apply_adaptive_difficulty()
	_refresh()
	_set_dialogue("You crouch by the table. The group is mid-task. Sample them: observe first, then surface their thinking.")
	_set_coach("Coach Vee: button order: Observe/Probe to reveal, Press after the error is visible, Redistribute when one voice dominates.")

func _apply_adaptive_difficulty() -> void:
	var d := Game.adaptive_difficulty(["group_monitoring", "formative_check", "status_treatment"])
	var level := str(d.get("level", "standard"))
	if level == "scaffold":
		understanding = clampf(maxf(understanding, 0.26), 0.0, 1.0)
		participation = clampf(maxf(participation, 0.38), 0.0, 1.0)
	elif level == "challenge":
		understanding = clampf(minf(understanding, 0.16), 0.0, 1.0)
		participation = clampf(minf(participation, 0.24), 0.0, 1.0)

func _build_ui() -> void:
	var refs := GroupCheckInUi.build(self, shared_concept, members, understanding, participation, revealed, Callable(self, "_on_move"))
	_layer = refs["layer"]
	_member_box = refs["member_box"]
	_status_lbl = refs["status_lbl"]
	_reaction_cue = refs["reaction_cue"]
	_u_bar = refs["u_bar"]
	_p_bar = refs["p_bar"]
	_dialogue = refs["dialogue"]
	_coach = refs["coach"]
	_buttons = refs["buttons"]

func _populate_members() -> void:
	if _member_box == null:
		return
	GroupCheckInUi.populate_members(_member_box, members)

func _on_move(tag: String) -> void:
	if _busy or _done:
		return
	if tag == "move_on":
		_leave()
		return
	_busy = true
	_pending_move_tag = tag
	if LLMClient.use_stub:
		_busy = false
		_pending_move_tag = ""
		_local_fallback(tag)
		return
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
		_pending_move_tag = ""
		_local_fallback(tag)

func _on_reply(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var requested_tag := _pending_move_tag
	_pending_move_tag = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_local_fallback(requested_tag if requested_tag != "" else "observe")
		return
	var resp = JSON.parse_string(body.get_string_from_utf8())
	if typeof(resp) != TYPE_DICTIONARY:
		_local_fallback(requested_tag if requested_tag != "" else "observe")
		return
	var j: Dictionary = resp.get("judge", {})
	_apply(j)
	var u: Dictionary = resp.get("group_utterance", {})
	_set_dialogue("%s (group): \"%s\"" % [str(u.get("speaker", "Group")), str(u.get("text", "..."))])
	_speak_group_line(str(u.get("speaker", "Group")), str(u.get("text", "")), str(u.get("emotion_shown", "thinking")))
	# telemetry/ECD: log the monitoring move under its group construct
	var tag: String = str(j.get("move_tag", requested_tag))
	var next_hint := _group_button_hint(tag, bool(j.get("targets", false)))
	_set_coach("Coach Vee: %s %s" % [str(resp.get("coach_tip", "")), next_hint])
	_move_history.append({"turn": _move_history.size() + 1, "tag": tag, "targets": bool(j.get("targets", false)), "construct": str(j.get("construct", "")),
		"reaction": str(u.get("text", "")), "meter": "Understanding %d%% | Participation %d%%" % [int(round(understanding * 100.0)), int(round(participation * 100.0))]})
	Telemetry.log_event({"event": "group_turn", "move": tag, "construct_id": str(j.get("construct", "")),
		"targets": bool(j.get("targets", false)), "understanding": understanding, "participation": participation,
		"student_text": str(u.get("text", "")), "speaker": str(u.get("speaker", "Group")),
		"emotion_shown": str(u.get("emotion_shown", ""))})
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
	var productive := tag == "observe" or tag == "probe" or tag == "redistribute" or (tag == "press" and revealed)
	match tag:
		"observe": revealed = true
		"probe": revealed = true; understanding = clampf(understanding + 0.03, 0, 1)
		"press": if revealed: understanding = clampf(understanding + 0.12, 0, 1)
		"redistribute": participation = clampf(participation + 0.2, 0, 1); understanding = clampf(understanding + 0.02, 0, 1)
	_set_dialogue("(group keeps working)")
	_set_coach("Coach Vee: %s" % _group_button_hint(tag, productive))
	_move_history.append({"turn": _move_history.size() + 1, "tag": tag, "targets": productive, "construct": Competency.GROUP_TAG_SKILL.get(tag, ""),
		"reaction": "(group keeps working)", "meter": "Understanding %d%% | Participation %d%%" % [int(round(understanding * 100.0)), int(round(participation * 100.0))]})
	Telemetry.log_event({"event": "group_turn", "move": tag, "construct_id": Competency.GROUP_TAG_SKILL.get(tag, ""),
		"targets": productive, "understanding": understanding, "participation": participation, "offline": true,
		"student_text": "(group keeps working)"})
	Competency.observe_group(tag, productive)
	_refresh()
	_check_win()

func _group_button_hint(tag: String, productive: bool) -> String:
	if not revealed:
		return "Next: press Observe or Probe before Press."
	if tag == "press" and productive:
		return "Next: press Redistribute if participation is low, otherwise Press again."
	if participation < 0.6:
		return "Next: press Redistribute to balance airtime."
	if understanding < 0.7:
		return "Next: press Press to work the shared error."
	return "Next: Move On."

func _check_win() -> void:
	if understanding >= 0.7 and participation >= 0.6:
		_done = true
		for b in _buttons:
			b.disabled = true
		_set_dialogue("This pod is on track - they reasoned past their shared error AND everyone is in it.")
		_set_coach("Coach Vee: you surfaced their thinking, pressed the crack, and rebalanced the talk. That is monitoring done right.")
		var score := _group_score()
		var reward := {}
		if target_badge != "":
			reward = GameState.award_badge(target_badge)
			Sfx.play("badge")
		var run_record := GameState.record_leaderboard({
			"scenario_id": str(scenario_context.get("id", Game.current_scenario_id)),
			"title": _scenario_title(),
			"mode": "Group",
			"badge": target_badge,
			"score": score,
			"detail": "Understanding %d%%  Participation %d%%" % [int(round(understanding * 100.0)), int(round(participation * 100.0))],
			"level_up": bool(reward.get("level_up", false)),
			"trace": Game.evidence_trace_from_moves(_move_history),
			"trace_steps": Game.evidence_trace_steps_from_moves(_move_history),
		})
		Telemetry.log_event({"event": "group_resolve", "scenario_id": str(scenario_context.get("id", Game.current_scenario_id)),
			"won": true, "understanding": understanding, "participation": participation})
		Telemetry.upload_competency()
		Telemetry.flush()
		_show_complete_panel(run_record, reward)

func _show_complete_panel(run_record: Dictionary, reward: Dictionary) -> void:
	for b in _buttons:
		b.visible = false
	if _dialogue != null:
		_dialogue.visible = false
	if _coach != null:
		_coach.visible = false
	GroupDebriefPanel.show(_layer, run_record, reward, {
		"score": _group_score(),
		"target_badge": target_badge,
		"understanding": understanding,
		"participation": participation,
	}, Callable(self, "_leave"))

func _group_score() -> int:
	return int(round(understanding * 140.0 + participation * 120.0))

func _scenario_title() -> String:
	return str(scenario_context.get("title", shared_concept))

func _leave() -> void:
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _refresh() -> void:
	if _u_bar != null:
		_u_bar.size.x = 220.0 * understanding
	if _p_bar != null:
		_p_bar.size.x = 220.0 * participation
	if _status_lbl != null:
		_status_lbl.text = ("Status: %s  (concept: %s)  |  Next: press Press or Redistribute" % [collective_status, shared_concept]) if revealed else "Status: hidden  |  Next: press Observe or Probe"
	if _layer != null:
		_reaction_cue = ReactionCue.show_group_cue(_layer, _reaction_cue, Vector2(536, 212), understanding, participation, revealed)

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
