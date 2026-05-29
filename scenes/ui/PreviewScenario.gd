extends Control
## Review & adjust a generated scenario before playing (lesson-plan import preview).
## Receives {"scenario": <dict>} via setup(); lets the teacher tweak period / drop a student,
## then saves to user://scenarios and plays.

const LessonImport = preload("res://scripts/LessonImport.gd")

var _scenario: Dictionary = {}
var _summary: Label

func _ready() -> void:
	_build_shell()

func setup(data: Dictionary) -> void:
	_scenario = data.get("scenario", {})
	_refresh()

func _build_shell() -> void:
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.size = vp
	bg.color = Color(0.07, 0.09, 0.16)
	add_child(bg)

	var title := Label.new()
	title.text = "REVIEW & ADJUST"
	title.position = Vector2(40, 28)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	add_child(title)

	var panel := Panel.new()   # themed rounded panel
	panel.position = Vector2(42, 78)
	panel.size = Vector2(vp.x - 84, vp.y - 170)
	add_child(panel)

	_summary = Label.new()
	_summary.position = Vector2(62, 98)
	_summary.size = Vector2(vp.x - 124, vp.y - 210)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 16)
	_summary.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9))
	add_child(_summary)

	var by := vp.y - 70
	var bw := 150.0
	var gap := 12.0
	var x := 42.0
	_make_btn("- 15s", x, by, 90, _on_period_down); x += 90 + gap
	_make_btn("+ 15s", x, by, 90, _on_period_up); x += 90 + gap
	_make_btn("Remove a student", x, by, 180, _on_remove); x += 180 + gap
	var play := _make_btn("Play this lesson", x, by, 190, _on_play); x += 190 + gap
	_make_btn("Back", x, by, 110, _on_back)
	play.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	play.grab_focus()

func _make_btn(label: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.position = Vector2(x, y)
	b.size = Vector2(w, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	add_child(b)
	return b

func _refresh() -> void:
	if _summary == null:
		return
	var names: Array = []
	for r in _scenario.get("roster", []):
		names.append(str(r.get("name", "?")))
	var objs := ""
	for o in _scenario.get("objectives", []):
		objs += "  -  %s\n" % str(o.get("label", ""))
	var src := "AI (content-specific)" if _scenario.get("persona_overrides", null) != null else "offline (format + objectives)"
	_summary.text = "%s\n\nFormat: %s     Seating: %s     Period: %ds     Badge: %s\nConversion: %s\n\nStudents (%d):  %s\n\nObjectives:\n%s" % [
		str(_scenario.get("title", "Lesson")),
		str(_scenario.get("format", "?")), str(_scenario.get("arrangement", "?")),
		int(_scenario.get("period_seconds", 120)), str(_scenario.get("badge", "")),
		src, names.size(), ", ".join(names), objs]

func _on_period_down() -> void:
	_scenario["period_seconds"] = max(90, int(_scenario.get("period_seconds", 120)) - 15)
	_refresh()

func _on_period_up() -> void:
	_scenario["period_seconds"] = min(180, int(_scenario.get("period_seconds", 120)) + 15)
	_refresh()

func _on_remove() -> void:
	var ros: Array = _scenario.get("roster", [])
	if ros.size() > 2:
		ros.pop_back()
		_scenario["roster"] = ros
		# keep an engaged_min objective consistent with the new roster size
		for o in _scenario.get("objectives", []):
			if o.get("metric", "") == "engaged_min":
				o["target"] = ros.size()
				o["label"] = "Reach every student (%d)" % ros.size()
		_refresh()

func _on_play() -> void:
	var id := LessonImport.save_custom(_scenario)
	Game.current_scenario_id = id
	Game.clear_lesson()
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _on_back() -> void:
	SceneRouter.change_scene("res://scenes/ui/ImportLesson.tscn")
