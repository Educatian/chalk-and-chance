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

	var caps := {"ushape": 9, "ushape6": 6, "rows": 15, "rows8": 8, "clusters": 16, "clusters8": 8, "pairs": 12}
	var cap: int = caps.get(s["arrangement"], 9)
	var seats_ok := true
	for r in s["roster"]:
		if int(r["seat"]) < 0 or int(r["seat"]) >= cap:
			seats_ok = false
	print("SEATS_VALID=%s" % str(seats_ok))

	var path := Game.scenario_path(id)
	print("RELOAD path=%s exists=%s" % [path, str(FileAccess.file_exists(path))])
	# Korean plan: format, length, subject and topic room come through; the id is unique.
	var kf := FileAccess.open("res://tools/sample_lesson_plan_ko.md", FileAccess.READ)
	var ks := LessonImport.plan_to_scenario(kf.get_as_text())
	kf.close()
	var ko_ok: bool = str(ks["format"]) == "discussion" and int(ks["period_seconds"]) == 100 \
		and str(ks["title"]).begins_with("소수의 크기 비교") and str(ks.get("art_from", "")) == "custom_comparing_decimals" \
		and str(ks["id"]).begins_with("custom_lesson_") and str(ks["id"]) != "custom_lesson"
	print("KOREAN_PLAN fmt=%s period=%d id=%s art=%s ok=%s" % [ks["format"], int(ks["period_seconds"]), ks["id"], ks.get("art_from", ""), str(ko_ok)])
	var exported := FileAccess.get_file_as_string("res://export_presets.cfg").contains("tools/sample_lesson_plan_ko.md")
	print("SAMPLES_EXPORTED=%s" % str(exported))
	if seats_ok and FileAccess.file_exists(path) and ko_ok and exported:
		print("IMPORT TEST: PASS")
	else:
		print("IMPORT TEST: FAIL")
	get_tree().quit()
