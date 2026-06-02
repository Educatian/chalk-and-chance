extends Node

const SCENARIO_DIR := "res://data/scenarios"
const PERSONA_DIR := "res://data/persona_library"
const PORTRAIT_DIR := "res://assets/portraits"

const REQUIRED_FIELDS := ["id", "title", "format", "mode", "arrangement", "roster", "objectives", "badge", "backdrop", "backdrop_thumb", "story_hook"]
const FORMATS := ["discussion", "lecture", "group_work", "independent"]
const MODES := ["overworld", "lecture", "gym"]
const ARRANGEMENTS := ["ushape", "rows", "clusters"]
const METRICS := ["attention_min", "composure_min", "disruptions_max", "engaged_min", "waittime_min", "connect_min"]
const BADGES := ["routine", "echo", "balance", "mirror", "insight", "bridge"]
const MOVE_TAGS := ["elicit", "extend", "revoice", "tell", "praise", "connect", "redirect", "wait"]
const GROUP_TAGS := ["observe", "probe", "press", "redistribute"]

var _issues: Array = []
var _scenario_ids := {}
var _badges_defined := {}

func _ready() -> void:
	_scan_scenarios()
	_scan_game_scenario_order()
	_scan_competency_model()

	if _issues.is_empty():
		print("SCENARIOINTEGRITY PASS")
	else:
		print("SCENARIOINTEGRITY FAIL %d issue(s)" % _issues.size())
		for issue in _issues:
			print(issue)
	get_tree().quit()

