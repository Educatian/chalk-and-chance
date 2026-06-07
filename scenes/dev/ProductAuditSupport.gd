extends RefCounted

static func reset_state() -> void:
	LLMClient.use_stub = true
	TTSClient.enabled = false
	Auth.token = ""
	Auth.user_id = ""
	Auth.display_name = ""
	Auth.class_code = ""
	Auth.role = ""
	Auth.api_base = ""
	GameState.badges = []
	GameState.attempts = {}
	GameState.relationships = {}
	GameState.teacher_xp = 260
	GameState.teacher_level = 2
	GameState.upgrade_points = 1
	GameState.leaderboard_records = [
		{"rank": "A", "score": 236, "title": "Intro to Fractions", "detail": "Comp 85%  Attention 91%  Progress 100%", "level_up": true,
			"coach_focus": "Formative check 46%", "coach_next": "Practice: Formative 46% -> Check before presenting again",
			"evidence_trace": "Present>Restraint+ | Check>Formative+",
			"evidence_trace_steps": [
				{"turn": 1, "move": "Present", "construct": "Restraint", "outcome": "evidence gained", "signal": "fit signal: the move matched the learning need", "reaction": "Class stayed with the chunk.", "meter": "Progress 42% | Attention 88%"},
				{"turn": 2, "move": "Check", "construct": "Formative", "outcome": "evidence gained", "signal": "confusion surfaced: misconception is now teachable", "reaction": "Two students named the unit split.", "meter": "Progress 70% | Attention 91%"},
			]},
		{"rank": "B", "score": 196, "title": "Comparing Decimals", "detail": "Objectives 2/2  Attention 78%  Engaged 6/6", "level_up": false,
			"coach_focus": "Funds of knowledge 40%", "coach_next": "Practice: Asset connect 40% -> Connect to learner asset",
			"evidence_trace": "Elicit>Eliciting+ | Tell>Restraint-"},
	]
	seed_competencies()
	Game.clear_lesson()

static func sample_trace_record() -> Dictionary:
	return {
		"rank": "A", "score": 236, "title": "Intro to Fractions",
		"coach_focus": "Formative check 46%",
		"coach_next": "Practice: Formative 46% -> Check before presenting again",
		"evidence_trace": "Present>Restraint+ | Check>Formative+",
		"evidence_trace_steps": [
			{"turn": 1, "move": "Present", "construct": "Restraint", "outcome": "evidence gained", "signal": "fit signal: the move matched the learning need", "reaction": "Class stayed with the chunk.", "meter": "Progress 42% | Attention 88%"},
			{"turn": 2, "move": "Check", "construct": "Formative", "outcome": "evidence gained", "signal": "confusion surfaced: misconception is now teachable", "reaction": "Two students named the unit split.", "meter": "Progress 70% | Attention 91%"},
		],
	}

static func seed_competencies() -> void:
	for s in Competency.SKILLS:
		Competency.theta[s] = 0.0
		Competency.n[s] = 0.0
	var sample := {
		"wait_time": {"theta": 1.05, "n": 9.0},
		"elicit_reasoning": {"theta": 0.72, "n": 7.0},
		"revoicing": {"theta": 0.44, "n": 6.0},
		"behavior_mgmt": {"theta": 0.18, "n": 5.0},
		"formative_check": {"theta": -0.15, "n": 4.0},
		"funds_of_knowledge": {"theta": -0.42, "n": 3.0},
	}
	for k in sample.keys():
		Competency.theta[k] = float(sample[k]["theta"])
		Competency.n[k] = float(sample[k]["n"])

static func assert_text_issues(label: String, root: Node, needles: Array) -> Array:
	var issues: Array = []
	var text := visible_text(root).to_lower()
	for needle in needles:
		var n := str(needle).to_lower()
		if text.find(n) == -1:
			issues.append("%s missing text: %s | visible=%s" % [label, str(needle), truncate(text, 220)])
	return issues

static func label_overlap_issues(label: String, root: Node, group_a: Array, group_b: Array) -> Array:
	var issues: Array = []
	var labels: Array = []
	_collect_labels(root, labels)
	for a in labels:
		if not _label_matches(a, group_a):
			continue
		for b in labels:
			if a == b or not _label_matches(b, group_b):
				continue
			var ar: Rect2 = a.get_global_rect()
			var br: Rect2 = b.get_global_rect()
			if ar.intersects(br) and ar.intersection(br).get_area() > 18.0:
				issues.append("%s text overlap: %s with %s" % [label, truncate(a.text, 64), truncate(b.text, 64)])
	return issues

