extends RefCounted

static func class_dashboard_text(data: Dictionary) -> String:
	var lines: Array = []
	var activity: Dictionary = data.get("activity", {})
	lines.append("Class %s | learners %d | telemetry events %d" % [
		str(data.get("class_code", "local")),
		int(data.get("learners", 0)),
		int(data.get("telemetry_events", 0)),
	])
	lines.append("Live instructor analytics")
	lines.append("Active 24h %d | sessions %d | completed %d | completion %d%%" % [
		int(activity.get("active_24h", 0)),
		int(activity.get("sessions", 0)),
		int(activity.get("completed_sessions", 0)),
		int(round(float(activity.get("completion_rate", 0.0)) * 100.0)),
	])
	var last_event := str(activity.get("last_event_at", ""))
	if last_event != "":
		lines.append("Last D1 event: %s" % last_event)
	lines.append("")
	_add_skill_risk(lines, data.get("skills", []))
	lines.append("")
	_add_modes(lines, data.get("modes", []))
	lines.append("")
	_add_learner_watchlist(lines, data.get("learners_detail", []))
	lines.append("")
	_add_interventions(lines, data.get("interventions", []))
	return "\n".join(lines)

static func local_class_dashboard_text(status: String) -> String:
	var lines: Array = [status, ""]
	lines.append("Live instructor analytics")
	lines.append("Cloud metrics need instructor sign-in; local preview uses this learner's evidence.")
	lines.append("")
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

static func _add_skill_risk(lines: Array, skills: Array) -> void:
	lines.append("Weakest class skills")
	if skills.is_empty():
		lines.append("No cloud competency rows yet. Have learners complete one mission.")
		return
	for i in range(mini(skills.size(), 6)):
		var row: Dictionary = skills[i]
		lines.append("%s avg %d%% ev %d risk %d ready %d" % [
			compact_skill_label(str(row.get("skill", ""))),
			int(round(float(row.get("avg_prob", 0.5)) * 100.0)),
			int(row.get("evidence", 0)),
			int(row.get("at_risk", 0)),
			int(row.get("ready", 0)),
		])

static func _add_modes(lines: Array, modes: Array) -> void:
	lines.append("Mode coverage")
	if modes.is_empty():
		lines.append("No mode telemetry yet.")
		return
	for i in range(mini(modes.size(), 4)):
		var row: Dictionary = modes[i]
		lines.append("%s  events %d  sessions %d" % [
			str(row.get("mode", "event")),
			int(row.get("events", 0)),
			int(row.get("sessions", 0)),
		])

static func _add_learner_watchlist(lines: Array, rows: Array) -> void:
	lines.append("Learner watchlist")
	if rows.is_empty():
		lines.append("No learner activity rows yet.")
		return
	for i in range(mini(rows.size(), 4)):
		var row: Dictionary = rows[i]
		lines.append("%s  avg %d%%  weak %s  ev %d" % [
			str(row.get("display_name", "Learner")),
			int(round(float(row.get("avg_prob", 0.5)) * 100.0)),
			compact_skill_label(str(row.get("weakest_skill", ""))),
			int(row.get("evidence", 0)),
		])

static func _add_interventions(lines: Array, interventions: Array) -> void:
	lines.append("Instructional next steps")
	if interventions.is_empty():
		lines.append("Collect one completed mission per learner before assigning stations.")
		return
	for i in range(mini(interventions.size(), 3)):
		lines.append("- %s" % str(interventions[i]))

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