func _scan_scenarios() -> void:
	var dir := DirAccess.open(SCENARIO_DIR)
	if dir == null:
		_issue("missing scenario dir: %s" % SCENARIO_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var path := "%s/%s" % [SCENARIO_DIR, file]
		var cfg := _json(path)
		if cfg.is_empty():
			_issue("%s invalid or empty JSON" % path)
			continue
		_scan_scenario(path, cfg)

func _scan_scenario(path: String, cfg: Dictionary) -> void:
	var id := str(cfg.get("id", ""))
	if id == "":
		_issue("%s missing id" % path)
		return
	if _scenario_ids.has(id):
		_issue("%s duplicate id already seen in %s" % [path, str(_scenario_ids[id])])
	else:
		_scenario_ids[id] = path
	for field in REQUIRED_FIELDS:
		if not cfg.has(field):
			_issue("%s missing required field: %s" % [id, field])

	var file_id := path.get_file().get_basename()
	if id != file_id:
		_issue("%s id does not match filename %s" % [id, file_id])

	var fmt := str(cfg.get("format", ""))
	if not (fmt in FORMATS):
		_issue("%s unknown format: %s" % [id, fmt])
	var mode := str(cfg.get("mode", ""))
	if not (mode in MODES):
		_issue("%s unknown mode: %s" % [id, mode])
	var arrangement := str(cfg.get("arrangement", ""))
	if not (arrangement in ARRANGEMENTS):
		_issue("%s unknown arrangement: %s" % [id, arrangement])

	var badge := str(cfg.get("badge", ""))
	if badge == "" or not (badge in BADGES):
		_issue("%s unknown badge: %s" % [id, badge])
	else:
		_badges_defined[badge] = true
	var requires := str(cfg.get("requires", ""))
	if requires != "" and not (requires in BADGES):
		_issue("%s requires unknown badge: %s" % [id, requires])

	_check_asset(id, "backdrop", str(cfg.get("backdrop", "")))
	_check_asset(id, "backdrop_thumb", str(cfg.get("backdrop_thumb", "")))
	if str(cfg.get("story_hook", "")).strip_edges().length() < 24:
		_issue("%s story_hook too short for mission briefing" % id)

	_scan_roster(id, cfg.get("roster", []))
	_scan_objectives(id, mode, cfg.get("objectives", []))
	_scan_persona_overrides(id, cfg.get("roster", []), cfg.get("persona_overrides", {}))

func _scan_roster(id: String, roster_value) -> void:
	if typeof(roster_value) != TYPE_ARRAY:
		_issue("%s roster is not an array" % id)
		return
	var roster: Array = roster_value
	if roster.size() < 2:
		_issue("%s roster needs at least 2 learners" % id)
	var seats := {}
	for i in range(roster.size()):
		var r = roster[i]
		if typeof(r) != TYPE_DICTIONARY:
			_issue("%s roster[%d] is not an object" % [id, i])
			continue
		var pid := str(r.get("id", r.get("persona_id", "")))
		if pid == "":
			_issue("%s roster[%d] missing id" % [id, i])
			continue
		if str(r.get("name", "")).strip_edges() == "":
			_issue("%s roster[%d] missing name" % [id, i])
		if not r.has("seat"):
			_issue("%s roster[%d] missing seat" % [id, i])
		else:
			var seat_key := str(r.get("seat", ""))
			if seats.has(seat_key):
				_issue("%s duplicate roster seat: %s" % [id, seat_key])
			seats[seat_key] = true
		if not FileAccess.file_exists("%s/%s.json" % [PERSONA_DIR, pid]):
			_issue("%s missing persona JSON for %s" % [id, pid])
		if not ResourceLoader.exists("%s/%s_neutral.png" % [PORTRAIT_DIR, pid]):
			_issue("%s missing neutral portrait for %s" % [id, pid])

func _scan_objectives(id: String, mode: String, objectives_value) -> void:
	if typeof(objectives_value) != TYPE_ARRAY:
		_issue("%s objectives is not an array" % id)
		return
	var objectives: Array = objectives_value
	if objectives.is_empty():
		if mode != "gym":
			_issue("%s non-gym scenario needs at least one objective" % id)
		return
	var objective_ids := {}
	for i in range(objectives.size()):
		var o = objectives[i]
		if typeof(o) != TYPE_DICTIONARY:
			_issue("%s objectives[%d] is not an object" % [id, i])
			continue
		for field in ["id", "label", "metric", "target"]:
			if not o.has(field):
				_issue("%s objectives[%d] missing %s" % [id, i, field])
		var oid := str(o.get("id", ""))
		if oid != "":
			if objective_ids.has(oid):
				_issue("%s duplicate objective id: %s" % [id, oid])
			objective_ids[oid] = true
		var metric := str(o.get("metric", ""))
		if not (metric in METRICS):
			_issue("%s objective %s unknown metric: %s" % [id, oid, metric])
		var target := float(o.get("target", -1.0))
		if target < 0.0:
			_issue("%s objective %s has negative target" % [id, oid])

func _scan_persona_overrides(id: String, roster_value, overrides_value) -> void:
	if overrides_value == null:
		return
	if typeof(overrides_value) != TYPE_DICTIONARY:
		_issue("%s persona_overrides is not an object" % id)
		return
	var roster_ids := {}
	if typeof(roster_value) == TYPE_ARRAY:
		for r in roster_value:
			if typeof(r) == TYPE_DICTIONARY:
				roster_ids[str(r.get("id", r.get("persona_id", "")))] = true
	var overrides: Dictionary = overrides_value
	for key in overrides.keys():
		var pid := str(key)
		if not roster_ids.has(pid):
			_issue("%s override references non-roster persona: %s" % [id, pid])
		var po = overrides[pid]
		if typeof(po) != TYPE_DICTIONARY:
			_issue("%s override for %s is not an object" % [id, pid])
			continue
		for field in ["target_label", "opening_line", "win_line", "win_moves"]:
			if not po.has(field) or (field != "win_moves" and str(po.get(field, "")).strip_edges() == ""):
				_issue("%s override %s missing %s" % [id, pid, field])
		var moves = po.get("win_moves", [])
		if typeof(moves) != TYPE_ARRAY or moves.is_empty():
			_issue("%s override %s needs win_moves" % [id, pid])
			continue
		for move in moves:
			var tag := str(move)
			if not (tag in MOVE_TAGS):
				_issue("%s override %s invalid win_move: %s" % [id, pid, tag])

func _scan_game_scenario_order() -> void:
	for id in Game.SCENARIOS:
		if not _scenario_ids.has(str(id)):
			_issue("Game.SCENARIOS references missing scenario: %s" % str(id))

func _scan_competency_model() -> void:
	var model := _json("res://data/competency_model.json")
	if model.is_empty():
		_issue("competency_model.json invalid or empty")
		return
	var skills_value = model.get("skills", [])
	if typeof(skills_value) != TYPE_ARRAY:
		_issue("competency_model skills is not an array")
		return
	var model_skills := {}
	for s in skills_value:
		if typeof(s) != TYPE_DICTIONARY:
			_issue("competency_model contains non-object skill")
			continue
		var sid := str(s.get("id", ""))
		if sid == "":
			_issue("competency_model skill missing id")
			continue
		model_skills[sid] = true
		if str(s.get("label", "")).strip_edges() == "":
			_issue("competency_model %s missing label" % sid)
		if str(s.get("anchor", "")).strip_edges() == "":
			_issue("competency_model %s missing anchor" % sid)
	for sid in Competency.SKILLS:
		if not model_skills.has(str(sid)):
			_issue("Competency.SKILLS missing from competency_model: %s" % str(sid))
	var rules: Dictionary = model.get("evidence_rules", {})
	for tag in Competency.TAG_SKILL.keys():
		_check_rule_for_skill(rules, str(tag), str(Competency.TAG_SKILL[tag]))
	for tag in GROUP_TAGS:
		_check_rule_for_skill(rules, tag, str(Competency.GROUP_TAG_SKILL.get(tag, "")))

func _check_rule_for_skill(rules: Dictionary, tag: String, expected_skill: String) -> void:
	if expected_skill == "":
		return
	if not rules.has(tag):
		_issue("competency_model missing evidence rule for tag: %s" % tag)
		return
	var rule = rules[tag]
	if typeof(rule) != TYPE_DICTIONARY:
		_issue("competency_model evidence rule is not object: %s" % tag)
		return
	var skills = rule.get("skills", [])
	if typeof(skills) != TYPE_ARRAY or not (expected_skill in skills):
		_issue("competency_model rule %s does not include skill %s" % [tag, expected_skill])

func _check_asset(id: String, field: String, path: String) -> void:
	if path == "":
		_issue("%s missing %s path" % [id, field])
	elif not ResourceLoader.exists(path):
		_issue("%s %s asset missing: %s" % [id, field, path])

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _issue(text: String) -> void:
	_issues.append(text)