static func find_named(root: Node, node_name: String) -> Node:
	if str(root.name) == node_name:
		return root
	for ch in root.get_children():
		var found := find_named(ch, node_name)
		if found != null:
			return found
	return null

static func visible_text(root: Node) -> String:
	var parts: Array = []
	_collect_text(root, parts)
	return " ".join(parts).replace("\n", " ").replace("\t", " ").strip_edges()

static func prepare_overworld_clear(sc: Node) -> void:
	sc._composure = 92.0
	sc._disruptions = 0
	for st in sc._npcs.keys():
		sc._npcs[st]["offtask"] = 0.0
		Game.note_visit(str(sc._npcs[st].get("persona_id", "")))
	Game.log_move("wait", true, true)
	Game.log_move("connect", true, true)
	if sc._objective_label != null:
		sc._objective_label.text = sc._objectives_status(100.0)
	if sc._attention_fill != null:
		sc._attention_fill.size = Vector2(216.0, 12.0)
	if sc._composure_fill != null:
		sc._composure_fill.size = Vector2(156.0 * sc._composure / GameState.max_composure(), 10.0)

static func overworld_trace_issue() -> String:
	for rec in GameState.leaderboard_records:
		if str(rec.get("scenario_id", "")) != "independent_fractions":
			continue
		var steps = rec.get("evidence_trace_steps", [])
		if str(rec.get("evidence_trace", "")) == "" or typeof(steps) != TYPE_ARRAY or steps.is_empty():
			return "Overworld leaderboard record did not save trace detail"
		return ""
	return "Overworld leaderboard record missing"

static func adaptive_semantic_issues() -> Array:
	var issues: Array = []
	var skills := ["wait_time", "elicit_reasoning", "behavior_mgmt"]
	seed_competencies()
	for skill in skills:
		Competency.theta[skill] = -2.0
		Competency.n[skill] = 4.0
	var low := Game.adaptive_difficulty(skills)
	if str(low.get("level", "")) != "scaffold":
		issues.append("Adaptive semantic check expected scaffold for low mastery, got %s" % str(low.get("level", "")))
	for skill in skills:
		Competency.theta[skill] = 2.0
		Competency.n[skill] = 4.0
	var high := Game.adaptive_difficulty(skills)
	if str(high.get("level", "")) != "challenge":
		issues.append("Adaptive semantic check expected challenge for high mastery, got %s" % str(high.get("level", "")))
	for skill in skills:
		Competency.n[skill] = 0.0
	var empty := Game.adaptive_difficulty(skills)
	if str(empty.get("level", "")) != "standard" or int(empty.get("evidence", -1)) != 0:
		issues.append("Adaptive semantic check expected standard with no evidence")
	var ladder := [
		Game.adaptive_level_for(0.50, 0),
		Game.adaptive_level_for(0.32, 3),
		Game.adaptive_level_for(0.82, 3),
	]
	if str(ladder[0].get("level", "")) != "standard" or str(ladder[1].get("level", "")) != "scaffold" or str(ladder[2].get("level", "")) != "challenge":
		issues.append("Adaptive replay ladder expected standard/scaffold/challenge")
	seed_competencies()
	return issues

static func json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 3) + "..."

static func _collect_text(n: Node, parts: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		var l := n as Label
		if l.text.strip_edges() != "":
			parts.append(l.text)
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		if r.text.strip_edges() != "":
			parts.append(r.text)
	elif n is Button:
		var b := n as Button
		if b.text.strip_edges() != "":
			parts.append(b.text)
	elif n is LineEdit:
		var e := n as LineEdit
		if e.text.strip_edges() != "":
			parts.append(e.text)
	elif n is TextEdit:
		var t := n as TextEdit
		if t.text.strip_edges() != "":
			parts.append(t.text)
	for ch in n.get_children():
		_collect_text(ch, parts)

static func _collect_labels(n: Node, labels: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		labels.append(n)
	for ch in n.get_children():
		_collect_labels(ch, labels)

static func _label_matches(label: Label, needles: Array) -> bool:
	var text := label.text.to_lower()
	for needle in needles:
		if text.find(str(needle).to_lower()) != -1:
			return true
	return false
