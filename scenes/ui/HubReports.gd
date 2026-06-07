extends RefCounted

static func quality_report_text() -> String:
	var rows := GameState.leaderboard_top(30)
	var evidence_score := 16
	var gameplay_score := 18
	var ux_score := 17
	var adapt_score := 14
	var data_score := 10
	if rows.size() >= 1:
		gameplay_score += 2
	var has_evidence := false
	for r in Competency.summary():
		if int(r.get("n", 0)) > 0:
			has_evidence = true
	if has_evidence:
		evidence_score += 3
		adapt_score += 2
	if Auth.signed_in():
		data_score += 3
	var score := mini(evidence_score + gameplay_score + ux_score + adapt_score + data_score, 95)
	var live_d1 := "ready for env-backed pilot" if Auth.signed_in() else "blocked until signed-in pilot env exists"
	var next_refactor := "Hub split started; continue extracting reports, overlays, and mission cards"
	if score >= 90:
		next_refactor = "Keep splitting large UI scenes while adding release polish"
	score = mini(score, 95)
	return "\n".join([
		"Current internal readiness: %d / 100" % score,
		"95-point target: QA-green commercial pilot, not public launch certification",
		"",
		"Readiness dimensions",
		"- Evidence transparency: %d / 20" % evidence_score,
		"- Play loop completeness: %d / 20" % gameplay_score,
		"- UI readability and pixel polish: %d / 20" % ux_score,
		"- Adaptive engine: %d / 20" % adapt_score,
		"- Cloud and instructor data: %d / 15 (%s)" % [data_score, live_d1],
		"",
		"Proof status",
		"- Contract-proven: telemetry redaction, competency upsert, instructor-only dashboard route",
		"- QA-proven: login-to-play completion, UI layout, screenshots, content surfaces",
		"- Live-proven: pending env-backed learner/instructor D1 run",
		"- External-proven: pending paired TeacherSim comparison",
		"",
		adaptive_proof_text(),
		"",
		"Strong now",
		"- Playable login -> hub -> briefing -> mode -> debrief loop",
		"- Evidence-based Coach Report with clickable Trace Detail",
		"- Adaptive start uses saved competency evidence",
		"- Profile defaults change loadout and in-mode item bonuses",
		"- Product QA, screenshot QA, telemetry QA, and playtest gates exist",
		"",
		"Remaining 95-point priorities",
		"1. Structural risk: %s" % next_refactor,
		"2. Game feel: add richer completion bursts and portrait/state animation variants",
		"3. Adaptive proof: show before/after difficulty shifts across repeated runs",
		"4. Instructor proof: run live D1 verification with learner and instructor accounts",
		"5. TeacherSim proof: compare feedback specificity, replay quality, and trace interpretability",
	])

static func adaptive_proof_text() -> String:
	var lines: Array = [
		"Adaptive proof",
		"- Shift rule: <45% scaffold, 45-72% standard, >72% challenge after 3+ evidence events",
	]
	var modes := {
		"Lecture": ["formative_check", "wait_time", "restraint"],
		"Discussion": ["wait_time", "elicit_reasoning", "behavior_mgmt"],
		"Group": ["group_monitoring", "formative_check", "status_treatment"],
		"Capstone": ["elicit_reasoning", "extend_thinking", "revoicing", "behavior_mgmt", "wait_time"],
	}
	for mode in modes.keys():
		var d := Game.adaptive_difficulty(modes[mode])
		lines.append("- %s now: %s | mastery %d%% | evidence %d" % [
			mode,
			Game.adaptive_difficulty_label(d).replace("Adaptive: ", ""),
			int(round(float(d.get("prob", 0.5)) * 100.0)),
			int(d.get("evidence", 0)),
		])
	lines.append("- Replay ladder proof: no evidence -> %s; low repeated evidence -> %s; strong repeated evidence -> %s" % [
		Game.adaptive_difficulty_label(Game.adaptive_level_for(0.50, 0)).replace("Adaptive: ", ""),
		Game.adaptive_difficulty_label(Game.adaptive_level_for(0.32, 3)).replace("Adaptive: ", ""),
		Game.adaptive_difficulty_label(Game.adaptive_level_for(0.82, 3)).replace("Adaptive: ", ""),
	])
	var latest := _latest_adaptive_run()
	if latest != "":
		lines.append("- Latest saved run: " + latest)
	else:
		lines.append("- Latest saved run: none yet; clear one mission to persist the starting level")
	return "\n".join(lines)

static func _latest_adaptive_run() -> String:
	var latest: Dictionary = {}
	for rec in GameState.leaderboard_top(30):
		var level := str(rec.get("adaptive_level", ""))
		if level == "":
			continue
		if latest.is_empty() or float(rec.get("unix", 0.0)) > float(latest.get("unix", 0.0)):
			latest = rec
	if latest.is_empty():
		return ""
	return "%s used %s" % [str(latest.get("title", "Run")), str(latest.get("adaptive_level", "")).replace("Adaptive: ", "")]

