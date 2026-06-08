extends Control
## Review & adjust a generated scenario before playing (lesson-plan import preview).
## Receives {"scenario": <dict>} via setup(); lets the teacher tweak period / drop a student,
## then saves to user://scenarios and plays.

const LessonImport = preload("res://scripts/LessonImport.gd")
const Art = preload("res://scripts/Art.gd")
const PixelUi = preload("res://scripts/PixelUi.gd")

var _scenario: Dictionary = {}
var _summary: Label
var _validation: Label
var _play_button: Button
var _summary_scroll: ScrollContainer
var _backdrop: TextureRect
var _story: Label

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

	_draw_equipped_items(Vector2(470, 26))

	var panel := Panel.new()   # themed rounded panel
	panel.position = Vector2(42, 78)
	panel.size = Vector2(vp.x - 84, vp.y - 186)
	add_child(panel)

	_summary_scroll = ScrollContainer.new()
	_summary_scroll.position = Vector2(58, 94)
	_summary_scroll.size = Vector2(vp.x - 426, vp.y - 222)
	_summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_summary_scroll)

	_summary = Label.new()
	_summary.position = Vector2.ZERO
	_summary.custom_minimum_size = Vector2(vp.x - 442, 0)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 16)
	_summary.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9))
	_summary_scroll.add_child(_summary)

	_backdrop = TextureRect.new()
	_backdrop.position = Vector2(vp.x - 342, 96)
	_backdrop.size = Vector2(282, 158)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_story = Label.new()
	_story.position = Vector2(vp.x - 342, 266)
	_story.size = Vector2(282, 112)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.add_theme_font_size_override("font_size", 13)
	_story.add_theme_color_override("font_color", Color(0.82, 0.86, 0.78))
	add_child(_story)

	_validation = Label.new()
	_validation.position = Vector2(62, vp.y - 126)
	_validation.size = Vector2(vp.x - 124, 34)
	_validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation.add_theme_font_size_override("font_size", 13)
	add_child(_validation)

	var by := vp.y - 70
	var bw := 150.0
	var gap := 12.0
	var x := 42.0
	_make_btn("- 15s", x, by, 90, _on_period_down); x += 90 + gap
	_make_btn("+ 15s", x, by, 90, _on_period_up); x += 90 + gap
	_make_btn("Remove a student", x, by, 180, _on_remove); x += 180 + gap
	var play := _make_btn("Play this lesson", x, by, 190, _on_play); x += 190 + gap
	_play_button = play
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

func _draw_equipped_items(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "Loadout"
	label.position = pos
	label.size = Vector2(86, 20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	add_child(label)
	var x := pos.x + 82.0
	for id in GameState.equipped_item_ids():
		var item_id := str(id)
		var tex := Art.tex(Items.icon_for(item_id))
		var slot := Panel.new()
		slot.position = Vector2(x, pos.y - 4)
		slot.size = Vector2(34, 34)
		slot.tooltip_text = "%s x%d" % [Items.name_for(item_id), GameState.item_count(item_id)]
		add_child(slot)
		if tex != null:
			PixelUi.add_centered_icon(slot, tex, 3.0)
		x += 38.0

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
	var first_move := _first_recommended_move()
	var errors := _validate_scenario(_scenario)
	_summary.text = "%s\n\nYour class: %d students (%s)\nYour challenge: keep the room with you while every learner contributes.\nWin condition: meet the objective checklist before the period ends.\nFirst recommended move: %s\n%s\n%s\n\nFormat: %s     Seating: %s     Period: %ds     Badge: %s\nConversion: %s\n\nObjectives:\n%s" % [
		str(_scenario.get("title", "Lesson")),
		names.size(), ", ".join(names), first_move,
		Game.scenario_signature(_scenario),
		Game.scenario_edge_label(_scenario),
		str(_scenario.get("format", "?")), str(_scenario.get("arrangement", "?")),
		int(_scenario.get("period_seconds", 120)), str(_scenario.get("badge", "")),
		src, objs]
	if _validation != null:
		if errors.is_empty():
			_validation.text = "Scenario check passed."
			_validation.add_theme_color_override("font_color", Color(0.68, 0.92, 0.72))
		else:
			_validation.text = "Fix before playing: " + "; ".join(errors)
			_validation.add_theme_color_override("font_color", Color(0.95, 0.56, 0.48))
	if _play_button != null:
		_play_button.disabled = not errors.is_empty()
	if _backdrop != null:
		_backdrop.texture = Art.tex(Art.scenario_backdrop_path(_scenario, str(_scenario.get("id", "")), false))
	if _story != null:
		_story.text = str(_scenario.get("story_hook", ""))

func _first_recommended_move() -> String:
	var fmt := str(_scenario.get("format", ""))
	match fmt:
		"lecture":
			return "Present a short chunk, wait, then Question a highlighted student."
		"group_work":
			return "Visit one pod, Listen, Surface, then Redistribute airtime."
		"independent":
			return "Circulate first, then confer with a student who is drifting."
	return "Talk to one student, Elicit their reasoning, then use Wait before pressing further."

func _validate_scenario(scenario: Dictionary) -> Array:
	var errors: Array = []
	for key in ["id", "title", "format", "mode", "arrangement", "roster", "objectives", "badge"]:
		if not scenario.has(key):
			errors.append("missing %s" % key)
	var fmt := str(scenario.get("format", ""))
	var mode := str(scenario.get("mode", ""))
	if not (fmt in ["discussion", "lecture", "group_work", "independent"]):
		errors.append("unknown format")
	if not (mode in ["overworld", "lecture", "gym"]):
		errors.append("unknown mode")
	var roster = scenario.get("roster", [])
	if typeof(roster) != TYPE_ARRAY or roster.size() < 2:
		errors.append("needs at least 2 students")
	else:
		var overrides: Dictionary = scenario.get("persona_overrides", {})
		for r in roster:
			if typeof(r) != TYPE_DICTIONARY or str(r.get("id", r.get("persona_id", ""))) == "":
				errors.append("each student needs an id")
				break
			var pid := str(r.get("id", r.get("persona_id", "")))
			if typeof(overrides) == TYPE_DICTIONARY and overrides.has(pid):
				var po = overrides.get(pid, {})
				if typeof(po) != TYPE_DICTIONARY or str(po.get("opening_line", "")) == "" or str(po.get("target_label", "")) == "" or str(po.get("win_line", "")) == "" or typeof(po.get("win_moves", [])) != TYPE_ARRAY:
					errors.append("persona override incomplete for %s" % pid)
					break
	var objectives = scenario.get("objectives", [])
	if typeof(objectives) != TYPE_ARRAY or objectives.is_empty():
		errors.append("needs objectives")
	if int(scenario.get("period_seconds", 0)) < 60:
		errors.append("period too short")
	return errors

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
