extends Node

const ProductAuditSupport = preload("res://scenes/dev/ProductAuditSupport.gd")
const ProductDebriefAudit = preload("res://scenes/dev/ProductDebriefAudit.gd")

var _issues: Array = []

func _ready() -> void:
	_reset_state()

	var hub: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(hub)
	await _frames(2)
	_reset_state()
	for child in hub.get_children():
		child.queue_free()
	await _frames(1)
	hub._build()
	await _frames(1)
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
			"ADAPTIVE START",
			"Research edge:",
			"FIRST MOVE",
			"Start rehearsal",
		])
		_assert_label_groups_do_not_overlap("Mission briefing", briefing, ["EVIDENCE", "Research edge:"], ["ADAPTIVE START", "Adaptive:"])
		_assert_label_groups_do_not_overlap("Mission briefing", briefing, ["Reward:"], ["ADAPTIVE START", "Adaptive:"])
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

	hub._open_locked_mission_notice("group_work_fractions", ProductAuditSupport.json("res://data/scenarios/group_work_fractions.json"))
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
			"LEADERBOARD / COACH REPORT",
			"Level",
			"Coach Report",
			"Intro to Fractions",
			"Focus",
			"TRACE",
			"Trace",
			"Class",
			"Quality",
			"TeacherSim",
			"Cloud Log",
		])
		leaderboard.queue_free()
	await _frames(1)

	hub._open_trace_detail(ProductAuditSupport.sample_trace_record())
	await _frames(2)
	var trace_detail := hub.get_node_or_null("TraceDetailOverlay")
	if trace_detail == null:
		_issue("Trace Detail overlay did not open")
	else:
		_assert_text("Trace Detail", trace_detail, [
			"TRACE DETAIL",
			"Turn 1",
			"Evidence",
			"Signal:",
			"Reaction:",
			"Meter:",
			"Next:",
		])
		trace_detail.queue_free()

	hub._open_quality_report()
	await _frames(2)
	var quality := hub.get_node_or_null("QualityReportOverlay")
	if quality == null:
		_issue("Quality Report overlay did not open")
	else:
		_assert_text("Quality Report", quality, ["COMMERCIAL READINESS", "Current internal readiness", "Readiness dimensions", "Proof status", "Contract-proven", "Live-proven", "External-proven", "Adaptive proof", "Shift rule:", "Replay ladder proof", "low repeated evidence", "strong repeated evidence", "Remaining 95-point priorities"])
		quality.queue_free()
	await _frames(1)

	hub._open_teacher_sim_delta()
	await _frames(2)
	var delta := hub.get_node_or_null("TeacherSimDeltaOverlay")
	if delta == null:
		_issue("TeacherSim Delta overlay did not open")
	else:
		_assert_text("TeacherSim Delta", delta, ["TEACHERSIM DELTA", "classic teacher simulation", "Comparison matrix", "Evidence transparency", "Novelty claim", "Adaptive evidence-transparent rehearsal", "Evidence plan", "Paired A/B", "Blind ratings"])
		delta.queue_free()
	await _frames(1)

	hub._open_cloud_log_check()
	await _frames(2)
	var cloud := hub.get_node_or_null("CloudLogOverlay")
	if cloud == null:
		_issue("Cloud Log overlay did not open")
	else:
		_assert_text("Cloud Log", cloud, ["CLOUD LOG CHECK", "Local telemetry file:", "POST /telemetry", "GET /class_dashboard", "Live verifier:", "live D1 proof pending"])
		cloud.queue_free()

	hub._open_class_dashboard()
	await _frames(2)
	var class_dash := hub.get_node_or_null("ClassDashboardOverlay")
	if class_dash == null:
		_issue("Class Dashboard overlay did not open")
	else:
		_assert_text("Class Dashboard", class_dash, [
			"INSTRUCTOR DASHBOARD",
			"Local learner skill snapshot",
			"Next practice:",
		])
		class_dash.queue_free()

	hub.queue_free()
	await _frames(1)

	for issue in ProductAuditSupport.adaptive_semantic_issues():
		_issue(issue)

	for issue in await ProductDebriefAudit.run(self):
		_issue(issue)

	if _issues.is_empty():
		print("PRODUCTCONTENT PASS")
	else:
		print("PRODUCTCONTENT FAIL %d issue(s)" % _issues.size())
		for issue in _issues:
			print(issue)
	get_tree().quit()

func _assert_text(label: String, root: Node, needles: Array) -> void:
	for issue in ProductAuditSupport.assert_text_issues(label, root, needles):
		_issue(issue)

func _reset_state() -> void:
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
		ProductAuditSupport.sample_trace_record(),
		{"rank": "B", "score": 196, "title": "Comparing Decimals", "detail": "Objectives 2/2  Attention 78%  Engaged 6/6", "level_up": false,
			"coach_focus": "Funds of knowledge 40%", "coach_next": "Practice: Asset connect 40% -> Connect to learner asset",
			"evidence_trace": "Elicit>Eliciting+ | Tell>Restraint-"},
	]
	ProductAuditSupport.seed_competencies()
	Game.clear_lesson()

func _assert_label_groups_do_not_overlap(label: String, root: Node, group_a: Array, group_b: Array) -> void:
	for issue in ProductAuditSupport.label_overlap_issues(label, root, group_a, group_b):
		_issue(issue)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _issue(text: String) -> void:
	_issues.append(text)
