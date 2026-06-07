extends RefCounted

const ProductAuditSupport = preload("res://scenes/dev/ProductAuditSupport.gd")

static func run(host: Node) -> Array:
	var issues: Array = []
	Game.current_scenario_id = "lecture_fractions"
	var lecture: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	host.add_child(lecture)
	await _frames(host, 2)
	lecture.setup({"scenario": ProductAuditSupport.json("res://data/scenarios/lecture_fractions.json")})
	await _frames(host, 2)
	lecture.progress = 100.0
	lecture.comprehension = 86.0
	lecture.attention = 82.0
	lecture.composure = 88.0
	lecture._finish(true)
	await _frames(host, 2)
	var lecture_complete := ProductAuditSupport.find_named(lecture, "LectureComplete")
	if lecture_complete == null:
		issues.append("Lecture debrief did not open")
	else:
		issues.append_array(ProductAuditSupport.assert_text_issues("Lecture debrief", lecture_complete, ["LECTURE DEBRIEF", "Trace:", "Practice:", "Return to hub"]))
		_require_completion_burst(issues, "Lecture debrief", lecture_complete)
	lecture.queue_free()
	await _frames(host, 1)

	Game.current_scenario_id = "gym_capstone"
	var gym: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	host.add_child(gym)
	await _frames(host, 2)
	gym.setup({"scenario": ProductAuditSupport.json("res://data/scenarios/gym_capstone.json")})
	await _frames(host, 2)
	for s in gym.students:
		s["resolved"] = true
		s["u"] = 0.88
	gym.composure = 84.0
	gym.order = 82.0
	gym._finish(true)
	await _frames(host, 2)
	var gym_complete := ProductAuditSupport.find_named(gym, "GymComplete")
	if gym_complete == null:
		issues.append("Gym debrief did not open")
	else:
		issues.append_array(ProductAuditSupport.assert_text_issues("Gym debrief", gym_complete, ["GYM DEBRIEF", "Trace:", "Practice:", "Return to hub"]))
		_require_completion_burst(issues, "Gym debrief", gym_complete)
	gym.queue_free()
	await _frames(host, 1)

	var group: Node = load("res://scenes/encounter/GroupCheckIn.tscn").instantiate()
	host.add_child(group)
	await _frames(host, 2)
	group.setup({"scenario_context": {"id": "group_work_fractions", "title": "Group Investigation", "badge": "balance"}})
	await _frames(host, 2)
	group._local_fallback("observe")
	await _frames(host, 2)
	_require_reaction_cue(issues, "Group check-in", group)
	group.understanding = 0.82
	group.participation = 0.78
	group.revealed = true
	group._check_win()
	await _frames(host, 2)
	var group_complete := ProductAuditSupport.find_named(group, "GroupComplete")
	if group_complete == null:
		issues.append("Group debrief did not open")
	else:
		issues.append_array(ProductAuditSupport.assert_text_issues("Group debrief", group_complete, ["GROUP DEBRIEF", "Trace:", "Practice:", "Return to room"]))
		issues.append_array(ProductAuditSupport.label_overlap_issues("Group debrief", group_complete, ["Trace:"], ["Focus:", "Practice:"]))
		issues.append_array(ProductAuditSupport.label_overlap_issues("Group debrief", group_complete, ["Focus:"], ["Practice:"]))
		_require_completion_burst(issues, "Group debrief", group_complete)
	group.queue_free()
	await _frames(host, 1)

	Game.clear_lesson()
	Game.current_scenario_id = "independent_fractions"
	var over: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	host.add_child(over)
	await _frames(host, 3)
	ProductAuditSupport.prepare_overworld_clear(over)
	over._end_lesson()
	await _frames(host, 2)
	over._on_reflect({"_reflect": "worked"})
	await _frames(host, 2)
	if over._overlay == null:
		issues.append("Overworld debrief did not open")
	else:
		issues.append_array(ProductAuditSupport.assert_text_issues("Overworld debrief", over._overlay, ["DEBRIEF", "Practice:", "Research edge:", "Evidence:"]))
	var trace_issue := ProductAuditSupport.overworld_trace_issue()
	if trace_issue != "":
		issues.append(trace_issue)
	over.queue_free()
	Game.clear_lesson()
	await _frames(host, 1)
	return issues

static func _frames(host: Node, n: int) -> void:
	for i in range(n):
		await host.get_tree().process_frame

static func _require_completion_burst(issues: Array, label: String, root: Node) -> void:
	if ProductAuditSupport.find_named(root, "CompletionBurst") == null:
		issues.append("%s missing CompletionBurst FX" % label)

static func _require_reaction_cue(issues: Array, label: String, root: Node) -> void:
	var cue := ProductAuditSupport.find_named(root, "ReactionCue")
	if cue == null:
		issues.append("%s missing ReactionCue feedback" % label)
		return
	issues.append_array(ProductAuditSupport.assert_text_issues(label + " reaction cue", cue, ["Airtime imbalance"]))
