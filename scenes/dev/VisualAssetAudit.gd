extends Node

const MIN_TEXTURE_RECT := 16.0
const MIN_SPRITE_EDGE := 12.0
const MAX_SPRITE_SQUASH := 0.08

var _issues: Array = []

func _ready() -> void:
	LLMClient.use_stub = true
	TTSClient.enabled = false
	GameState.settings["text_reveal"] = "instant"
	GameState.settings["reduced_motion"] = true
	GameState.badges = []
	GameState.attempts = {}
	GameState.relationships = {}
	GameState.leaderboard_records = [
		{"rank": "A", "score": 236, "title": "Intro to Fractions", "detail": "Comp 85%  Attention 91%  Progress 100%"},
	]
	Game.clear_lesson()

	_scan_required_assets()
	await _audit_scene("Login", load("res://scenes/ui/Login.tscn").instantiate())
	await _audit_hub()
	await _audit_preview()
	await _audit_encounter()
	await _audit_lecture()
	await _audit_gym()
	await _audit_scene("GroupCheckIn", load("res://scenes/encounter/GroupCheckIn.tscn").instantiate())
	await _audit_overworld("discussion_fractions")
	await _audit_overworld("group_work_fractions")

	if _issues.is_empty():
		print("VISUALASSET PASS")
	else:
		print("VISUALASSET FAIL %d issue(s)" % _issues.size())
		for i in _issues:
			print(i)
	get_tree().quit()

func _audit_hub() -> void:
	var sc: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(sc)
	await _frames(2)
	_scan("Hub", sc)
	await _scan_hub_overlay(sc, "Hub briefing", func(): sc._open_mission_briefing("lecture_fractions"), "MissionBriefingOverlay")
	await _scan_hub_overlay(sc, "Hub evidence", func(): sc._open_evidence_journal(), "EvidenceJournalOverlay")
	await _scan_hub_overlay(sc, "Hub leaderboard", func(): sc._open_leaderboard(), "LeaderboardOverlay")
	await _scan_hub_overlay(sc, "Hub settings", func(): sc._open_settings(), "SettingsOverlay")
	await _scan_hub_overlay(sc, "Hub upgrades", func(): sc._open_upgrades(), "UpgradeOverlay")
	await _scan_hub_overlay(sc, "Hub items", func(): sc._open_items(), "ItemsOverlay")
	sc.queue_free()
	await _frames(1)

func _scan_hub_overlay(sc: Node, label: String, opener: Callable, overlay_name: String) -> void:
	opener.call()
	await _frames(2)
	var overlay := sc.get_node_or_null(overlay_name)
	if overlay != null:
		_scan(label, overlay)
		overlay.queue_free()
	await _frames(1)

func _audit_preview() -> void:
	var sc: Node = load("res://scenes/ui/PreviewScenario.tscn").instantiate()
	add_child(sc)
	await _frames(1)
	sc.setup({"scenario": _json("res://data/scenarios/reading_main_idea.json")})
	await _frames(2)
	_scan("PreviewScenario", sc)
	sc.queue_free()
	await _frames(1)

func _audit_encounter() -> void:
	Game.current_scenario_id = "discussion_fractions"
	var sc: Node = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(sc)
	await _frames(1)
	sc.setup({"persona_id": "jordan_skeptic", "display_name": "Jordan"})
	await _frames(2)
	_scan("Encounter menu", sc)
	sc._toggle_input_mode()
	await _frames(2)
	_scan("Encounter type", sc)
	sc.queue_free()
	await _frames(1)

func _audit_lecture() -> void:
	Game.current_scenario_id = "lecture_fractions"
	var sc: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(sc)
	await _frames(1)
	sc.setup({"scenario": _json("res://data/scenarios/lecture_fractions.json")})
	await _frames(2)
	_scan("Lecture menu", sc)
	sc._toggle_input_mode()
	await _frames(2)
	_scan("Lecture type", sc)
	sc.queue_free()
	await _frames(1)

