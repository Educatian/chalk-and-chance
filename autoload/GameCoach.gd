extends RefCounted

static func scenario_signature(cfg: Dictionary) -> String:
	var mode := str(cfg.get("mode", "overworld"))
	var fmt := str(cfg.get("format", "discussion"))
	if mode == "gym":
		return "The test: several kids need you at once, and the room won't wait."
	match fmt:
		"lecture":
			return "The test: keep the talking short and keep checking who's with you."
		"group_work":
			return "The test: read each table, and don't let one kid do all the talking."
		"independent":
			return "The test: get up, walk the rows, talk to kids one at a time."
	return "The test: run the room and still hear each student's thinking."

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
		return "Scored: the whole class at once, all of them live."
	if fmt == "group_work":
		return "Scored: how each group reasons, and who gets to talk."
	if fmt == "lecture":
		return "Scored: how often you stop talking and check."
	if has_equity and has_wait:
		return "Scored: how long you wait, who you call on, what you catch."
	return "Scored: each move, against the skill it practices."

static func practice_recommendation(scenarios: Array) -> String:
	var next := _next_open_scenario_title(scenarios)
	var weakest := _weakest_with_evidence()
	if weakest.is_empty():
		return "Start with %s. Wait longer than feels normal, and get everyone talking." % next
	return "Try %s next. Work on %s. You're at %d%% after %d moves." % [
		next,
		str(weakest.get("label", weakest.get("skill", "your weak spot"))),
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
		return "Starting with extra help"
	if level == "challenge":
		return "Starting harder"
	return "Starting at normal"

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
			"outcome": "worked" if ok else "missed",
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
		return "Practice target: finish one mission first. Then you'll get a real one."
	var skill := str(target.get("skill", ""))
	var label := str(target.get("label", skill))
	var move := _practice_move_for(skill, verbose)
	var n := int(target.get("n", 0))
	if n <= 0:
		return "Practice target: you haven't tried %s yet. Try: %s." % [label, move]
	var pct := int(round(float(target.get("prob", 0.5)) * 100.0))
	if verbose:
		return "Practice target: %s is your weakest spot (%d%% after %d moves). Try: %s." % [label, pct, n, move]
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
			return "the pause gave more kids a way in"
		if tag == "connect":
			return "they trust you a little more now"
		if tag == "redistribute":
			return "a quieter kid got the floor"
		if text.find("not sure") >= 0 or text.find("confused") >= 0:
			return "the mix-up came out where you can teach it"
		return "right move for what they needed"
	if tag == "tell":
		return "you gave the answer, so they stopped thinking"
	if tag == "press":
		return "pushed before the group had settled on an idea"
	return "didn't fit yet. Go smaller, or wait a beat"

static func _trace_reaction_text(tag: String, ok: bool) -> String:
	if ok:
		return "That one fit."
	if tag == "tell":
		return "You told them before they'd worked it out."
	return "Not what they needed most right then."

static func _compact_move_label(tag: String) -> String:
	return {
		"elicit": "Elicit", "extend": "Extend", "revoice": "Revoice", "tell": "Tell",
		"praise": "Praise", "connect": "Connect", "redirect": "Redirect", "wait": "Wait",
		"present": "Present", "ask": "Question", "reexplain": "Repair", "poll": "Check",
		"observe": "Observe", "probe": "Probe", "press": "Press", "redistribute": "Redistribute",
	}.get(tag, tag.capitalize())

static func _practice_move_for(skill: String, verbose: bool) -> String:
	var verbose_moves := {
		"elicit_reasoning": "ask how they got it before you say if it's right",
		"extend_thinking": "ask for another way to show it, or a 'because'",
		"revoicing": "say their idea back in your words, then check you got it",
		"wait_time": "after you ask, wait. Longer than feels okay",
		"behavior_mgmt": "walk over or give a quiet cue before anything louder",
		"restraint": "hold the answer back and hint at the next step",
		"behavior_specific_praise": "name exactly what they did that you want again",
		"funds_of_knowledge": "tie the task to something from their own life",
		"group_monitoring": "watch the table first so you know where they're stuck",
		"formative_check": "have a few students show their work. A thumbs-up won't tell you much",
		"status_treatment": "hand the floor to a quiet student who knows their stuff",
	}
	var compact_moves := {
		"elicit_reasoning": "why?", "extend_thinking": "another way", "revoicing": "revoice then check",
		"wait_time": "hold the pause", "behavior_mgmt": "quiet cue", "restraint": "hint, don't tell",
		"behavior_specific_praise": "specific praise", "funds_of_knowledge": "their world",
		"group_monitoring": "watch first", "formative_check": "show me", "status_treatment": "share the floor",
	}
	return str((verbose_moves if verbose else compact_moves).get(skill, "make one move that fits"))

static func _compact_skill_label(skill: String, fallback: String) -> String:
	return {
		"elicit_reasoning": "Eliciting", "extend_thinking": "Extending", "revoicing": "Revoicing",
		"wait_time": "Wait-time", "behavior_mgmt": "Redirects", "restraint": "Restraint",
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
	return "the capstone again"

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
