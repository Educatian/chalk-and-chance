extends Node
## Headless check of the offline lesson-plan import: sample plan -> scenario -> save -> reload.

const LessonImport = preload("res://scripts/LessonImport.gd")

func _ready() -> void:
	var f := FileAccess.open("res://tools/sample_lesson_plan.md", FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var s := LessonImport.plan_to_scenario(txt)
	var id := LessonImport.save_custom(s)
	print("IMPORT id=%s title=%s fmt=%s arr=%s roster=%d period=%d" % [
		id, str(s["title"]), str(s["format"]), str(s["arrangement"]), (s["roster"] as Array).size(), int(s["period_seconds"])])

	var caps := {"ushape": 9, "rows": 15, "clusters": 16, "pairs": 12}
	var cap: int = caps.get(s["arrangement"], 9)
	var seats_ok := true
	for r in s["roster"]:
		if int(r["seat"]) < 0 or int(r["seat"]) >= cap:
			seats_ok = false
	print("SEATS_VALID=%s" % str(seats_ok))

	var path := Game.scenario_path(id)
	print("RELOAD path=%s exists=%s" % [path, str(FileAccess.file_exists(path))])
	if seats_ok and FileAccess.file_exists(path):
		print("IMPORT TEST: PASS")
	else:
		print("IMPORT TEST: FAIL")
	get_tree().quit()
