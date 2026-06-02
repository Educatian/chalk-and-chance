extends Control
## Mission-select hub. Lists the scenarios from Game.SCENARIOS (reading each JSON for its
## title/badge), shows which badges are earned, and routes to the chosen scenario.

const Art = preload("res://scripts/Art.gd")

func _ready() -> void:
	_build()

func setup(_data: Dictionary) -> void:
	pass

func _build() -> void:
	var vp := get_viewport_rect().size
	var fd := GameState.ui_font_delta()

	var bg := ColorRect.new()
	bg.size = vp
	bg.color = Color(0.07, 0.09, 0.16)
	add_child(bg)

	var title := Label.new()
	title.text = "CHALK & CHANCE"
	title.position = Vector2(40, 26)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 26 + fd)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.14))
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)

	var sub := Label.new()
	sub.text = "Start with demo lessons. Unlock harder classrooms."
	sub.position = Vector2(42, 74)
	sub.size = Vector2(410, 22)
	sub.clip_text = false
	sub.add_theme_font_size_override("font_size", 15 + fd)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	add_child(sub)

	var level := Label.new()
	level.text = "Teacher Level %d   XP %d/%d   Next +1 upgrade in %d XP   Points %d" % [
		GameState.teacher_level,
		GameState.teacher_xp,
		GameState.xp_for_level(GameState.teacher_level + 1),
		GameState.xp_to_next_level(),
		GameState.upgrade_points,
	]
	level.position = Vector2(42, 98)
	level.size = Vector2(vp.x - 260, 20)
	level.add_theme_font_size_override("font_size", 13 + fd)
	level.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	add_child(level)

	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(42, 122)
	xp_bg.size = Vector2(240, 9)
	xp_bg.color = Color(0, 0, 0, 0.52)
	add_child(xp_bg)
	var xp_fill := ColorRect.new()
	xp_fill.position = xp_bg.position
	xp_fill.size = Vector2(240.0 * GameState.level_progress(), 9)
	xp_fill.color = Color(0.35, 0.78, 0.42)
	add_child(xp_fill)

	var evidence := Button.new()
	evidence.text = "Evidence"
	evidence.position = Vector2(vp.x - 486, 74)
	evidence.size = Vector2(118, 34)
	evidence.add_theme_font_size_override("font_size", 12 + fd)
	evidence.pressed.connect(_open_evidence_journal)
	add_child(evidence)

	var upgrades := Button.new()
	upgrades.text = "Upgrade"
	upgrades.position = Vector2(vp.x - 358, 74)
	upgrades.size = Vector2(104, 34)
	upgrades.add_theme_font_size_override("font_size", 12 + fd)
	upgrades.disabled = GameState.upgrade_points <= 0
	upgrades.pressed.connect(_open_upgrades)
	add_child(upgrades)

	var items := Button.new()
	items.text = "Items"
	items.position = Vector2(vp.x - 244, 74)
	items.size = Vector2(74, 34)
	items.add_theme_font_size_override("font_size", 12 + fd)
	items.pressed.connect(_open_items)
	add_child(items)

	var board := Button.new()
	board.text = "Board"
	board.position = Vector2(vp.x - 154, 74)
	board.size = Vector2(84, 34)
	board.add_theme_font_size_override("font_size", 12 + fd)
	board.pressed.connect(_open_leaderboard)
	add_child(board)

	var legend := Label.new()
	legend.text = "Badges: Routine=pacing  |  Echo=reasoning  |  Balance=airtime  |  Mirror=feedback  |  Insight=capstone"
	legend.position = Vector2(42, 136)
	legend.size = Vector2(vp.x - 84, 34)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 11 + fd)
	legend.add_theme_color_override("font_color", Color(0.68, 0.76, 0.86))
	add_child(legend)

	var settings := Button.new()
	settings.text = "Settings"
	settings.position = Vector2(vp.x - 172, 28)
	settings.size = Vector2(130, 36)
	settings.add_theme_font_size_override("font_size", 12 + fd)
	settings.pressed.connect(_open_settings)
	add_child(settings)

	_draw_equipped_items(Vector2(vp.x - 398, 116))

	var open_ids: Array = []
	var locked_ids: Array = []
	for sid in _scenario_ids():
		var scfg := _load(sid)
		var req := str(scfg.get("requires", ""))
		if req != "" and not GameState.has_badge(req):
			locked_ids.append(sid)
		else:
			open_ids.append(sid)
	var ordered_ids := open_ids + locked_ids

	var list_top := 178.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(42, list_top)
	scroll.size = Vector2(vp.x - 84, maxf(148.0, vp.y - list_top - 22.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(vp.x - 84, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var coach := Label.new()
	coach.text = Game.practice_recommendation()
	coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach.custom_minimum_size = Vector2(0, 46)
	coach.add_theme_font_size_override("font_size", 13 + fd)
	coach.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	list.add_child(coach)

	var first: Button = null
	var start_marked := false
	for id in ordered_ids:
		var cfg := _load(id)
		var badge: String = str(cfg.get("badge", ""))
		var earned: bool = badge != "" and GameState.has_badge(badge)
		var requires: String = str(cfg.get("requires", ""))
		var locked: bool = requires != "" and not GameState.has_badge(requires)
		var is_next := not earned and not locked and not start_marked
		var b := _add_mission_card(list, id, cfg, earned, locked, is_next)
		if is_next:
			start_marked = true
		if first == null and b != null:
			first = b

	var imp := Button.new()
	imp.text = "+  Import a lesson plan..."
	imp.custom_minimum_size = Vector2(0, 42)
	imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imp.add_theme_font_size_override("font_size", 14 + fd)
	imp.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	imp.pressed.connect(_go_import)
	list.add_child(imp)

	var hint := Label.new()
	hint.text = "Move: arrows or WASD. Select/talk: Z, Enter, or Space."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0, 38)
	hint.add_theme_font_size_override("font_size", 14 + fd)
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	list.add_child(hint)

	if first != null:
		first.grab_focus()

## All scenarios found in data/scenarios/ (built-ins first in Game.SCENARIOS order, then any
## imported custom_*.json), so a lesson-plan import shows up automatically.
func _scenario_ids() -> Array:
	var found: Array = []
	for d in ["res://data/scenarios", "user://scenarios"]:
		var dir := DirAccess.open(d)
		if dir != null:
			for f in dir.get_files():
				if f.ends_with(".json") and not (f.get_basename() in found):
					found.append(f.get_basename())
	var ordered: Array = []
	for b in Game.SCENARIOS:
		if b in found:
			ordered.append(b)
			found.erase(b)
	found.sort()
	ordered.append_array(found)
	return ordered

func _load(id: String) -> Dictionary:
	var path := Game.scenario_path(id)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				return d
	return {"title": id}

func _choose(id: String) -> void:
	Game.current_scenario_id = id
	var cfg := _load(id)
	var mode := str(cfg.get("mode", ""))
	if mode == "gym":
		SceneRouter.change_scene("res://scenes/encounter/GymEncounter.tscn", {"scenario": cfg})
	elif mode == "lecture":
		SceneRouter.change_scene("res://scenes/encounter/LectureScene.tscn", {"scenario": cfg})
	else:
		SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _open_mission_briefing(id: String) -> void:
	var cfg := _load(id)
	var fd := GameState.ui_font_delta()
	var vp := get_viewport_rect().size
	var overlay := Control.new()
	overlay.name = "MissionBriefingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(70, 42)
	panel.size = Vector2(vp.x - 140, vp.y - 84)
	overlay.add_child(panel)

	var image := TextureRect.new()
	image.position = Vector2(96, 92)
	image.size = Vector2(356, 200)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.texture = Art.tex(Art.scenario_backdrop_path(cfg, id, false))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(image)

	var badge := Label.new()
	badge.text = _mission_meta(cfg)
	badge.position = Vector2(96, 304)
	badge.size = Vector2(356, 24)
	badge.clip_text = true
	badge.add_theme_font_size_override("font_size", 12 + fd)
	badge.add_theme_color_override("font_color", Color(0.70, 0.82, 0.94))
	overlay.add_child(badge)

	var reward := Label.new()
	reward.text = _mission_reward_text(str(cfg.get("badge", "")), false)
	reward.position = Vector2(96, 330)
	reward.size = Vector2(356, 24)
	reward.clip_text = true
	reward.add_theme_font_size_override("font_size", 12 + fd)
	reward.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	overlay.add_child(reward)

	var title := Label.new()
	title.text = str(cfg.get("title", id))
	title.position = Vector2(480, 76)
	title.size = Vector2(344, 48)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 14 + fd)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	_add_brief_label(overlay, "CASE", str(cfg.get("story_hook", "")), Vector2(480, 138), Vector2(344, 76), Color(0.84, 0.82, 0.74), fd, 48)
	_add_brief_label(overlay, "SUCCESS", _brief_objectives_text(cfg), Vector2(480, 222), Vector2(344, 94), Color(0.90, 0.92, 0.96), fd, 46)
	_add_brief_label(overlay, "EVIDENCE", Game.scenario_edge_label(cfg), Vector2(480, 324), Vector2(344, 58), Color(0.66, 0.90, 0.78), fd, 48)
	_add_brief_label(overlay, "FIRST MOVE", _mission_first_move(cfg), Vector2(96, 370), Vector2(724, 42), Color(0.72, 0.92, 0.78), fd, 92)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(96, 430)
	back.size = Vector2(160, 38)
	back.add_theme_font_size_override("font_size", 13 + fd)
	back.pressed.connect(func(): overlay.queue_free())
	overlay.add_child(back)

	var start := Button.new()
	start.text = "Start rehearsal"
	start.position = Vector2(584, 430)
	start.size = Vector2(236, 38)
	start.add_theme_font_size_override("font_size", 13 + fd)
	start.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	start.pressed.connect(func():
		overlay.queue_free()
		_choose(id)
	)
	overlay.add_child(start)
	start.grab_focus()

func _add_brief_label(parent: Control, head: String, body: String, pos: Vector2, size: Vector2, color: Color, fd: int, wrap_chars: int) -> void:
	var label := Label.new()
	label.text = "%s\n%s" % [head, _wrap_words(body, wrap_chars)]
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12 + fd)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _wrap_words(text: String, max_chars: int) -> String:
	var out: Array = []
	var line := ""
	for raw in text.replace("  |  ", " | ").split(" "):
		var word := str(raw)
		if word == "":
			continue
		if line != "" and line.length() + 1 + word.length() > max_chars:
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		out.append(line)
	return "\n".join(out)

