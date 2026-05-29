extends Node
## Headless check of Lecture mode: a present/check rhythm should finish the lesson with
## comprehension + attention healthy and award the badge.

func _ready() -> void:
	GameState.badges = []
	Game.start_lesson("lecture_fractions", 120.0)
	var f := FileAccess.open("res://data/scenarios/lecture_fractions.json", FileAccess.READ)
	var cfg = JSON.parse_string(f.get_as_text())
	f.close()
	var sc: Control = load("res://scenes/encounter/LectureScene.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	sc.setup({"scenario": cfg})
	await get_tree().process_frame

	var guard := 0
	while not sc._over and guard < 50:
		guard += 1
		if sc.comprehension < 55.0 and guard % 5 == 0:
			sc._on_move("poll")
		elif guard % 2 == 0:
			sc._select(guard % sc.students.size())
			sc._on_move("ask")
		else:
			sc._on_move("present")
		await get_tree().process_frame
		await get_tree().process_frame

	print("LECTURE progress=%.0f comp=%.0f attn=%.0f composure=%.0f over=%s badges=%s" % [
		sc.progress, sc.comprehension, sc.attention, sc.composure, str(sc._over), str(GameState.badges)])
	if sc.progress >= 100.0 and ("routine" in GameState.badges):
		print("LECTURE TEST: PASS")
	else:
		print("LECTURE TEST: FAIL")
	get_tree().quit()
