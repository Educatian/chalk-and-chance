extends RefCounted

static func scenario_signature(cfg: Dictionary) -> String:
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
	return "Signature: whole-room orchestration plus differentiated student reasoning."

static func scenario_edge_label(cfg: Dictionary) -> String:
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

static func practice_recommendation(scenarios: Array) -> String:
	var next := _next_open_scenario_title(scenarios)
	var weakest := _weakest_with_evidence()
	if weakest.is_empty():
		return "Adaptive coach: start with %s. First target: generate evidence for wait-time, equity, and reasoning moves." % next
	return "Adaptive coach: next play %s. Focus on %s; current estimate %d%% from %d evidence events." % [
		next,
		str(weakest.get("label", weakest.get("skill", "practice focus"))),
		int(round(float(weakest.get("prob", 0.5)) * 100.0)),
		int(weakest.get("n", 0)),
	]

static func adaptive_difficulty(skills: Array) -> Dictionary:
	var total_weight := 0.0
	var weighted_prob := 0.0
	var evidence := 0
	for skill in skills:
		var sid := str(skill)
		var count := int(Competency.n.get(sid, 0))
		if count <= 0:
			continue
		var weight := float(mini(count, 12))
		total_weight += weight
		weighted_prob += Competency.prob(sid) * weight
		evidence += count
	if evidence < 3 or total_weight <= 0.0:
		return adaptive_level_for(0.5, evidence)
	var p := weighted_prob / total_weight
	return adaptive_level_for(p, evidence)

static func adaptive_level_for(prob: float, evidence: int) -> Dictionary:
	if evidence < 3:
		return {"level": "standard", "prob": prob, "evidence": evidence, "meter": 0.0, "threshold": 0.0}
	if prob < 0.45:
		return {"level": "scaffold", "prob": prob, "evidence": evidence, "meter": 1.0, "threshold": -1.0}
	if prob > 0.72:
		return {"level": "challenge", "prob": prob, "evidence": evidence, "meter": -1.0, "threshold": 1.0}
	return {"level": "standard", "prob": prob, "evidence": evidence, "meter": 0.0, "threshold": 0.0}

static func adaptive_difficulty_label(d: Dictionary) -> String:
	var level := str(d.get("level", "standard"))
	if level == "scaffold":
		return "Adaptive: scaffold start"
	if level == "challenge":
		return "Adaptive: challenge start"
	return "Adaptive: standard start"

static func evidence_trace_from_moves(moves: Array, limit: int = 6) -> String:
	var parts: Array = []
	for step in evidence_trace_steps_from_moves(moves, limit):
		parts.append(str(step.get("summary", "")))
	return " | ".join(parts)

static func evidence_trace_steps_from_moves(moves: Array, limit: int = 6) -> Array:
	var steps: Array = []
	if moves.is_empty():
		return steps
	var start := maxi(0, moves.size() - limit)
	for i in range(start, moves.size()):
		var m = moves[i]
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var tag := str(m.get("tag", ""))
		if tag == "":
			continue
		var skill := str(m.get("construct", ""))
		if skill == "":
			skill = str(Competency.TAG_SKILL.get(tag, Competency.GROUP_TAG_SKILL.get(tag, "")))
		var ok := bool(m.get("targets", false))
		var summary := "%s>%s%s" % [_compact_move_label(tag), _compact_skill_label(skill, skill), "+" if ok else "-"]
		steps.append({
			"turn": int(m.get("turn", i + 1)),
			"move": _compact_move_label(tag),
			"construct": _compact_skill_label(skill, skill),
			"outcome": "evidence gained" if ok else "missed evidence",
			"signal": str(m.get("reaction_signal", _reaction_signal_for_trace(tag, ok, str(m.get("reaction", ""))))),
			"reaction": str(m.get("reaction", _trace_reaction_text(tag, ok))),
			"meter": str(m.get("meter", "")),
			"summary": summary,
		})
	return steps

static func evidence_practice_target(verbose := true) -> String:
	var rows := Competency.summary()
	var target := {}
	for r in rows:
		if int(r.get("n", 0)) > 0 and (target.is_empty() or float(r.get("prob", 0.5)) < float(target.get("prob", 0.5))):
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

