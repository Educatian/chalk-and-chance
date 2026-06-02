extends Node

var _issues: Array = []

func _ready() -> void:
	LLMClient.use_stub = true
	TTSClient.enabled = false
	GameState.badges = []
	GameState.attempts = {}
	GameState.relationships = {}
	GameState.teacher_xp = 260
	GameState.teacher_level = 2
	GameState.upgrade_points = 1
	GameState.leaderboard_records = [
		{"rank": "A", "score": 236, "title": "Intro to Fractions", "detail": "Comp 85%  Attention 91%  Progress 100%", "level_up": true},
		{"rank": "B", "score": 196, "title": "Comparing Decimals", "detail": "Objectives 2/2  Attention 78%  Engaged 6/6", "level_up": false},
	]
	_seed_competencies()
	Game.clear_lesson()

	var hub: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(hub)
	await _frames(2)
	_assert_text("Hub base", hub, [
		"CHALK & CHANCE",
		"Adaptive coach:",
		"Evidence",
		"Teacher Level",
		"Badges:",
	])

	hub._open_evidence_journal()
	await _frames(2)
	var evidence := hub.get_node_or_null("EvidenceJournalOverlay")
	if evidence == null:
		_issue("Evidence Journal overlay did not open")
	else:
		_assert_text("Evidence Journal", evidence, [
			"EVIDENCE JOURNAL",
			"Practice target:",
			"growth edge",
			"Try:",
			"RECENT RUN EVIDENCE",
			"Rowe 1986",
		])
		evidence.queue_free()
	await _frames(1)

	hub._open_mission_briefing("lecture_fractions")
	await _frames(2)
	var briefing := hub.get_node_or_null("MissionBriefingOverlay")
	if briefing == null:
		_issue("Mission briefing overlay did not open")
	else:
		_assert_text("Mission briefing", briefing, [
			"CASE",
			"SUCCESS",
			"EVIDENCE",
			"Research edge:",
			"FIRST MOVE",
			"Start rehearsal",
		])
		briefing.queue_free()
	await _frames(1)

	GameState.upgrade_points = 0
	hub._open_upgrades_or_explain()
	await _frames(2)
	var upgrade_notice := hub.get_node_or_null("NoticeOverlay")
	if upgrade_notice == null:
		_issue("No-upgrade notice did not open")
	else:
		_assert_text("No-upgrade notice", upgrade_notice, [
			"NO UPGRADE POINTS YET",
			"Level up",
			"earn XP",
			"spend the point",
		])
		upgrade_notice.queue_free()
	await _frames(1)

	hub._open_locked_mission_notice("group_work_fractions", _json("res://data/scenarios/group_work_fractions.json"))
	await _frames(2)
	var locked_notice := hub.get_node_or_null("NoticeOverlay")
	if locked_notice == null:
		_issue("Locked-mission notice did not open")
	else:
		_assert_text("Locked mission notice", locked_notice, [
			"MISSION LOCKED",
			"opens after",
			"badge",
			"Clear the earlier mission",
		])
		locked_notice.queue_free()
	await _frames(1)

	hub._open_leaderboard()
	await _frames(2)
	var leaderboard := hub.get_node_or_null("LeaderboardOverlay")
	if leaderboard == null:
		_issue("Leaderboard overlay did not open")
	else:
		_assert_text("Leaderboard", leaderboard, [
			"LEADERBOARD",
			"Level",
			"Evidence",
			"Intro to Fractions",
		])
		leaderboard.queue_free()

	hub.queue_free()
	await _frames(1)

	await _audit_debrief_practice_targets()

	if _issues.is_empty():
		print("PRODUCTCONTENT PASS")
	else:
		print("PRODUCTCONTENT FAIL %d issue(s)" % _issues.size())
		for issue in _issues:
			print(issue)
	get_tree().quit()

func _seed_competencies() -> void:
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

