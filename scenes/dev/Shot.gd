extends Node
## Captures rendered screenshots of the overworld and an encounter, then quits.
## Run WINDOWED (not --headless) so the framebuffer has real pixels:
##   godot --path . res://scenes/dev/Shot.tscn
## Saves PNGs to tools/.

const OUT_DIR := "res://tools/"

func _ready() -> void:
	await _frames(8)

	# 0) Mission hub
	var hub: Node = load("res://scenes/ui/Hub.tscn").instantiate()
	add_child(hub)
	await _frames(8)
	await _save("shot_hub.png")
	hub.queue_free()
	await _frames(3)

	# 0b) Import-a-lesson screen
	var imp: Node = load("res://scenes/ui/ImportLesson.tscn").instantiate()
	add_child(imp)
	await _frames(6)
	imp._text.text = "Grade: 5\nSubject: Comparing Decimals\nDuration: 45 minutes\nFormat: whole-class number talk / discussion\nObjectives: compare decimals by place value; every student contributes at least once.\nAnticipated misconception: more digits means bigger (0.45 > 0.5)."
	imp._status.text = "Paste or load a plan, then Generate & Play."
	await _frames(3)
	await _save("shot_import.png")
	imp.queue_free()
	await _frames(3)

	# 0c) Preview / adjust screen (fed a sample generated scenario)
	var prev: Node = load("res://scenes/ui/PreviewScenario.tscn").instantiate()
	add_child(prev)
	await _frames(2)
	var sf := FileAccess.open("res://data/scenarios/reading_main_idea.json", FileAccess.READ)
	var sd = JSON.parse_string(sf.get_as_text())
	sf.close()
	prev.setup({"scenario": sd})
	await _frames(3)
	await _save("shot_preview.png")
	prev.queue_free()
	await _frames(3)

	# 0d) Gym (multi-student boss) encounter
	Game.current_scenario_id = "gym_capstone"
	var gf := FileAccess.open("res://data/scenarios/gym_capstone.json", FileAccess.READ)
	var gcfg = JSON.parse_string(gf.get_as_text())
	gf.close()
	var gym: Node = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(gym)
	await _frames(2)
	gym.setup({"scenario": gcfg})
	await _frames(3)
	gym._select(0)
	gym._on_move("elicit")
	await _frames(2)
	gym._select(1)
	gym._on_move("redirect")
	await _frames(3)
	await _save("shot_gym.png")
	gym.queue_free()
	await _frames(3)
	Game.current_scenario_id = "discussion_fractions"

	# 1) Overworld - turn the teacher to the board so students drift (withitness demo)
	var ow: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(ow)
	await _frames(6)
	if ow._player != null:
		ow._player.facing = Vector2i(0, -1)   # face the board, back to class
	await _frames(220)                        # ~3.5s of drift
	await _save("shot_overworld.png")
	ow._trigger_interrupt()                   # force an interrupt event
	await _frames(5)
	await _save("shot_interrupt.png")
	ow.queue_free()
	await _frames(3)

	# 1b) Lecture mode (reactive students; present/check rhythm)
	Game.current_scenario_id = "lecture_fractions"
	Game.start_lesson("lecture_fractions", 120.0)
	var lf := FileAccess.open("res://data/scenarios/lecture_fractions.json", FileAccess.READ)
	var lcfg = JSON.parse_string(lf.get_as_text())
	lf.close()
	var lec: Node = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(lec)
	await _frames(2)
	lec.setup({"scenario": lcfg})
	await _frames(3)
	lec._on_move("present")
	await _frames(2)
	lec._on_move("present")
	await _frames(2)
	lec._on_move("present")        # students drift (reaction)
	await _frames(3)
	lec._select(2)
	lec._on_move("ask")            # a check (reaction on the called student)
	await _frames(4)
	await _save("shot_lecture.png")
	lec.queue_free()
	await _frames(3)

	# 1c) Group work scene (clusters arrangement)
	Game.current_scenario_id = "group_work_fractions"
	var owg: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(owg)
	await _frames(10)
	await _save("shot_groupwork.png")
	owg.queue_free()
	await _frames(3)

	# 1d) Imported lesson plan -> custom scenario (comparing decimals)
	Game.current_scenario_id = "custom_comparing_decimals"
	var owc: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(owc)
	await _frames(10)
	await _save("shot_custom.png")
	owc.queue_free()
	await _frames(3)

	# 2) Encounter with Noah in the imported decimals lesson (shows content-specific lines)
	var enc: Control = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(enc)
	await _frames(2)
	enc.setup({"persona_id": "noah_g5_fractions", "display_name": "Noah"})
	await _frames(3)
	enc._on_move("elicit")
	await _frames(4)
	enc._on_move("extend")
	await _frames(4)
	await _save("shot_encounter.png")
	enc.queue_free()
	await _frames(3)

	# 3) Independent-work scene (rows, 8 students) + debrief overlay
	Game.current_scenario_id = "independent_fractions"
	var owi: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(owi)
	await _frames(10)
	await _save("shot_independent.png")
	owi._end_lesson()
	await _frames(5)
	await _save("shot_debrief.png")
	owi.queue_free()
	await _frames(3)
	Game.current_scenario_id = "discussion_fractions"

	get_tree().quit()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + name)
	print("saved ", name, " ", img.get_size())
