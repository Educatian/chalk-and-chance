extends Node
## Headless smoke test for the encounter loop (no UI clicks needed).
## Drives Encounter._on_move() through an elicit/extend sequence and asserts the
## understanding gate crosses 0.80 and the Echo badge is awarded.
## Run with scene = res://scenes/dev/SmokeTest.tscn.

func _ready() -> void:
	# Start from a clean slate so a prior save does not mask the result.
	GameState.badges = []
	GameState.student_progress = {}

	# Validate every persona JSON parses and carries a badge field.
	for pid in ["noah_g5_fractions", "talia_dominator", "meilin_anxious", "deshawn_offtask"]:
		var p := "res://data/persona_library/%s.json" % pid
		var ok := false
		var badge := "?"
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				var d = JSON.parse_string(f.get_as_text())
				f.close()
				if typeof(d) == TYPE_DICTIONARY:
					ok = true
					badge = str(d.get("badge", "?"))
		print("PERSONA %-18s ok=%s badge=%s" % [pid, str(ok), badge])

	var enc: Control = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(enc)
	await get_tree().process_frame

	# Asset check: the neutral portrait should be loaded and visible after _ready().
	print("PORTRAIT neutral exists=%s shown=%s size=%s"
		% [ResourceLoader.exists("res://assets/portraits/noah_g5_fractions_neutral.png"),
			str(enc._student_tex.visible),
			str(enc._student_tex.texture.get_size()) if enc._student_tex.texture != null else "null"])

	var script_moves := ["elicit", "extend", "elicit", "extend", "elicit", "extend", "elicit"]
	for m in script_moves:
		if enc._resolved:
			break
		enc._on_move(m)
		await get_tree().process_frame
		await get_tree().process_frame
		print("move=%-7s understanding=%.2f engagement=%.0f rapport=%.0f resolved=%s"
			% [m, enc.understanding, enc.engagement, enc.rapport, str(enc._resolved)])

	print("BADGES: ", GameState.badges)
	if "echo" in GameState.badges and enc._resolved:
		print("SMOKE TEST: PASS")
	else:
		print("SMOKE TEST: FAIL")

	# Differentiated win: Deshawn should NOT resolve via elicit, but should via redirect.
	GameState.badges = []
	Game.start_lesson("test", 120.0)
	var enc2: Control = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(enc2)
	await get_tree().process_frame
	enc2.setup({"persona_id": "deshawn_offtask", "display_name": "Deshawn"})
	await get_tree().process_frame
	for i in range(6):
		enc2._on_move("elicit")
		await get_tree().process_frame
		await get_tree().process_frame
	var elicit_resolved: bool = enc2._resolved
	print("DESHAWN via elicit: understanding=%.2f resolved=%s (expect false)" % [enc2.understanding, str(elicit_resolved)])
	for i in range(9):
		if enc2._resolved:
			break
		enc2._on_move("redirect")
		await get_tree().process_frame
		await get_tree().process_frame
	print("DESHAWN via redirect: understanding=%.2f resolved=%s badges=%s" % [enc2.understanding, str(enc2._resolved), str(GameState.badges)])
	if (not elicit_resolved) and enc2._resolved and ("routine" in GameState.badges):
		print("DIFFERENTIATION: PASS")
	else:
		print("DIFFERENTIATION: FAIL")
	get_tree().quit()