func _audit_gym() -> void:
	Game.current_scenario_id = "gym_capstone"
	var sc: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(sc)
	await _frames(1)
	sc.setup({"scenario": _json("res://data/scenarios/gym_capstone.json")})
	await _frames(2)
	_scan("Gym menu", sc)
	sc._toggle_input_mode()
	await _frames(2)
	_scan("Gym type", sc)
	sc.queue_free()
	await _frames(1)

func _audit_overworld(id: String) -> void:
	Game.current_scenario_id = id
	Game.clear_lesson()
	var sc: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(sc)
	await _frames(4)
	_scan("Overworld %s" % id, sc)
	sc.queue_free()
	await _frames(1)

func _audit_scene(label: String, sc: Node) -> void:
	add_child(sc)
	await _frames(3)
	_scan(label, sc)
	sc.queue_free()
	await _frames(1)

func _scan_required_assets() -> void:
	var scenario_ids := [
		"lecture_fractions", "independent_fractions", "discussion_fractions",
		"group_work_fractions", "reading_main_idea", "science_force_motion",
		"culturally_responsive_intro", "custom_comparing_decimals", "gym_capstone",
	]
	for id in scenario_ids:
		_require("res://assets/backdrops/%s.png" % id)
		_require("res://assets/backdrops/%s_thumb.png" % id)
	for id2 in Items.all_ids():
		_require(Items.icon_for(str(id2)))

func _require(path: String) -> void:
	if not ResourceLoader.exists(path):
		_issues.append("missing required asset: %s" % path)

func _scan(label: String, root: Node) -> void:
	_walk(label, root)

func _walk(label: String, n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is TextureRect:
		_check_texture_rect(label, n as TextureRect)
	elif n is Sprite2D:
		_check_sprite(label, n as Sprite2D)
	for ch in n.get_children():
		_walk(label, ch)

func _check_texture_rect(label: String, tr: TextureRect) -> void:
	if not tr.visible:
		return
	if tr.texture == null:
		_issues.append("%s missing texture: %s" % [label, _node_path(tr)])
		return
	var r := tr.get_global_rect()
	if r.size.x < MIN_TEXTURE_RECT or r.size.y < MIN_TEXTURE_RECT:
		_issues.append("%s tiny TextureRect: %s rect=%s tex=%s" % [label, _node_path(tr), str(r), _tex_size(tr.texture)])

func _check_sprite(label: String, spr: Sprite2D) -> void:
	if not spr.visible:
		return
	if spr.texture == null:
		_issues.append("%s missing sprite texture: %s" % [label, _node_path(spr)])
		return
	var sc := spr.get_global_transform().get_scale()
	var drawn := Vector2(absf(sc.x) * float(spr.texture.get_width()), absf(sc.y) * float(spr.texture.get_height()))
	if drawn.x < MIN_SPRITE_EDGE or drawn.y < MIN_SPRITE_EDGE:
		_issues.append("%s tiny Sprite2D: %s drawn=%s tex=%s" % [label, _node_path(spr), str(drawn), _tex_size(spr.texture)])
	if absf(sc.x) > 0.001 and absf(sc.y) > 0.001:
		var ratio := absf(absf(sc.x) / absf(sc.y) - 1.0)
		if ratio > MAX_SPRITE_SQUASH and not _allow_nonuniform_sprite(spr):
			_issues.append("%s squashed Sprite2D: %s scale=%s tex=%s" % [label, _node_path(spr), str(sc), _tex_size(spr.texture)])

func _allow_nonuniform_sprite(spr: Sprite2D) -> bool:
	var p := spr.get_parent()
	while p != null:
		if str(p.name).to_lower().contains("overworld"):
			return true
		p = p.get_parent()
	return false

func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _tex_size(t: Texture2D) -> String:
	return "%dx%d" % [t.get_width(), t.get_height()]

func _node_path(n: Node) -> String:
	return str(n.get_path())
