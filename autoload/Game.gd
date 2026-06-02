extends Node
## Tiny global holding which scenario the overworld should load. A mission-select hub will
## set this later; for now keys 1/2 in the overworld switch scenes for testing.

var current_scenario_id := "discussion_fractions"

## Persistent in-period lesson state so the period, composure, off-task and equity carry
## across the overworld<->encounter scene swaps (a lesson is one continuous period).
## Keyed by persona_id. Empty/active=false means "start a fresh period".
var lesson := {}

## Resolve a scenario id to its file: built-ins in res://, imported customs in user://.
func scenario_path(id: String) -> String:
	var r := "res://data/scenarios/%s.json" % id
	if FileAccess.file_exists(r):
		return r
	return "user://scenarios/%s.json" % id

func start_lesson(scenario_id: String, period_seconds: float) -> void:
	lesson = {
		"active": true, "scenario_id": scenario_id,
		"period_left": period_seconds, "composure": GameState.max_composure(), "disruptions": 0,
		"offtask": {}, "visited": {}, "moves": [],
	}

func clear_lesson() -> void:
	lesson = {}

func lesson_active(scenario_id: String) -> bool:
	return lesson.get("active", false) and lesson.get("scenario_id", "") == scenario_id

## Record that a student was engaged (called on) and log a teaching move for scoring.
func note_visit(persona_id: String) -> void:
	if not lesson.get("active", false):
		return
	var v: Dictionary = lesson.get("visited", {})
	v[persona_id] = int(v.get(persona_id, 0)) + 1
	lesson["visited"] = v

func log_move(tag: String, wait_ok: bool, targets: bool) -> void:
	if not lesson.get("active", false):
		return
	var m: Array = lesson.get("moves", [])
	m.append({"tag": tag, "wait_ok": wait_ok, "targets": targets})
	lesson["moves"] = m

## Missions shown in the select hub, in order.
const SCENARIOS := [
	"discussion_fractions",
	"lecture_fractions",
	"group_work_fractions",
	"independent_fractions",
	"reading_main_idea",
	"science_force_motion",
	"culturally_responsive_intro",
	"gym_capstone",
]

## One-line research/gameplay signature for mission cards and lesson previews.
## The point is to foreground Chalk & Chance's edge over avatar-only rehearsal:
## classroom orchestration, differentiated student needs, and construct-level evidence.
func scenario_signature(cfg: Dictionary) -> String:
	var mode := str(cfg.get("mode", "overworld"))
	var fmt := str(cfg.get("format", "discussion"))
	if mode == "gym":
		return "Signature: simultaneous learner triage + competing classroom demands."
	match fmt:
		"lecture":
			return "Signature: pacing, checks for understanding, wait-time, and equity evidence."
		"group_work":
			return "Signature: pod monitoring, shared reasoning, and participation balance."
		"independent":
			return "Signature: circulation, proximity control, and quiet individual conferences."
		_:
			return "Signature: whole-room orchestration plus differentiated student reasoning."

func scenario_edge_label(cfg: Dictionary) -> String:
	var fmt := str(cfg.get("format", "discussion"))
	var objectives: Array = cfg.get("objectives", [])
	var has_equity := false
	var has_wait := false
	for o in objectives:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var metric := str(o.get("metric", ""))
		has_equity = has_equity or metric == "engaged_min"
		has_wait = has_wait or metric == "waittime_min"
	if str(cfg.get("mode", "")) == "gym":
		return "Research edge: not one scripted avatar, but a live multi-student capstone."
	if fmt == "group_work":
		return "Research edge: group-level reasoning and airtime are scored, not just talk quality."
	if fmt == "lecture":
		return "Research edge: lecture rhythm becomes measurable practice, not a monologue."
	if has_equity and has_wait:
		return "Research edge: wait-time, equity, and withitness are measured together."
	return "Research edge: every move leaves a construct-level evidence trace."

