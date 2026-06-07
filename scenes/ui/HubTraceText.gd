extends RefCounted

static func trace_detail_text(rec: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s | Rank %s | Score %03d" % [
		truncate(str(rec.get("title", "Lesson")), 34),
		str(rec.get("rank", "-")),
		int(rec.get("score", 0)),
	])
	var focus := str(rec.get("coach_focus", ""))
	if focus != "":
		lines.append("Coach focus: " + focus)
	lines.append("")
	var raw_steps = rec.get("evidence_trace_steps", [])
	var steps: Array = raw_steps if typeof(raw_steps) == TYPE_ARRAY else []
	if steps.size() > 0:
		var step_count: int = min(steps.size(), 4)
		for i in range(step_count):
			var step = steps[i]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			lines.append("Turn %d | Move %s | Evidence %s | %s" % [
				int(step.get("turn", i + 1)),
				truncate(str(step.get("move", "Move")), 14),
				truncate(str(step.get("construct", "Skill")), 18),
				str(step.get("outcome", "evidence")),
			])
			var signal_text := str(step.get("signal", ""))
			if signal_text != "":
				lines.append("Signal: " + truncate(signal_text, 76))
			var reaction := str(step.get("reaction", ""))
			if reaction != "":
				lines.append("Reaction: " + truncate(reaction, 76))
			var meter := str(step.get("meter", ""))
			if meter != "":
				lines.append("Meter: " + truncate(meter, 76))
	else:
		var trace := str(rec.get("evidence_trace", ""))
		if trace != "":
			lines.append("TRACE " + trace)
		else:
			lines.append("No saved trace detail for this older run.")
	lines.append("")
	var next_step := str(rec.get("coach_next", ""))
	if next_step != "":
		lines.append("Next: " + next_step)
	else:
		lines.append("Next: " + Game.evidence_practice_target(false))
	return "\n".join(lines)

static func truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max(0, max_len - 3)) + "..."
