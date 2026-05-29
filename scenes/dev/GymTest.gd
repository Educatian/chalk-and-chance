extends Node
## Headless check of the Gym (multi-student) mode: round-robin each student's win move
## until all resolve; confirm the win path is reachable and meters survive.

func _ready() -> void:
	GameState.badges = []
	var f := FileAccess.open("res://data/scenarios/gym_capstone.json", FileAccess.READ)
	var cfg = JSON.parse_string(f.get_as_text())
	f.close()
	var enc: Control = load("res://scenes/encounter/GymEncounter.tscn").instantiate()
	add_child(enc)
	await get_tree().process_frame
	enc.setup({"scenario": cfg})
	await get_tree().process_frame

	var guard := 0
	while not enc._over and guard < 60:
		guard += 1
		for i in range(enc.students.size()):
			if enc.students[i].get("resolved", false):
				continue
			enc._select(i)
			var wm: Array = enc.students[i]["win_moves"]
			var mv: String = str(wm[0])
			if mv == "wait" and wm.size() > 1:
				mv = str(wm[1])
			enc._on_move(mv)
			await get_tree().process_frame

	var resolved := 0
	for s in enc.students:
		if s.get("resolved", false):
			resolved += 1
	print("GYM resolved=%d/%d composure=%.0f order=%.0f over=%s badges=%s" % [
		resolved, enc.students.size(), enc.composure, enc.order, str(enc._over), str(GameState.badges)])
	if resolved == enc.students.size() and ("insight" in GameState.badges):
		print("GYM TEST: PASS")
	else:
		print("GYM TEST: FAIL")
	get_tree().quit()