func practice_recommendation() -> String:
	var next := _next_open_scenario_title()
	var rows := Competency.summary()
	var weakest := {}
	for r in rows:
		if int(r.get("n", 0)) <= 0:
			continue
		if weakest.is_empty() or float(r.get("prob", 0.5)) < float(weakest.get("prob", 0.5)):
			weakest = r
	if weakest.is_empty():
		return "Adaptive coach: start with %s. First target: generate evidence for wait-time, equity, and reasoning moves." % next
	return "Adaptive coach: next play %s. Focus on %s; current estimate %d%% from %d evidence events." % [
		next,
		str(weakest.get("label", weakest.get("skill", "practice focus"))),
		int(round(float(weakest.get("prob", 0.5)) * 100.0)),
		int(weakest.get("n", 0)),
	]

func evidence_practice_target(verbose := true) -> String:
	var rows := Competency.summary()
	var target := {}
	for r in rows:
		if int(r.get("n", 0)) > 0:
			if target.is_empty() or float(r.get("prob", 0.5)) < float(target.get("prob", 0.5)):
				target = r
	if target.is_empty():
		for r2 in rows:
			if int(r2.get("n", 0)) <= 0:
				target = r2
				break
	if target.is_empty():
		return "Practice target: clear a mission to convert choices into evidence-backed coaching."
	var skill := str(target.get("skill", ""))
	var label := str(target.get("label", skill))
	var move := _practice_move_for(skill, verbose)
	var n := int(target.get("n", 0))
	if n <= 0:
		return "Practice target: collect first evidence for %s. Try: %s." % [label, move]
	var pct := int(round(float(target.get("prob", 0.5)) * 100.0))
	if verbose:
		return "Practice target: %s is the growth edge (%d%%, %d events). Try: %s." % [label, pct, n, move]
	return "Practice: %s %d%% -> %s" % [_compact_skill_label(skill, label), pct, move]

func _practice_move_for(skill: String, verbose: bool) -> String:
	if verbose:
		match skill:
			"elicit_reasoning":
				return "ask the learner to explain their reasoning before you evaluate it"
			"extend_thinking":
				return "press for a second representation or a why-because explanation"
			"revoicing":
				return "make the student's idea public in your own words, then check it"
			"wait_time":
				return "pause before prompting again so the next response is earned"
			"behavior_mgmt":
				return "use proximity or a quiet redirect before escalating"
			"restraint":
				return "avoid taking over; cue the next step instead of telling the answer"
			"behavior_specific_praise":
				return "name the exact productive behavior you want repeated"
			"funds_of_knowledge":
				return "connect the task to a learner asset or lived example"
			"group_monitoring":
				return "observe the pod before intervening so you know the shared error"
			"formative_check":
				return "ask for a quick sample of thinking, not a yes/no check"
			"status_treatment":
				return "redistribute airtime to a quieter learner with competence"
	match skill:
		"elicit_reasoning":
			return "why?"
		"extend_thinking":
			return "new model"
		"revoicing":
			return "revoice then check"
		"wait_time":
			return "hold the pause"
		"behavior_mgmt":
			return "quiet cue"
		"restraint":
			return "cue, do not tell"
		"behavior_specific_praise":
			return "specific praise"
		"funds_of_knowledge":
			return "asset link"
		"group_monitoring":
			return "observe"
		"formative_check":
			return "quick sample"
		"status_treatment":
			return "rebalance airtime"
	return "produce visible evidence"

func _compact_skill_label(skill: String, fallback: String) -> String:
	match skill:
		"elicit_reasoning":
			return "Eliciting"
		"extend_thinking":
			return "Extending"
		"revoicing":
			return "Revoicing"
		"wait_time":
			return "Wait-time"
		"behavior_mgmt":
			return "Mgmt"
		"restraint":
			return "Restraint"
		"behavior_specific_praise":
			return "Praise"
		"funds_of_knowledge":
			return "Asset connect"
		"group_monitoring":
			return "Monitoring"
		"formative_check":
			return "Formative check"
		"status_treatment":
			return "Status treatment"
	return fallback

func _next_open_scenario_title() -> String:
	for id in SCENARIOS:
		var cfg := _load_scenario_cfg(id)
		if cfg.is_empty():
			continue
		var badge := str(cfg.get("badge", ""))
		var req := str(cfg.get("requires", ""))
		if badge != "" and GameState.has_badge(badge):
			continue
		if req == "" or GameState.has_badge(req):
			return str(cfg.get("title", id))
	return "the capstone replay"

func _load_scenario_cfg(id: String) -> Dictionary:
	var path := scenario_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}
