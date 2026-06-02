extends Node

const VIEW := Rect2(Vector2.ZERO, Vector2(960, 540))
const INTERACTIVE := ["Button", "LineEdit", "TextEdit", "ScrollContainer"]

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

	await _audit_scene("Login", load("res://scenes/ui/Login.tscn").instantiate())
	await _audit_hub()
	await _audit_scene("ImportLesson", load("res://scenes/ui/ImportLesson.tscn").instantiate())
	await _audit_preview()
	await _audit_encounter()
	await _audit_lecture()
	await _audit_gym()
	await _audit_group_checkin()

	if _issues.is_empty():
		print("UIAUDIT PASS")
	else:
		print("UIAUDIT FAIL %d issue(s)" % _issues.size())
		for i in _issues:
			print(i)
	get_tree().quit()

func _audit_hub() -> void:
	var sc: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	_scan("Hub", sc)
	await _scan_hub_overlay(sc, "Hub briefing", func(): sc._open_mission_briefing("lecture_fractions"), "MissionBriefingOverlay")
	await _scan_hub_overlay(sc, "Hub evidence", func(): sc._open_evidence_journal(), "EvidenceJournalOverlay")
	await _scan_hub_overlay(sc, "Hub leaderboard", func(): sc._open_leaderboard(), "LeaderboardOverlay")
	await _scan_hub_overlay(sc, "Hub settings", func(): sc._open_settings(), "SettingsOverlay")
	await _scan_hub_overlay(sc, "Hub upgrades", func(): sc._open_upgrades(), "UpgradeOverlay")
	await _scan_hub_overlay(sc, "Hub items", func(): sc._open_items(), "ItemsOverlay")
	GameState.upgrade_points = 0
	await _scan_hub_overlay(sc, "Hub no-upgrade notice", func(): sc._open_upgrades_or_explain(), "NoticeOverlay")
	await _scan_hub_overlay(sc, "Hub locked-mission notice", func(): sc._open_locked_mission_notice("group_work_fractions", _json("res://data/scenarios/group_work_fractions.json")), "NoticeOverlay")
	sc.queue_free()
	await get_tree().process_frame

func _scan_hub_overlay(sc: Node, label: String, opener: Callable, overlay_name: String) -> void:
	opener.call()
	await get_tree().process_frame
	var overlay := sc.get_node_or_null(overlay_name)
	if overlay != null:
		_scan(label, overlay)
		overlay.queue_free()
	await get_tree().process_frame

