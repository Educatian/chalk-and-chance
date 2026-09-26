extends Node
## Dev: unit checks for the multi-path judge. Prints PATHJUDGE PASS/FAIL.
const PathJudge = preload("res://scripts/PathJudge.gd")
var fails := 0

func _ok(label: String, cond: bool) -> void:
	print("PATHJUDGE | [%s] %s" % ["OK " if cond else "XX", label])
	if not cond:
		fails += 1

func _ready() -> void:
	var noah = JSON.parse_string(FileAccess.get_file_as_string("res://data/persona_library/noah_g5_fractions.json"))
	var pj = PathJudge.for_persona(noah)
	_ok("noah has 3 paths", pj.paths.size() == 3)
	var r1: Dictionary = pj.evaluate("extend")
	_ok("extend before any reasoning is early, not a hit", r1["fit"] == "early")
	var r2: Dictionary = pj.evaluate("elicit")
	_ok("elicit opens a path", r2["fit"] == "advance")
	var r3: Dictionary = pj.evaluate("extend")
	_ok("extend after elicit advances", r3["fit"] == "advance" and r3["done"])
	var r4: Dictionary = pj.evaluate("extend")
	_ok("repeating the same move lands softer", r4["fit"] == "advance" and float(r4["credit"]) < float(r3["credit"]))
	_ok("tell never fits", pj.evaluate("tell")["fit"] == "miss")
	var pj2 = PathJudge.for_persona(noah)
	_ok("short wait does not count", pj2.evaluate("wait", false)["fit"] == "miss")
	_ok("a different path also works (wait -> elicit)", pj2.evaluate("wait", true)["fit"] == "advance" and pj2.evaluate("elicit")["fit"] == "advance")
	var legacy = PathJudge.for_persona({"win_moves": ["redirect"]})
	_ok("legacy persona falls back to win_moves", legacy.evaluate("redirect")["fit"] == "advance")
	var dir := DirAccess.open("res://data/persona_library")
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/persona_library/" + f))
			var n := (d.get("paths", []) as Array).size()
			_ok("%s has 2-3 paths" % f.get_basename(), n >= 2 and n <= 3)
	var CoachFeedback = load("res://scripts/CoachFeedback.gd")
	var fb: Dictionary = CoachFeedback.analyze([
		{"turn": 1, "tag": "extend", "targets": false, "fit": "early", "student": "Noah", "note": "right idea, too early: first Elicit or Wait or Revoice"},
		{"turn": 2, "tag": "elicit", "targets": true, "fit": "advance", "student": "Noah", "path": "Diagnose, then press"},
	])
	_ok("coach names the early move's setup", str(fb["grow"].get("better_label", "")) == "Elicit first")
	_ok("coach lists other ways in", (fb["ways"] as Array).size() == 1 and str(fb["ways"][0]).contains("Think time first"))
	# --- skill-contingent scaffolding ---
	var Scaffold = load("res://scripts/Scaffold.gd")
	Competency.reset_estimates()
	_ok("no evidence -> full support", int(Scaffold.level_for(["elicit_reasoning"])["level"]) == Scaffold.FULL)
	Competency.n["elicit_reasoning"] = 10
	Competency.theta["elicit_reasoning"] = 0.2    # ~55%
	_ok("mid estimate -> partial support", int(Scaffold.level_for(["elicit_reasoning"])["level"]) == Scaffold.PARTIAL)
	Competency.theta["elicit_reasoning"] = 0.8    # ~69%
	_ok("good estimate -> light support", int(Scaffold.level_for(["elicit_reasoning"])["level"]) == Scaffold.LIGHT)
	Competency.theta["elicit_reasoning"] = 2.0    # ~88%, n=10
	_ok("mastery with evidence -> support off", int(Scaffold.level_for(["elicit_reasoning"])["level"]) == Scaffold.OFF)
	Competency.n["elicit_reasoning"] = 5
	_ok("high estimate but thin evidence stays light", int(Scaffold.level_for(["elicit_reasoning"])["level"]) == Scaffold.LIGHT)
	Competency.reset_estimates()

	# --- lecture evidence contract ---
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/lecture_fractions.json"))
	LLMClient.use_stub = true
	var lec: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(lec)
	await get_tree().process_frame
	lec.setup({"scenario": cfg})
	await get_tree().process_frame
	for mv in ["present", "present", "present"]:
		lec._on_move(mv)
		await get_tree().process_frame
	var last: Dictionary = {}
	for e in Telemetry._buffer:
		if str(e.get("event", "")) == "lecture_move":
			last = e
	for key in ["attempt_id", "scenario_attempt", "opportunity_id", "opportunity_present", "productive_move", "evidence_rule_version", "state_before", "state_after"]:
		_ok("lecture_move logs %s" % key, last.has(key))
	_ok("third Present in a row is labelled a monologue opportunity, not productive",
		str(last.get("opportunity_type", "")) == "monologue" and not bool(last.get("productive_move", true)))
	lec.queue_free()
	print("PATHJUDGE %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit()
