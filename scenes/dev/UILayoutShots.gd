extends Node

const OUT_DIR := "res://tools/"

func _ready() -> void:
	print("UI shots start")
	get_window().size = Vector2i(960, 540)
	LLMClient.use_stub = true
	TTSClient.enabled = false
	GameState.settings["text_reveal"] = "instant"
	GameState.settings["reduced_motion"] = true
	GameState.badges = []
	GameState.attempts = {}
	GameState.relationships = {}
	GameState.teacher_xp = 260
	GameState.teacher_level = 2
	GameState.upgrade_points = 1
	GameState.leaderboard_records = [
		{"rank": "A", "score": 236, "title": "Intro to Fractions", "detail": "Comp 85%  Attention 91%  Progress 100%", "level_up": true},
		{"rank": "B", "score": 196, "title": "Comparing Decimals", "detail": "Objectives 2/2  Attention 78%  Engaged 6/6", "level_up": false},
		{"rank": "B", "score": 182, "title": "Jordan Encounter", "detail": "Jordan reached in 4 turns; bond 25%", "level_up": false},
	]
	_seed_competencies()
	Game.clear_lesson()

	await _shot_plain("ui_login.png", "res://scenes/ui/Login.tscn")
	await _shot_hub()
	await _shot_plain("ui_import.png", "res://scenes/ui/ImportLesson.tscn")
	await _shot_preview()
	await _shot_encounter()
	await _shot_lecture()
	await _shot_gym()
	await _shot_plain("ui_group.png", "res://scenes/encounter/GroupCheckIn.tscn")
	get_tree().quit()

func _shot_plain(name: String, path: String) -> void:
	var sc: Node = load(path).instantiate()
	add_child(sc)
	await _frames(10)
	await _save(name)
	sc.queue_free()
	await _frames(3)

func _shot_hub() -> void:
	var sc: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(sc)
	await _frames(10)
	await _save("ui_hub.png")
	GameState.upgrade_points = 0
	sc._open_upgrades_or_explain()
	await _frames(6)
	await _save("ui_notice_upgrade.png")
	var upgrade_notice := sc.get_node_or_null("NoticeOverlay")
	if upgrade_notice != null:
		upgrade_notice.queue_free()
	await _frames(3)
	sc._open_locked_mission_notice("group_work_fractions", _json("res://data/scenarios/group_work_fractions.json"))
	await _frames(6)
	await _save("ui_notice_locked.png")
	var locked_notice := sc.get_node_or_null("NoticeOverlay")
	if locked_notice != null:
		locked_notice.queue_free()
	await _frames(3)
	GameState.upgrade_points = 1
	sc._open_mission_briefing("lecture_fractions")
	await _frames(6)
	await _save("ui_briefing.png")
	var brief := sc.get_node_or_null("MissionBriefingOverlay")
	if brief != null:
		brief.queue_free()
	await _frames(3)
	sc._open_evidence_journal()
	await _frames(6)
	await _save("ui_evidence.png")
	var evidence := sc.get_node_or_null("EvidenceJournalOverlay")
	if evidence != null:
		evidence.queue_free()
	await _frames(3)
	sc._open_leaderboard()
	await _frames(6)
	await _save("ui_leaderboard.png")
	var board := sc.get_node_or_null("LeaderboardOverlay")
	if board != null:
		board.queue_free()
	await _frames(3)
	sc._open_settings()
	await _frames(6)
	await _save("ui_settings.png")
	var settings := sc.get_node_or_null("SettingsOverlay")
	if settings != null:
		settings.queue_free()
	await _frames(3)
	sc._open_upgrades()
	await _frames(6)
	await _save("ui_upgrades.png")
	var upgrades := sc.get_node_or_null("UpgradeOverlay")
	if upgrades != null:
		upgrades.queue_free()
	await _frames(3)
	sc._open_items()
	await _frames(6)
	await _save("ui_items.png")
	var items := sc.get_node_or_null("ItemsOverlay")
	if items != null:
		items.queue_free()
	await _frames(3)
	sc.queue_free()
	await _frames(3)

func _shot_preview() -> void:
	var sc: Node = load("res://scenes/ui/PreviewScenario.tscn").instantiate()
	add_child(sc)
	await _frames(4)
	sc.setup({"scenario": _json("res://data/scenarios/reading_main_idea.json")})
	await _frames(10)
	await _save("ui_preview.png")
	sc.queue_free()
	await _frames(3)

func _shot_encounter() -> void:
	Game.current_scenario_id = "discussion_fractions"
	var sc: Node = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(sc)
	await _frames(4)
	sc.setup({"persona_id": "jordan_skeptic", "display_name": "Jordan"})
	await _frames(10)
	await _save("ui_encounter_menu.png")
	sc._toggle_input_mode()
	sc._text_input.text = "Can you walk me through how you got that?"
	await _frames(10)
	await _save("ui_encounter_type.png")
	sc.queue_free()
	await _frames(3)

func _shot_lecture() -> void:
	Game.current_scenario_id = "lecture_fractions"
	var sc: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(sc)
	await _frames(4)
	sc.setup({"scenario": _json("res://data/scenarios/lecture_fractions.json")})
	await _frames(10)
	await _save("ui_lecture_menu.png")
	sc._toggle_input_mode()
	sc._text_input.text = "Show me with your fingers if the denominator is the number of equal parts."
	await _frames(10)
	await _save("ui_lecture_type.png")
	sc.queue_free()
	await _frames(3)

func _shot_gym() -> void:
	Game.current_scenario_id = "gym_capstone"
	var sc: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(sc)
	await _frames(4)
	sc.setup({"scenario": _json("res://data/scenarios/gym_capstone.json")})
	await _frames(10)
	await _save("ui_gym_menu.png")
	sc._toggle_input_mode()
	sc._text_input.text = "Noah, explain what part you are using as the whole."
	await _frames(10)
	await _save("ui_gym_type.png")
	sc.queue_free()
	await _frames(3)

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
		"group_monitoring": {"theta": 0.10, "n": 3.0},
		"status_treatment": {"theta": -0.28, "n": 2.0},
	}
	for k in sample.keys():
		Competency.theta[k] = float(sample[k]["theta"])
		Competency.n[k] = float(sample[k]["n"])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + name)
	var err := img.save_png(path)
	print("saved ", name, " ", img.get_size())
	if err != OK:
		push_error("Failed to save %s: %s" % [path, str(err)])