func _brief_objectives_text(cfg: Dictionary) -> String:
	var objectives: Array = cfg.get("objectives", [])
	if objectives.is_empty():
		return "Resolve every learner while class order stays intact."
	var labels: Array = []
	for o in objectives.slice(0, 3):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			labels.append(str(o.get("label", "")))
	return "  |  ".join(labels)

func _mission_first_move(cfg: Dictionary) -> String:
	var fmt := str(cfg.get("format", "discussion"))
	match fmt:
		"lecture":
			return "Present briefly, wait, then Question a highlighted learner before moving on."
		"group_work":
			return "Visit one pod, surface shared reasoning, then redistribute airtime."
		"independent":
			return "Circulate first, use proximity, then confer with a drifting learner."
	return "Elicit reasoning, use wait-time, then press or revoice without taking over."

func _add_mission_card(parent: VBoxContainer, id: String, cfg: Dictionary, earned: bool, locked: bool, is_next: bool) -> Button:
	var fd := GameState.ui_font_delta()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 152)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.modulate = Color(0.72, 0.76, 0.86) if locked else Color.WHITE
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var thumb_tex := Art.tex(Art.scenario_backdrop_path(cfg, id, true))
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(156, 88)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)
	if thumb_tex != null:
		thumb.texture = thumb_tex
	else:
		thumb.modulate = Color(0.35, 0.40, 0.52)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	info.add_child(top)

	var chip := Label.new()
	chip.text = _mission_chip(earned, locked, is_next)
	chip.custom_minimum_size = Vector2(76, 22)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 11 + fd)
	chip.add_theme_color_override("font_color", _mission_chip_color(earned, locked, is_next))
	top.add_child(chip)

	var title := Label.new()
	title.text = str(cfg.get("title", id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 14 + fd)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	top.add_child(title)

	var meta := Label.new()
	meta.text = _mission_meta(cfg)
	meta.add_theme_font_size_override("font_size", 11 + fd)
	meta.add_theme_color_override("font_color", Color(0.70, 0.82, 0.94))
	meta.clip_text = true
	info.add_child(meta)

	var story := Label.new()
	story.text = str(cfg.get("story_hook", ""))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(0, 30)
	story.add_theme_font_size_override("font_size", 10 + fd)
	story.add_theme_color_override("font_color", Color(0.84, 0.82, 0.74))
	info.add_child(story)

	var focus := Label.new()
	focus.text = _mission_focus(cfg)
	focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus.custom_minimum_size = Vector2(0, 26)
	focus.add_theme_font_size_override("font_size", 11 + fd)
	focus.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	info.add_child(focus)

	var signature := Label.new()
	signature.text = Game.scenario_signature(cfg)
	signature.clip_text = true
	signature.add_theme_font_size_override("font_size", 10 + fd)
	signature.add_theme_color_override("font_color", Color(0.66, 0.90, 0.78))
	info.add_child(signature)

	var reward := Label.new()
	reward.text = _mission_reward_text(str(cfg.get("badge", "")), earned)
	reward.clip_text = true
	reward.add_theme_font_size_override("font_size", 10 + fd)
	reward.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	info.add_child(reward)

	var action := Button.new()
	action.custom_minimum_size = Vector2(116, 0)
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", 12 + fd)
	if locked:
		action.text = "Locked\n%s" % _badge_name(str(cfg.get("requires", "")))
		action.disabled = true
	elif earned:
		action.text = "Replay"
		action.pressed.connect(_open_mission_briefing.bind(id))
	else:
		action.text = "Start"
		action.pressed.connect(_open_mission_briefing.bind(id))
	row.add_child(action)
	return null if locked else action

func _mission_chip(earned: bool, locked: bool, is_next: bool) -> String:
	if earned:
		return "CLEARED"
	if locked:
		return "LOCKED"
	if is_next:
		return "NEXT"
	return "OPEN"

func _mission_chip_color(earned: bool, locked: bool, is_next: bool) -> Color:
	if earned:
		return Color(0.55, 0.92, 0.62)
	if locked:
		return Color(0.62, 0.68, 0.80)
	if is_next:
		return Color(0.98, 0.86, 0.42)
	return Color(0.62, 0.88, 0.95)

func _mission_meta(cfg: Dictionary) -> String:
	var mode := str(cfg.get("mode", "overworld"))
	var format := str(cfg.get("format", "discussion")).replace("_", " ").capitalize()
	var roster: Array = cfg.get("roster", [])
	var seconds := int(cfg.get("period_seconds", 0))
	var time_text := "%d:%02d" % [seconds / 60, seconds % 60] if seconds > 0 else "boss"
	var badge := str(cfg.get("badge", ""))
	var badge_text := "Badge: %s" % _badge_name(badge) if badge != "" else "No badge"
	if mode == "gym":
		format = "Capstone"
	return "%s  |  %s  |  %d learners  |  %s" % [format, time_text, roster.size(), badge_text]

func _mission_focus(cfg: Dictionary) -> String:
	var objectives: Array = cfg.get("objectives", [])
	if objectives.is_empty():
		return "Focus: resolve every learner while class order stays intact."
	var labels: Array = []
	for o in objectives.slice(0, 2):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			labels.append(str(o.get("label", "")))
	return "Focus: " + "  |  ".join(labels)

func _mission_reward_text(badge: String, earned: bool) -> String:
	if badge == "":
		return "Reward: practice data and competency evidence"
	var reward_bits := ["+%d XP" % GameState.badge_xp(badge)]
	var items: Dictionary = Items.BADGE_REWARDS.get(badge, {})
	for id in items.keys():
		reward_bits.append("%s x%d" % [Items.short_name_for(str(id)), int(items[id])])
	return ("Collected: " if earned else "Reward: ") + ", ".join(reward_bits)

func _go_import() -> void:
	SceneRouter.change_scene("res://scenes/ui/ImportLesson.tscn")

func _open_settings() -> void:
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(210, 86)
	panel.size = Vector2(540, 360)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(236, 112)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 18 + GameState.ui_font_delta())
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	var options := [
		{"label": "Sound", "key": "audio_enabled", "on": "On", "off": "Off"},
		{"label": "Text size", "key": "large_text", "on": "Large", "off": "Normal"},
		{"label": "Motion", "key": "reduced_motion", "on": "Reduced", "off": "Normal"},
	]
	var y := 162.0
	for opt in options:
		var b := Button.new()
		b.position = Vector2(250, y)
		b.size = Vector2(420, 42)
		b.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
		overlay.add_child(b)
		_refresh_setting_button(b, opt)
		b.pressed.connect(func():
			var key := str(opt["key"])
			GameState.set_setting(key, not bool(GameState.get_setting(key, false)))
			_refresh_setting_button(b, opt)
		)
		y += 54.0

	var reveal := Button.new()
	reveal.position = Vector2(250, y)
	reveal.size = Vector2(420, 42)
	reveal.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
	overlay.add_child(reveal)
	_refresh_reveal_button(reveal)
	reveal.pressed.connect(func():
		var next := "instant" if str(GameState.get_setting("text_reveal", "typewriter")) == "typewriter" else "typewriter"
		GameState.set_setting("text_reveal", next)
		_refresh_reveal_button(reveal)
	)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(250, 386)
	close.size = Vector2(420, 42)
	close.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
	close.pressed.connect(func():
		overlay.queue_free()
		for child in get_children():
			child.queue_free()
		_build()
	)
	overlay.add_child(close)
	close.grab_focus()

