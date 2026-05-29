extends RefCounted
## Offline lesson-plan -> scenario converter (no backend needed). Parses plan text for the
## activity format, duration, and subject, and maps them to a valid scenario (seating by
## task, objectives, roster). For content-specific student dialogue, the FastAPI backend
## (tools/llm_backend) fills persona_overrides; this heuristic gives the structure. Custom
## scenarios are written to user://scenarios/ so they work in exported builds.

const NAMES := {
	"talia_dominator": "Talia", "sam_withdrawn": "Sam", "diego_ell": "Diego",
	"jordan_skeptic": "Jordan", "priya_quiet": "Priya", "noah_g5_fractions": "Noah",
	"meilin_anxious": "Mei-Lin", "deshawn_offtask": "Deshawn",
	"riley_avoidant": "Riley", "marcus_volatile": "Marcus",
}

static func plan_to_scenario(text: String) -> Dictionary:
	var low := text.to_lower()
	var fmt := "discussion"
	var arr := "ushape"
	var badge := "echo"
	if _has(low, ["group", "collaborat", "station", "team", "jigsaw"]):
		fmt = "group_work"; arr = "clusters"; badge = "balance"
	elif _has(low, ["independent", "seatwork", "worksheet", "practice set", "individual work"]):
		fmt = "independent"; arr = "rows"; badge = "routine"
	elif _has(low, ["lecture", "direct instruction", "mini-lesson", "presentation"]):
		fmt = "lecture"; arr = "rows"; badge = "routine"
	elif _has(low, ["discussion", "number talk", "socratic", "seminar", "debate"]):
		fmt = "discussion"; arr = "ushape"; badge = "echo"

	var minutes := _find_minutes(low)
	var period := 120
	if minutes > 0:
		period = clampi(int(round(minutes * 2.5)), 90, 180)

	var subject := _find_subject(text)
	var ros := _roster_for(fmt, arr)
	var objs: Array = [
		{"id": "attn", "label": "Keep class attention >= 65%", "metric": "attention_min", "target": 65},
		{"id": "comp", "label": "Finish with composure >= 50%", "metric": "composure_min", "target": 50},
		{"id": "dis", "label": "At most 3 disruptions", "metric": "disruptions_max", "target": 3},
		{"id": "eq", "label": "Reach every student (%d)" % ros.size(), "metric": "engaged_min", "target": ros.size()},
	]
	if fmt == "discussion" or fmt == "lecture":
		objs.append({"id": "wt", "label": "Use wait time at least 2 times", "metric": "waittime_min", "target": 2})

	var rise := 8.0
	if fmt == "group_work":
		rise = 12.0
	elif fmt == "lecture":
		rise = 11.0

	return {
		"id": "custom_" + _slug(subject),
		"title": "%s  -  %s (%s)" % [subject, _fmt_name(fmt), arr],
		"format": fmt, "arrangement": arr,
		"period_seconds": period, "offtask_rise": rise,
		"roster": ros, "objectives": objs, "badge": badge,
		"_source": "offline_import",
	}

static func save_custom(scenario: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute("user://scenarios")
	var id: String = str(scenario.get("id", "custom_lesson"))
	var f := FileAccess.open("user://scenarios/%s.json" % id, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scenario, "\t"))
		f.close()
	return id

# --- helpers -----------------------------------------------------------------

static func _has(low: String, keys: Array) -> bool:
	for k in keys:
		if low.find(k) != -1:
			return true
	return false

static func _find_minutes(low: String) -> int:
	var re := RegEx.new()
	re.compile("(\\d{1,3})\\s*(?:min|minute)")
	var m := re.search(low)
	if m != null:
		return int(m.get_string(1))
	return 0

static func _find_subject(text: String) -> String:
	for raw in text.split("\n"):
		var line := raw.strip_edges().lstrip("*# ").strip_edges()   # ignore markdown bold/heading marks
		var l := line.to_lower()
		if l.begins_with("subject") or l.begins_with("topic") or l.begins_with("title"):
			var idx := line.find(":")
			if idx != -1:
				var val := line.substr(idx + 1).strip_edges().lstrip("*").strip_edges()
				if val != "":
					return _clean_subject(val)
	# else first real markdown heading
	for raw2 in text.split("\n"):
		if raw2.strip_edges().begins_with("#"):
			var h := raw2.strip_edges().lstrip("# ").strip_edges()
			if h != "" and h.to_lower() != "lesson plan":
				return _clean_subject(h)
	return "Imported Lesson"

static func _clean_subject(s: String) -> String:
	# Drop a leading discipline prefix like "Mathematics - " or "Math — " for a tidy title.
	for sep in [" - ", " — ", " – "]:
		var d := s.find(sep)
		if d != -1 and d < 24:
			s = s.substr(d + sep.length()).strip_edges()
			break
	if s.length() > 40:
		s = s.substr(0, 40)
		var sp := s.rfind(" ")
		if sp > 16:
			s = s.substr(0, sp)
		s = s.strip_edges()
	# drop a dangling unmatched open parenthesis
	var op := s.rfind("(")
	if op != -1 and s.find(")", op) == -1:
		s = s.substr(0, op).strip_edges()
	return s if s != "" else "Imported Lesson"

static func _fmt_name(fmt: String) -> String:
	match fmt:
		"lecture": return "Lecture"
		"group_work": return "Group Work"
		"independent": return "Independent Work"
		_: return "Discussion"

static func _roster_for(fmt: String, arr: String) -> Array:
	var ids: Array
	var seats: Array
	match fmt:
		"lecture":
			ids = ["talia_dominator", "diego_ell", "jordan_skeptic", "marcus_volatile", "priya_quiet", "meilin_anxious", "deshawn_offtask", "noah_g5_fractions"]
			seats = [0, 2, 4, 5, 7, 9, 11, 13]
		"group_work":
			ids = ["talia_dominator", "noah_g5_fractions", "meilin_anxious", "diego_ell", "deshawn_offtask", "marcus_volatile", "priya_quiet", "sam_withdrawn"]
			seats = [0, 1, 4, 5, 8, 9, 12, 13]
		"independent":
			ids = ["riley_avoidant", "marcus_volatile", "deshawn_offtask", "noah_g5_fractions", "meilin_anxious", "sam_withdrawn", "diego_ell", "priya_quiet"]
			seats = [1, 3, 5, 7, 8, 10, 12, 14]
		_:
			ids = ["talia_dominator", "sam_withdrawn", "diego_ell", "jordan_skeptic", "priya_quiet", "noah_g5_fractions"]
			seats = [0, 1, 2, 4, 6, 8]
	var out: Array = []
	for i in range(ids.size()):
		out.append({"id": ids[i], "name": NAMES.get(ids[i], "Student"), "seat": seats[i]})
	return out

static func _slug(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "_"
	while out.find("__") != -1:
		out = out.replace("__", "_")
	out = out.strip_edges().lstrip("_").rstrip("_")
	if out == "":
		out = "lesson"
	if out.length() > 28:
		out = out.substr(0, 28)
	return out