func _audit_preview() -> void:
	var sc: Node = load("res://scenes/ui/PreviewScenario.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	var cfg := _json("res://data/scenarios/reading_main_idea.json")
	sc.setup({"scenario": cfg})
	await get_tree().process_frame
	_scan("PreviewScenario", sc)
	sc.queue_free()
	await get_tree().process_frame

func _audit_encounter() -> void:
	Game.current_scenario_id = "discussion_fractions"
	var sc: Node = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	sc.setup({"persona_id": "noah_g5_fractions", "display_name": "Noah"})
	await get_tree().process_frame
	_scan("Encounter menu", sc)
	sc._toggle_input_mode()
	await get_tree().process_frame
	_scan("Encounter type", sc)
	sc._toggle_input_mode()
	for m in ["elicit", "extend", "elicit", "wait", "extend", "elicit", "revoice", "elicit", "extend"]:
		if sc._resolved:
			break
		sc._on_move(m)
		for i in range(6):
			await get_tree().process_frame
	await get_tree().process_frame
	if sc._resolved:
		_scan("Encounter completion", sc)
	else:
		_issues.append("Encounter completion did not resolve during UI audit")
	sc.queue_free()
	await get_tree().process_frame

func _audit_lecture() -> void:
	Game.current_scenario_id = "lecture_fractions"
	var sc: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	sc.setup({"scenario": _json("res://data/scenarios/lecture_fractions.json")})
	await get_tree().process_frame
	_scan("Lecture menu", sc)
	sc._dialogue.text = "Noah: \"I think the denominator names the equal parts, but I am still mixing it up when the picture changes.\""
	await get_tree().process_frame
	_scan("Lecture long dialogue", sc)
	sc._toggle_input_mode()
	await get_tree().process_frame
	_scan("Lecture type", sc)
	sc.progress = 100.0
	sc.comprehension = 86.0
	sc.attention = 82.0
	sc.composure = 88.0
	sc._finish(true)
	await get_tree().process_frame
	_scan("Lecture completion", sc)
	sc.queue_free()
	await get_tree().process_frame

func _audit_gym() -> void:
	Game.current_scenario_id = "gym_capstone"
	var sc: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	sc.setup({"scenario": _json("res://data/scenarios/gym_capstone.json")})
	await get_tree().process_frame
	_scan("Gym menu", sc)
	sc._dialogue.text = "Priya: \"I can explain my fraction if I get a second, but everyone is moving on before I finish the whole idea.\""
	await get_tree().process_frame
	_scan("Gym long dialogue", sc)
	sc._toggle_input_mode()
	await get_tree().process_frame
	_scan("Gym type", sc)
	for s in sc.students:
		s["resolved"] = true
		s["u"] = 0.88
	sc.composure = 84.0
	sc.order = 82.0
	sc._finish(true)
	await get_tree().process_frame
	_scan("Gym completion", sc)
	sc.queue_free()
	await get_tree().process_frame

func _audit_group_checkin() -> void:
	var sc: Node = load("res://scenes/encounter/GroupCheckIn.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	sc.setup({"scenario_context": {"id": "group_work_fractions", "title": "Group Investigation", "badge": "balance"}})
	await get_tree().process_frame
	_scan("GroupCheckIn", sc)
	sc._dialogue.text = "Talia: \"We all agree that eighths are bigger because eight is bigger than four, but Sam has another idea and is not getting airtime.\""
	await get_tree().process_frame
	_scan("GroupCheckIn long dialogue", sc)
	sc.understanding = 0.82
	sc.participation = 0.78
	sc.revealed = true
	sc._check_win()
	await get_tree().process_frame
	_scan("GroupCheckIn completion", sc)
	sc.queue_free()
	await get_tree().process_frame

func _audit_scene(label: String, sc: Node) -> void:
	add_child(sc)
	await get_tree().process_frame
	_scan(label, sc)
	sc.queue_free()
	await get_tree().process_frame

func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}

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

func _scan(label: String, root: Node) -> void:
	var controls := _visible_controls(root)
	for c in controls:
		if c is TextureRect:
			continue
		var r := _rect(c)
		if r.size.x <= 0.5 or r.size.y <= 0.5:
			continue
		if not _inside_scroll(c) and not VIEW.encloses(r):
			_issues.append("%s clipped: %s %s" % [label, _node_name(c), str(r)])
		_scan_text_fit(label, c)
	var interactives := controls.filter(func(c): return _is_interactive(c) and (not _inside_scroll(c) or _visible_in_scroll(c)))
	for i in range(interactives.size()):
		for j in range(i + 1, interactives.size()):
			var a: Control = interactives[i]
			var b: Control = interactives[j]
			if _ancestor_related(a, b):
				continue
			var ar := _rect(a)
			var br := _rect(b)
			if ar.intersects(br):
				var area := ar.intersection(br).get_area()
				if area > 24.0:
					_issues.append("%s overlap: %s %s with %s %s" % [label, _node_name(a), str(ar), _node_name(b), str(br)])
	var labels := controls.filter(func(c): return c is Label and (not _inside_scroll(c) or _visible_in_scroll(c)))
	for lc in labels:
		var l: Label = lc
		if l.text.strip_edges() == "" or _under_interactive(l):
			continue
		var lr := _label_text_rect(l)
		if lr.size.x <= 0.5 or lr.size.y <= 0.5:
			continue
		for ic in interactives:
			var target: Control = ic
			if _ancestor_related(l, target):
				continue
			if not _draws_after(target, l):
				continue
			var tr := _rect(target)
			if lr.intersects(tr):
				var hit := lr.intersection(tr)
				var text_area := hit.get_area()
				if text_area > 18.0 and hit.size.x > 3.0 and hit.size.y > 3.0:
					_issues.append("%s text occluded: %s %s by %s %s text=%s" % [label, _node_name(l), str(lr), _node_name(target), str(tr), _quote_text(l.text)])

func _scan_text_fit(label: String, c: Control) -> void:
	if c is Button:
		var b: Button = c
		if b.text.strip_edges() != "":
			var bmin := b.get_combined_minimum_size()
			var br := b.get_global_rect()
			if bmin.x > br.size.x + 2.0 or bmin.y > br.size.y + 2.0:
				_issues.append("%s button text overflow: %s min=%s rect=%s text=%s" % [label, _node_name(b), str(bmin), str(br), _quote_text(b.text)])
	if not (c is Label):
		return
	var l: Label = c
	if l.text.strip_edges() == "":
		return
	if l.has_method("get_line_count") and l.has_method("get_visible_line_count"):
		var lines := int(l.call("get_line_count"))
		var visible := int(l.call("get_visible_line_count"))
		if visible > 0 and lines > visible and not _intentional_short_clip(l):
			_issues.append("%s text clipped: %s lines=%d visible=%d text=%s" % [label, _node_name(l), lines, visible, _quote_text(l.text)])
			return
	var min_size := l.get_combined_minimum_size()
	var r := l.get_global_rect()
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF and min_size.x > r.size.x + 2.0 and not _intentional_short_clip(l):
		_issues.append("%s text overflow: %s min=%s rect=%s text=%s" % [label, _node_name(l), str(min_size), str(r), _quote_text(l.text)])
	_scan_container_padding(label, l)

func _scan_container_padding(label: String, l: Label) -> void:
	if not l.has_meta("qa_container_rect") or not l.has_meta("qa_text_rect"):
		return
	var container: Rect2 = l.get_meta("qa_container_rect")
	var authored_text: Rect2 = l.get_meta("qa_text_rect")
	var min_padding := float(l.get_meta("qa_min_padding", 4.0))
	if authored_text.size.x <= 0.0 or authored_text.size.y <= 0.0:
		return
	var scale_x := l.position.x / authored_text.position.x if authored_text.position.x != 0.0 else l.size.x / authored_text.size.x
	var scale_y := l.position.y / authored_text.position.y if authored_text.position.y != 0.0 else l.size.y / authored_text.size.y
	var scale := maxf(1.0, minf(scale_x, scale_y))
	var actual_container := Rect2(container.position * scale, container.size * scale)
	var actual_text := Rect2(l.position, l.size)
	var inset := actual_container.grow(-min_padding * scale)
	if not inset.encloses(actual_text):
		_issues.append("%s dialogue padding tight: %s container=%s text=%s min_pad=%.1f" % [label, _node_name(l), str(actual_container), str(actual_text), min_padding * scale])

func _intentional_short_clip(l: Label) -> bool:
	if not l.clip_text:
		return false
	var t := l.text.strip_edges()
	return t.ends_with("...") or t.length() <= 18

func _quote_text(text: String) -> String:
	return "\"%s\"" % _truncate_for_audit(text.replace("\n", " "), 80)

func _truncate_for_audit(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 3) + "..."

func _visible_controls(root: Node) -> Array:
	var out: Array = []
	_walk(root, out)
	return out

func _walk(n: Node, out: Array) -> void:
	if n is Control:
		var c: Control = n
		if not c.visible:
			return
		out.append(c)
	for ch in n.get_children():
		_walk(ch, out)

func _rect(c: Control) -> Rect2:
	return c.get_global_rect()

func _label_text_rect(l: Label) -> Rect2:
	var r := l.get_global_rect()
	var min_size := l.get_combined_minimum_size()
	var text_size := r.size
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		text_size = Vector2(min_size.x, maxf(r.size.y, min_size.y))
	elif r.size.x <= 0.5 or r.size.y <= 0.5:
		text_size = min_size
	return Rect2(r.position, text_size).grow(-1.0)

func _is_interactive(c: Control) -> bool:
	for cls in INTERACTIVE:
		if c.is_class(cls):
			return true
	return false

func _ancestor_related(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)

func _under_interactive(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is Control and _is_interactive(p as Control):
			return true
		p = p.get_parent()
	return false

func _draws_after(a: Control, b: Control) -> bool:
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	var common := _common_parent(a, b)
	if common == null:
		return true
	var abranch := _branch_under(common, a)
	var bbranch := _branch_under(common, b)
	if abranch == null or bbranch == null or abranch == bbranch:
		return true
	return abranch.get_index() > bbranch.get_index()

func _common_parent(a: Node, b: Node) -> Node:
	var p := a
	while p != null:
		if p == b or p.is_ancestor_of(b):
			return p
		p = p.get_parent()
	return null

func _branch_under(parent: Node, child: Node) -> Node:
	var n := child
	var p := child.get_parent()
	while p != null and p != parent:
		n = p
		p = p.get_parent()
	return n if p == parent else null

func _inside_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _visible_in_scroll(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			var sr := (p as ScrollContainer).get_global_rect()
			var cr := c.get_global_rect()
			return sr.intersects(cr) and sr.intersection(cr).get_area() > 24.0
		p = p.get_parent()
	return true

func _node_name(c: Control) -> String:
	return "%s(%s)" % [c.name, c.get_class()]