func _open_upgrades() -> void:
	var overlay := Control.new()
	overlay.name = "UpgradeOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(186, 62)
	panel.size = Vector2(588, 416)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "LEVEL UP REWARDS"
	title.position = Vector2(218, 92)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 17 + GameState.ui_font_delta())
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	var points := Label.new()
	points.text = "Upgrade Points: %d" % GameState.upgrade_points
	points.position = Vector2(220, 126)
	points.size = Vector2(520, 20)
	points.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
	points.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	overlay.add_child(points)

	var y := 162.0
	for id in ["steady_presence", "wait_mastery", "relationship_sense"]:
		var def: Dictionary = GameState.UPGRADE_DEFS[id]
		var rank := GameState.upgrade_rank(id)
		var max_rank := int(def.get("max", 1))
		var b := Button.new()
		b.position = Vector2(220, y)
		b.size = Vector2(520, 58)
		b.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
		b.text = "%s  Rank %d/%d\n%s" % [str(def.get("name", id)), rank, max_rank, str(def.get("desc", ""))]
		b.disabled = GameState.upgrade_points <= 0 or rank >= max_rank
		b.pressed.connect(_choose_upgrade.bind(id, overlay))
		overlay.add_child(b)
		y += 70.0

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(220, 390)
	close.size = Vector2(520, 42)
	close.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
	close.pressed.connect(func():
		overlay.queue_free()
		for child in get_children():
			child.queue_free()
		_build()
	)
	overlay.add_child(close)
	close.grab_focus()

