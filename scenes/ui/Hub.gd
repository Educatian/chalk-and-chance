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
	sub.text = "Start with the demo lesson. Badges unlock harder classroom rehearsals."
	sub.position = Vector2(42, 74)
	sub.add_theme_font_size_override("font_size", 16 + fd)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	add_child(sub)

	var level := Label.new()
	level.text = "Teacher Level %d   XP %d/%d   Upgrade Points %d" % [
		GameState.teacher_level,
		GameState.teacher_xp,
		GameState.xp_for_level(GameState.teacher_level + 1),
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

	var upgrades := Button.new()
	upgrades.text = "Upgrade"
	upgrades.position = Vector2(vp.x - 326, 74)
	upgrades.size = Vector2(118, 34)
	upgrades.add_theme_font_size_override("font_size", 12 + fd)
	upgrades.disabled = GameState.upgrade_points <= 0
	upgrades.pressed.connect(_open_upgrades)
	add_child(upgrades)

	var items := Button.new()
	items.text = "Items"
	items.position = Vector2(vp.x - 190, 74)
	items.size = Vector2(74, 34)
	items.add_theme_font_size_override("font_size", 12 + fd)
	items.pressed.connect(_open_items)
	add_child(items)

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

	var first: Button = null
	var start_marked := false
	for id in ordered_ids:
		var cfg := _load(id)
		var btitle: String = str(cfg.get("title", id))
		var badge: String = str(cfg.get("badge", ""))
		var earned: bool = badge != "" and GameState.has_badge(badge)
		var requires: String = str(cfg.get("requires", ""))
		var locked: bool = requires != "" and not GameState.has_badge(requires)
		var mark := ""
		if earned:
			mark = "   [DONE]"
		elif locked:
			mark = "   [LOCKED - earn %s first: %s]" % [_badge_name(requires), _badge_desc(requires)]
		elif not start_marked:
			mark = "   [START HERE]"
			start_marked = true
		var b := Button.new()
		b.text = btitle + mark
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15 + fd)
		b.disabled = locked
		if not locked:
			b.pressed.connect(_choose.bind(id))
		if earned:
			b.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6))
		elif locked:
			b.add_theme_color_override("font_color", Color(0.55, 0.61, 0.75))
		list.add_child(b)
		if first == null and not locked:
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
		add_child(slot)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.position = Vector2(x + 1, pos.y - 3)
			icon.size = Vector2(32, 32)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.tooltip_text = "%s x%d" % [Items.name_for(str(id)), GameState.item_count(str(id))]
			add_child(icon)
		x += 38.0

func _open_items() -> void:
	GameState.ensure_item_defaults()
	var overlay := Control.new()
	overlay.name = "ItemsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

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
	help.text = "Equip up to four classroom tools. Use them during lessons to recover composure, notice cues, manage order, or set a practice goal."
	help.position = Vector2(140, 106)
	help.size = Vector2(680, 38)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 13 + GameState.ui_font_delta())
	help.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93))
	overlay.add_child(help)

	var y := 150.0
	var ids := Items.all_ids()
	ids.sort()
	for id in ids:
		_add_item_row(overlay, str(id), 140.0, y)
		y += 38.0

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(140, 446)
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
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = Vector2(x, y)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		overlay.add_child(icon)
	var label := Label.new()
	label.text = "%s  x%d" % [Items.name_for(id), count]
	label.position = Vector2(x + 36, y + 3)
	label.size = Vector2(210, 24)
	label.add_theme_font_size_override("font_size", 12 + GameState.ui_font_delta())
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90) if count > 0 else Color(0.55, 0.60, 0.66))
	overlay.add_child(label)
	var desc := Label.new()
	desc.text = Items.desc_for(id)
	desc.position = Vector2(x + 250, y + 3)
	desc.size = Vector2(300, 24)
	desc.clip_text = true
	desc.add_theme_font_size_override("font_size", 11 + GameState.ui_font_delta())
	desc.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93))
	overlay.add_child(desc)
	var b := Button.new()
	b.position = Vector2(x + 560, y - 2)
	b.size = Vector2(120, 28)
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