func _audit_debrief_practice_targets() -> void:
	Game.current_scenario_id = "lecture_fractions"
	var lecture: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(lecture)
	await _frames(2)
	lecture.setup({"scenario": _json("res://data/scenarios/lecture_fractions.json")})
	await _frames(2)
	lecture.progress = 100.0
	lecture.comprehension = 86.0
	lecture.attention = 82.0
	lecture.composure = 88.0
	lecture._finish(true)
	await _frames(2)
	var lecture_complete := _find_named(lecture, "LectureComplete")
	if lecture_complete == null:
		_issue("Lecture debrief did not open")
	else:
		_assert_text("Lecture debrief", lecture_complete, ["LECTURE DEBRIEF", "Practice:", "Continue"])
	lecture.queue_free()
	await _frames(1)

	Game.current_scenario_id = "gym_capstone"
	var gym: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(gym)
	await _frames(2)
	gym.setup({"scenario": _json("res://data/scenarios/gym_capstone.json")})
	await _frames(2)
	for s in gym.students:
		s["resolved"] = true
		s["u"] = 0.88
	gym.composure = 84.0
	gym.order = 82.0
	gym._finish(true)
	await _frames(2)
	var gym_complete := _find_named(gym, "GymComplete")
	if gym_complete == null:
		_issue("Gym debrief did not open")
	else:
		_assert_text("Gym debrief", gym_complete, ["GYM DEBRIEF", "Practice:", "Continue"])
	gym.queue_free()
	await _frames(1)

	var group: Node = load("res://scenes/encounter/GroupCheckIn.tscn").instantiate()
	add_child(group)
	await _frames(2)
	group.setup({"scenario_context": {"id": "group_work_fractions", "title": "Group Investigation", "badge": "balance"}})
	await _frames(2)
	group.understanding = 0.82
	group.participation = 0.78
	group.revealed = true
	group._check_win()
	await _frames(2)
	var group_complete := _find_named(group, "GroupComplete")
	if group_complete == null:
		_issue("Group debrief did not open")
	else:
		_assert_text("Group debrief", group_complete, ["GROUP DEBRIEF", "Practice:", "Continue"])
	group.queue_free()
	await _frames(1)

	Game.clear_lesson()
	Game.current_scenario_id = "independent_fractions"
	var over: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(over)
	await _frames(3)
	_prepare_overworld_clear(over)
	over._end_lesson()
	await _frames(2)
	over._on_reflect({"_reflect": "worked"})
	await _frames(2)
	if over._overlay == null:
		_issue("Overworld debrief did not open")
	else:
		_assert_text("Overworld debrief", over._overlay, ["DEBRIEF", "Practice:", "Research edge:", "Evidence:"])
	over.queue_free()
	Game.clear_lesson()
	await _frames(1)

func _prepare_overworld_clear(sc: Node) -> void:
	sc._composure = 92.0
	sc._disruptions = 0
	for st in sc._npcs.keys():
		sc._npcs[st]["offtask"] = 0.0
		Game.note_visit(str(sc._npcs[st].get("persona_id", "")))
	if sc._objective_label != null:
		sc._objective_label.text = sc._objectives_status(100.0)
	if sc._attention_fill != null:
		sc._attention_fill.size = Vector2(216.0, 12.0)
	if sc._composure_fill != null:
		sc._composure_fill.size = Vector2(156.0 * sc._composure / GameState.max_composure(), 10.0)

func _assert_text(label: String, root: Node, needles: Array) -> void:
	var text := _visible_text(root).to_lower()
	for needle in needles:
		var n := str(needle).to_lower()
		if text.find(n) == -1:
			_issue("%s missing text: %s | visible=%s" % [label, str(needle), _truncate(text, 220)])

func _find_named(root: Node, node_name: String) -> Node:
	if str(root.name) == node_name:
		return root
	for ch in root.get_children():
		var found := _find_named(ch, node_name)
		if found != null:
			return found
	return null

func _visible_text(root: Node) -> String:
	var parts: Array = []
	_collect_text(root, parts)
	return " ".join(parts).replace("\n", " ").replace("\t", " ").strip_edges()

func _collect_text(n: Node, parts: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		var l := n as Label
		if l.text.strip_edges() != "":
			parts.append(l.text)
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

func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _issue(text: String) -> void:
	_issues.append(text)

func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 3) + "..."