func _choose_upgrade(id: String, overlay: Control) -> void:
	if GameState.spend_upgrade(id):
		if is_instance_valid(overlay):
			overlay.queue_free()
		for child in get_children():
			child.queue_free()
		_build()
		if GameState.upgrade_points > 0:
			_open_upgrades()

func _open_evidence_journal() -> void:
	var fd := GameState.ui_font_delta()
	var overlay := Control.new()
	overlay.name = "EvidenceJournalOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(82, 44)
	panel.size = Vector2(796, 442)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "EVIDENCE JOURNAL"
	title.position = Vector2(112, 74)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 16 + fd)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	var summary := Label.new()
	summary.text = "Live ECD model: each turn updates a competency estimate, evidence count, and uncertainty."
	summary.position = Vector2(114, 106)
	summary.size = Vector2(720, 34)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 12 + fd)
	summary.add_theme_color_override("font_color", Color(0.72, 0.88, 0.96))
	overlay.add_child(summary)

	var anchors := _competency_anchors()
	var rows := Competency.summary()
	var y := 150.0
	for i in range(mini(rows.size(), 6)):
		var row: Dictionary = rows[i]
		_add_evidence_row(overlay, row, str(anchors.get(str(row.get("skill", "")), "session evidence model")), y)
		y += 38.0

	var recent := Label.new()
	recent.text = "RECENT RUN EVIDENCE\n%s" % _recent_evidence_text()
	recent.position = Vector2(114, 386)
	recent.size = Vector2(560, 58)
	recent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recent.add_theme_font_size_override("font_size", 11 + fd)
	recent.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	overlay.add_child(recent)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(704, 430)
	close.size = Vector2(140, 34)
	close.add_theme_font_size_override("font_size", 13 + fd)
	close.pressed.connect(func(): overlay.queue_free())
	overlay.add_child(close)
	close.grab_focus()