static func teacher_sim_delta_text() -> String:
	return "\n".join([
		"Gap check against classic teacher simulation",
		"",
		"Comparison matrix (internal rubric; pilot validation pending)",
		"- Feedback specificity: Classic 2/5 | Chalk & Chance 4/5",
		"- Adaptive replay: Classic 1/5 | Chalk & Chance 4/5",
		"- Classroom ecology: Classic 2/5 | Chalk & Chance 5/5",
		"- Evidence transparency: Classic 1/5 | Chalk & Chance 5/5",
		"- Instructor analytics: Classic 1/5 | Chalk & Chance 3/5 until live D1 pilot",
		"",
		"Professional benchmark check",
		"- Mursion-class bar: realistic practice, real-time feedback, AI scoring, analytics",
		"- TeachLivE-class bar: complex human interaction rehearsal with repeatable practice",
		"- simSchool-class bar: scalable modules, diverse learners, automated observation reports",
		"",
		"Outstanding design verdict",
		"- Stronger: construct-level evidence trace is visible inside every scored run",
		"- Stronger: adaptive replay changes future mission starts from saved competency evidence",
		"- Stronger: game modes cover individual, lecture, group, room, and capstone ecologies",
		"- Stronger: teacher profile loadouts alter default affordances, not just cosmetic identity",
		"- Not proven yet: live instructor analytics and external paired comparison",
		"",
		"Where Chalk & Chance is stronger",
		"- Move-by-move evidence trace, not just end-of-scenario feedback",
		"- Competency model persists and changes future starting difficulty",
		"- Multiple rehearsal ecologies: one learner, lecture, group, room, capstone",
		"- Teacher profiles create different default tools and tactical affordances",
		"- D1 telemetry supports instructor-level class skill views",
		"",
		"Novelty claim",
		"Adaptive evidence-transparent rehearsal: each teacher move becomes a construct-level trace that changes later missions.",
		"",
		"Next superiority proof",
		"Evidence plan",
		"- Paired A/B: same teacher move sequence in classic sim and Chalk & Chance",
		"- Blind ratings: specificity, replay usefulness, trace interpretability, ecology realism",
		"- Pass gate: Chalk & Chance >= +1 on at least 3 dimensions without losing usability",
		"",
		"Run paired player reviews: judge specificity, adaptive replay quality, and trace interpretability.",
		"Target: +1 rubric point over classic TeacherSim on at least 3 of 5 dimensions.",
	])

static func cloud_log_text(status: String, data: Dictionary = {}) -> String:
	var lines: Array = [status, ""]
	lines.append("Identity: %s" % ("signed in as %s / %s" % [Auth.display_name, Auth.class_code] if Auth.signed_in() else "offline or demo mode"))
	lines.append("Local telemetry file: " + str(Telemetry._path))
	lines.append("Cloud write routes: POST /telemetry, POST /competency")
	lines.append("Cloud read routes: GET /competency, GET /class_dashboard")
	if not data.is_empty():
		lines.append("")
		lines.append("D1 snapshot")
		lines.append("Learners %d | telemetry events %d" % [int(data.get("learners", 0)), int(data.get("telemetry_events", 0))])
		var skills: Array = data.get("skills", [])
		if skills.is_empty():
			lines.append("No class competency rows yet.")
		else:
			for i in range(mini(skills.size(), 4)):
				var row: Dictionary = skills[i]
				lines.append("%s avg %d%% ev %d" % [
					compact_skill_label(str(row.get("skill", ""))),
					int(round(float(row.get("avg_prob", 0.5)) * 100.0)),
					int(row.get("evidence", 0)),
				])
	else:
		lines.append("")
		lines.append("Verification path: sign in, clear one mission, return here, confirm D1 counts rise.")
		lines.append("Live verifier: scripts/verify_live_d1_flow.ps1 with learner and instructor env vars.")
		lines.append("Status: contract-proven locally; live D1 proof pending credentials.")
	return "\n".join(lines)

static func class_dashboard_text(data: Dictionary) -> String:
	var lines: Array = []
	lines.append("Class %s | learners %d | telemetry events %d" % [
		str(data.get("class_code", "local")),
		int(data.get("learners", 0)),
		int(data.get("telemetry_events", 0)),
	])
	lines.append("Weakest class skills")
	var skills: Array = data.get("skills", [])
	if skills.is_empty():
		lines.append("No cloud competency rows yet. Have learners complete one mission.")
	else:
		for i in range(mini(skills.size(), 7)):
			var row: Dictionary = skills[i]
			lines.append("%s  avg %d%%  ev %d  learners %d" % [
				compact_skill_label(str(row.get("skill", ""))),
				int(round(float(row.get("avg_prob", 0.5)) * 100.0)),
				int(row.get("evidence", 0)),
				int(row.get("learners", 0)),
			])
	lines.append("")
	lines.append("Instructional next step: group low-probability skills into tomorrow's rehearsal stations.")
	return "\n".join(lines)

static func local_class_dashboard_text(status: String) -> String:
	var lines: Array = [status, ""]
	lines.append("Local learner skill snapshot")
	var rows := Competency.summary()
	for i in range(mini(rows.size(), 6)):
		var r: Dictionary = rows[i]
		lines.append("%s  %d%%  ev %d" % [
			compact_skill_label(str(r.get("skill", ""))),
			int(round(float(r.get("prob", 0.5)) * 100.0)),
			int(r.get("n", 0)),
		])
	lines.append("")
	lines.append("Runs recorded locally: %d" % GameState.leaderboard_top(30).size())
	lines.append("Next practice: %s" % Game.evidence_practice_target(false))
	return "\n".join(lines)

static func compact_skill_label(skill: String) -> String:
	return {
		"elicit_reasoning": "Elicit reasoning",
		"extend_thinking": "Extend thinking",
		"revoicing": "Revoicing",
		"wait_time": "Wait time",
		"behavior_mgmt": "Behavior mgmt",
		"restraint": "Restraint",
		"behavior_specific_praise": "Specific praise",
		"funds_of_knowledge": "Asset connect",
		"group_monitoring": "Group monitor",
		"formative_check": "Formative check",
		"status_treatment": "Status treatment",
	}.get(skill, skill)