static func _weakest_with_evidence() -> Dictionary:
	var weakest := {}
	for r in Competency.summary():
		if int(r.get("n", 0)) <= 0:
			continue
		if weakest.is_empty() or float(r.get("prob", 0.5)) < float(weakest.get("prob", 0.5)):
			weakest = r
	return weakest

static func _reaction_signal_for_trace(tag: String, ok: bool, reaction: String) -> String:
	var text := reaction.to_lower()
	if ok:
		if tag == "wait":
			return "productive pause: more learners can enter"
		if tag == "connect":
			return "rapport bridge: learner trust becomes usable evidence"
		if tag == "redistribute":
			return "airtime balanced: quieter voices become visible"
		if text.find("not sure") >= 0 or text.find("confused") >= 0:
			return "confusion surfaced: misconception is now teachable"
		return "fit signal: the move matched the learning need"
	if tag == "tell":
		return "takeover risk: answer-giving reduced learner reasoning"
	if tag == "press":
		return "pressure mistimed: press before shared reasoning stabilized"
	return "mismatch signal: choose a smaller or better-timed move"

static func _trace_reaction_text(tag: String, ok: bool) -> String:
	if ok:
		return "The move fit the teaching need."
	if tag == "tell":
		return "Telling moved faster than the learner's reasoning."
	return "The move did not match the strongest need yet."

static func _compact_move_label(tag: String) -> String:
	return {
		"elicit": "Elicit", "extend": "Extend", "revoice": "Revoice", "tell": "Tell",
		"praise": "Praise", "connect": "Connect", "redirect": "Redirect", "wait": "Wait",
		"present": "Present", "ask": "Question", "reexplain": "Repair", "poll": "Check",
		"observe": "Observe", "probe": "Probe", "press": "Press", "redistribute": "Redistribute",
	}.get(tag, tag.capitalize())

static func _practice_move_for(skill: String, verbose: bool) -> String:
	var verbose_moves := {
		"elicit_reasoning": "ask the learner to explain their reasoning before you evaluate it",
		"extend_thinking": "press for a second representation or a why-because explanation",
		"revoicing": "make the student's idea public in your own words, then check it",
		"wait_time": "pause before prompting again so the next response is earned",
		"behavior_mgmt": "use proximity or a quiet redirect before escalating",
		"restraint": "avoid taking over; cue the next step instead of telling the answer",
		"behavior_specific_praise": "name the exact productive behavior you want repeated",
		"funds_of_knowledge": "connect the task to a learner asset or lived example",
		"group_monitoring": "observe the pod before intervening so you know the shared error",
		"formative_check": "ask for a quick sample of thinking, not a yes/no check",
		"status_treatment": "redistribute airtime to a quieter learner with competence",
	}
	var compact_moves := {
		"elicit_reasoning": "why?", "extend_thinking": "new model", "revoicing": "revoice then check",
		"wait_time": "hold the pause", "behavior_mgmt": "quiet cue", "restraint": "cue, do not tell",
		"behavior_specific_praise": "specific praise", "funds_of_knowledge": "asset link",
		"group_monitoring": "observe", "formative_check": "quick sample", "status_treatment": "rebalance airtime",
	}
	return str((verbose_moves if verbose else compact_moves).get(skill, "produce visible evidence"))

static func _compact_skill_label(skill: String, fallback: String) -> String:
	return {
		"elicit_reasoning": "Eliciting", "extend_thinking": "Extending", "revoicing": "Revoicing",
		"wait_time": "Wait-time", "behavior_mgmt": "Mgmt", "restraint": "Restraint",
		"behavior_specific_praise": "Praise", "funds_of_knowledge": "Asset connect",
		"group_monitoring": "Monitoring", "formative_check": "Formative check",
		"status_treatment": "Status treatment",
	}.get(skill, fallback)

static func _next_open_scenario_title(scenarios: Array) -> String:
	for id in scenarios:
		var cfg := _load_scenario_cfg(str(id))
		if cfg.is_empty():
			continue
		var badge := str(cfg.get("badge", ""))
		var req := str(cfg.get("requires", ""))
		if badge != "" and GameState.has_badge(badge):
			continue
		if req == "" or GameState.has_badge(req):
			return str(cfg.get("title", id))
	return "the capstone replay"

static func _load_scenario_cfg(id: String) -> Dictionary:
	var path := Game.scenario_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}