func _add_evidence_row(overlay: Control, row: Dictionary, anchor: String, y: float) -> void:
	var fd := GameState.ui_font_delta()
	var bg := ColorRect.new()
	bg.position = Vector2(106, y - 4)
	bg.size = Vector2(748, 32)
	bg.color = Color(0.10, 0.13, 0.23, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var label := Label.new()
	label.text = str(row.get("label", row.get("skill", "")))
	label.position = Vector2(116, y)
	label.size = Vector2(166, 24)
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 11 + fd)
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	overlay.add_child(label)

	var pct := int(round(float(row.get("prob", 0.5)) * 100.0))
	var n := int(row.get("n", 0))
	var unc := float(row.get("unc", 1.0))
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(290, y + 4)
	bar_bg.size = Vector2(128, 10)
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.position = bar_bg.position
	fill.size = Vector2(128.0 * clampf(float(pct) / 100.0, 0.0, 1.0), 10)
	fill.color = _evidence_color(pct, n)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fill)

	var stat := Label.new()
	stat.text = "%3d%%  ev %02d  unc %.2f" % [pct, n, unc]
	stat.position = Vector2(430, y)
	stat.size = Vector2(152, 22)
	stat.add_theme_font_size_override("font_size", 10 + fd)
	stat.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	overlay.add_child(stat)

	var cite := Label.new()
	cite.text = _short_anchor(anchor)
	cite.position = Vector2(588, y)
	cite.size = Vector2(250, 22)
	cite.clip_text = true
	cite.add_theme_font_size_override("font_size", 10 + fd)
	cite.add_theme_color_override("font_color", Color(0.68, 0.88, 0.96))
	overlay.add_child(cite)

func _evidence_color(pct: int, n: int) -> Color:
	if n <= 0:
		return Color(0.50, 0.56, 0.66)
	if pct >= 70:
		return Color(0.35, 0.78, 0.42)
	if pct >= 50:
		return Color(0.95, 0.78, 0.30)
	return Color(0.90, 0.45, 0.55)

func _competency_anchors() -> Dictionary:
	var out: Dictionary = {}
	var path := "res://data/competency_model.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				for s in d.get("skills", []):
					if typeof(s) == TYPE_DICTIONARY:
						out[str(s.get("id", ""))] = str(s.get("anchor", ""))
	return out

func _short_anchor(anchor: String) -> String:
	var a := anchor.strip_edges()
	if a.find("Jacobs") != -1:
		return "Jacobs et al. 2010"
	if a.find("Rowe") != -1:
		return "Rowe 1986"
	if a.find("Simonsen") != -1:
		return "Simonsen et al. 2008"
	if a.find("Moll") != -1:
		return "Moll & Gonzalez; HLP 12"
	if a.find("Chapin") != -1 or a.find("O'Connor") != -1:
		return "Chapin/O'Connor moves"
	if a.find("Hattie") != -1:
		return "Hattie & Timperley 2007"
	if a.find("Reinke") != -1:
		return "Reinke et al. 2008"
	if a.find("formative") != -1:
		return "Formative evidence"
	if a.length() <= 32:
		return a
	return "Evidence model"

func _recent_evidence_text() -> String:
	var rows := GameState.leaderboard_top(3)
	if rows.is_empty():
		return "No posted run yet. Clear a lesson to turn moves into evidence."
	var bits: Array = []
	for r in rows.slice(0, 2):
		bits.append("%s: %s" % [_truncate(str(r.get("title", "Run")), 22), _truncate(str(r.get("detail", "")), 46)])
	return "\n".join(bits)

func _open_leaderboard() -> void:
	var overlay := Control.new()
	overlay.name = "LeaderboardOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(108, 54)
	panel.size = Vector2(744, 426)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "LEADERBOARD"
	title.position = Vector2(138, 82)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 17 + GameState.ui_font_delta())
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	var summary := Label.new()
	summary.text = "Level %d  |  XP %d  |  next upgrade in %d XP" % [
		GameState.teacher_level,
		GameState.teacher_xp,
		GameState.xp_to_next_level(),
	]
	summary.position = Vector2(140, 112)
	summary.size = Vector2(680, 26)
	summary.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
	summary.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	overlay.add_child(summary)

	var header := Label.new()
	header.text = "Rank   Score   Mission                         Evidence"
	header.position = Vector2(140, 148)
	header.size = Vector2(680, 24)
	header.add_theme_font_size_override("font_size", 12 + GameState.ui_font_delta())
	header.add_theme_color_override("font_color", Color(0.62, 0.88, 0.95))
	overlay.add_child(header)

	var rows := GameState.leaderboard_top(8)
	var y := 178.0
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Clear a lesson or encounter to post your first run."
		empty.position = Vector2(140, y)
		empty.size = Vector2(680, 34)
		empty.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
		empty.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
		overlay.add_child(empty)
	else:
		for i in range(rows.size()):
			_add_leaderboard_row(overlay, rows[i], i + 1, y)
			y += 38.0

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(140, 432)
	close.size = Vector2(680, 34)
	close.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
	close.pressed.connect(func(): overlay.queue_free())
	overlay.add_child(close)
	close.grab_focus()

func _add_leaderboard_row(overlay: Control, rec: Dictionary, pos: int, y: float) -> void:
	var row_bg := ColorRect.new()
	row_bg.position = Vector2(132, y - 5)
	row_bg.size = Vector2(696, 32)
	row_bg.color = Color(0.12, 0.15, 0.26, 0.74) if pos % 2 == 1 else Color(0.09, 0.12, 0.21, 0.55)
	row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row_bg)

	var label := Label.new()
	label.text = "#%d  %s   %03d   %s" % [
		pos,
		str(rec.get("rank", "-")),
		int(rec.get("score", 0)),
		_truncate(str(rec.get("title", "Lesson")), 28),
	]
	label.position = Vector2(140, y)
	label.size = Vector2(408, 24)
	label.add_theme_font_size_override("font_size", 12 + GameState.ui_font_delta())
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	overlay.add_child(label)

	var detail := Label.new()
	var mark := "LEVEL UP  " if bool(rec.get("level_up", false)) else ""
	detail.text = mark + _truncate(str(rec.get("detail", "")), 42)
	detail.position = Vector2(548, y)
	detail.size = Vector2(270, 24)
	detail.clip_text = true
	detail.add_theme_font_size_override("font_size", 11 + GameState.ui_font_delta())
	detail.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	overlay.add_child(detail)

func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, maxi(0, max_len - 3)) + "..."

func _draw_equipped_items(pos: Vector2) -> void:
	var fd := GameState.ui_font_delta()
	var label := Label.new()
	label.text = "Equipped"
	label.position = pos
	label.size = Vector2(90, 18)
	label.add_theme_font_size_override("font_size", 11 + fd)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	add_child(label)
	var x := pos.x + 92.0
	for id in GameState.equipped_item_ids():
		var tex := Art.tex(Items.icon_for(str(id)))
		var slot := Panel.new()
		slot.position = Vector2(x, pos.y - 4)
		slot.size = Vector2(34, 34)
		slot.tooltip_text = "%s x%d" % [Items.name_for(str(id)), GameState.item_count(str(id))]
		add_child(slot)
		if tex != null:
			var icon := Sprite2D.new()
			icon.texture = tex
			icon.centered = false
			icon.position = Vector2(x + 1, pos.y - 3)
			icon.scale = Vector2(32.0 / float(tex.get_width()), 32.0 / float(tex.get_height()))
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(icon)
		x += 38.0

func _open_items() -> void:
	GameState.ensure_item_defaults()
	var overlay := Control.new()
	overlay.name = "ItemsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2(108, 48)
	panel_bg.size = Vector2(744, 444)
	panel_bg.color = Color(0.08, 0.10, 0.18, 0.98)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel_bg)

	var panel := Panel.new()
	panel.position = Vector2(108, 48)
	panel.size = Vector2(744, 444)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "ITEM LOADOUT"
	title.position = Vector2(138, 74)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 17 + GameState.ui_font_delta())
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	overlay.add_child(title)

	var help := Label.new()
	help.text = _wrap_words("Equip up to four tools. Use them to recover, notice cues, manage order, or set a practice goal.", 68)
	help.position = Vector2(140, 106)
	help.size = Vector2(680, 42)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.clip_text = true
	help.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
	help.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93))
	overlay.add_child(help)

	var y := 158.0
	var ids := Items.all_ids()
	ids.sort()
	for id in ids:
		_add_item_row(overlay, str(id), 140.0, y)
		y += 37.0

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(140, 450)
	close.size = Vector2(680, 34)
	close.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
	close.pressed.connect(func():
		overlay.queue_free()
		for child in get_children():
			child.queue_free()
		_build()
	)
	overlay.add_child(close)
	close.grab_focus()

func _add_item_row(overlay: Control, id: String, x: float, y: float) -> void:
	var count := GameState.item_count(id)
	var equipped := id in GameState.equipped_item_ids()
	var tex := Art.tex(Items.icon_for(id))
	if tex != null:
		var icon := Sprite2D.new()
		icon.texture = tex
		icon.centered = false
		icon.position = Vector2(x, y)
		icon.scale = Vector2(28.0 / float(tex.get_width()), 28.0 / float(tex.get_height()))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		overlay.add_child(icon)
	var label := Label.new()
	label.text = "%s  x%d" % [Items.name_for(id), count]
	label.position = Vector2(x + 48, y + 3)
	label.size = Vector2(196, 24)
	label.add_theme_font_size_override("font_size", 12 + GameState.ui_font_delta())
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90) if count > 0 else Color(0.55, 0.60, 0.66))
	overlay.add_child(label)
	var desc := Label.new()
	desc.text = _truncate(Items.desc_for(id), 44)
	desc.position = Vector2(x + 250, y + 3)
	desc.size = Vector2(302, 24)
	desc.add_theme_font_size_override("font_size", 11 + GameState.ui_font_delta())
	desc.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93))
	overlay.add_child(desc)
	var b := Button.new()
	b.position = Vector2(x + 566, y - 2)
	b.size = Vector2(114, 28)
	b.add_theme_font_size_override("font_size", 11 + GameState.ui_font_delta())
	b.text = "Unequip" if equipped else "Equip"
	b.disabled = count <= 0 or (not equipped and GameState.equipped_item_ids().size() >= Items.MAX_EQUIPPED)
	b.pressed.connect(_toggle_item_equipped.bind(id, overlay))
	overlay.add_child(b)

func _toggle_item_equipped(id: String, overlay: Control) -> void:
	if id in GameState.equipped_item_ids():
		GameState.unequip_item(id)
	else:
		GameState.equip_item(id)
	if is_instance_valid(overlay):
		overlay.queue_free()
	_open_items()

func _refresh_setting_button(button: Button, opt: Dictionary) -> void:
	var on := bool(GameState.get_setting(str(opt["key"]), false))
	button.text = "%s: %s" % [str(opt["label"]), str(opt["on"] if on else opt["off"])]

func _refresh_reveal_button(button: Button) -> void:
	var mode := str(GameState.get_setting("text_reveal", "typewriter"))
	button.text = "Dialogue text: %s" % ("Instant" if mode == "instant" else "Typewriter")

func _badge_name(id: String) -> String:
	return id.capitalize()

func _badge_desc(id: String) -> String:
	match id:
		"routine":
			return "manage pacing"
		"echo":
			return "surface reasoning"
		"balance":
			return "share airtime"
		"mirror":
			return "give useful feedback"
		"insight":
			return "handle the capstone"
		"bridge":
			return "connect to students"
	return "clear earlier lessons"
