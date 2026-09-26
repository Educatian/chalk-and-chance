extends CanvasLayer
## Coach Vee's between-round coaching screen. Shows one move that worked, one missed
## opportunity with the better move + a sentence starter, any repeated anti-pattern,
## whether last round's focus was met, and a single focus for an immediate re-rehearsal.
##
##   CoachCard.open(parent, moves, scenario_id, on_rehearse, on_continue)

const CoachFeedback = preload("res://scripts/CoachFeedback.gd")
const HubUi = preload("res://scenes/ui/HubUi.gd")
const PIXEL_FONT := "res://ui/fonts/PressStart2P-Regular.ttf"
const VP := Vector2(960, 540)

var _root: Control
var _sections: Array[Control] = []

static func open(parent: Node, moves: Array, scenario_id: String, on_rehearse: Callable, on_continue: Callable) -> CanvasLayer:
	var card = load("res://scenes/ui/CoachCard.gd").new()
	card.layer = 80
	card.name = "CoachCard"
	parent.add_child(card)
	card._build(moves, scenario_id, on_rehearse, on_continue)
	return card

## Toast at the top of a rehearsal reminding the player of the focus Coach Vee set.
static func show_focus_banner(parent: Node, scenario_id: String) -> void:
	var focus: Dictionary = GameState.coach_focus.get(scenario_id, {})
	if focus.is_empty() or parent == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 70
	parent.add_child(layer)
	var box := Panel.new()
	box.size = Vector2(520, 40)
	box.position = Vector2((VP.x - 520) * 0.5, -48)
	box.add_theme_stylebox_override("panel", HubUi.plate_style(Color(0.06, 0.12, 0.14, 0.95), Color(0.30, 0.92, 0.86, 0.9)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var l := Label.new()
	l.text = "COACH VEE'S FOCUS  ·  " + str(focus.get("text", ""))
	l.size = Vector2(520, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.70, 1.0, 0.94))
	box.add_child(l)
	var t := layer.create_tween()
	t.tween_interval(0.6)
	t.tween_property(box, "position:y", 10.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): Sfx.play("open", -6.0))
	t.tween_interval(4.0)
	t.tween_property(box, "modulate:a", 0.0, 0.6)
	t.tween_callback(layer.queue_free)

func _build(moves: Array, scenario_id: String, on_rehearse: Callable, on_continue: Callable) -> void:
	var fb := CoachFeedback.analyze(moves)
	var prev_focus: Dictionary = GameState.coach_focus.get(scenario_id, {})
	var prev := CoachFeedback.focus_met(prev_focus, moves)
	if not prev.is_empty():
		Telemetry.log_event({"event": "coach_focus_result", "scenario_id": scenario_id,
			"focus_tag": str(prev_focus.get("tag", "")), "met": bool(prev["met"]), "got": int(prev["got"]), "need": int(prev["need"])})

	_root = Control.new()
	_root.size = VP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.88)
	dim.size = VP
	_root.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(36, 26)
	panel.size = Vector2(888, 488)
	var sb := HubUi.plate_style(Color(0.06, 0.07, 0.13, 0.98), Color(0.98, 0.82, 0.30, 0.9))
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var ratio := 0.0
	var hits := 0
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and bool(m.get("targets", false)):
			hits += 1
	if moves.size() > 0:
		ratio = float(hits) / float(moves.size())
	var mood := "proud" if ratio >= 0.6 else ("warm" if ratio >= 0.35 else "thinking")
	var portrait := TextureRect.new()
	portrait.texture = _tex("res://assets/portraits/coach_vee_%s.png" % mood, "res://assets/portraits/coach_vee_neutral.png")
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(56, 48)
	portrait.size = Vector2(150, 150)
	_root.add_child(portrait)
	var frame := Panel.new()
	frame.position = portrait.position - Vector2(3, 3)
	frame.size = portrait.size + Vector2(6, 6)
	var fsb := StyleBoxFlat.new()
	fsb.draw_center = false
	fsb.border_color = Color(0.98, 0.82, 0.30)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	_root.add_child(frame)

	var title := _label("COACHING", Vector2(230, 50), Vector2(400, 24), 16, Color(0.98, 0.95, 0.86))
	title.add_theme_font_override("font", load(PIXEL_FONT))
	_root.add_child(title)
	_root.add_child(_label("Coach Vee  ·  " + str(fb.get("summary", "no moves recorded")), Vector2(230, 80), Vector2(660, 20), 13, Color(0.62, 0.88, 0.95)))

	var y := 108.0
	if not prev.is_empty():
		var ok := bool(prev["met"])
		var line := "Last focus: %s   %s  (%d/%d)" % [str(prev["text"]), "MET" if ok else "NOT YET", int(prev["got"]), int(prev["need"])]
		var pl := _label(line, Vector2(230, y), Vector2(660, 20), 13, Color(0.45, 0.95, 0.60) if ok else Color(0.98, 0.70, 0.45))
		_root.add_child(pl)
		_sections.append(pl)
		y += 26.0
		if ok:
			GameState.coach_focus.erase(scenario_id)

	if fb.is_empty():
		var none := _label("No moves were recorded this round. Next time, try one move that asks for a student's thinking.", Vector2(230, y), Vector2(660, 40), 14, Color(0.9, 0.9, 0.9))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_root.add_child(none)
		_sections.append(none)
	else:
		var glow: Dictionary = fb.get("glow", {})
		if not glow.is_empty():
			_sections.append(_section(Vector2(230, y), "WHAT WORKED", "%s  ·  %s" % [glow["when"], glow["label"]], str(glow["text"]), "", Color(0.45, 0.95, 0.60)))
			y += 86.0
		var grow: Dictionary = fb.get("grow", {})
		if not grow.is_empty():
			var head := "%s  ·  %s  ->  try %s" % [grow["when"], grow["label"], grow.get("better_label", "")]
			if str(grow.get("note", "")) != "":
				head += "   (%s)" % str(grow["note"])
			var body := str(grow["text"])
			_sections.append(_section(Vector2(230, y), "TRY INSTEAD", head, body, str(grow.get("starter", "")), Color(0.98, 0.82, 0.30)))
			y += 118.0
		var ways: Array = fb.get("ways", [])
		if not ways.is_empty():
			var wl := _para("OTHER WAYS IN
" + "
".join(ways), Vector2(230, y), 660.0, 13, Color(0.62, 0.88, 0.95))
			_root.add_child(wl)
			_sections.append(wl)
			y += 22.0 + 20.0 * ways.size()
		var pattern := str(fb.get("pattern", ""))
		if pattern != "":
			var pat := _para(pattern, Vector2(230, y), 660.0, 13, Color(0.98, 0.62, 0.45))
			_root.add_child(pat)
			_sections.append(pat)

	var focus: Dictionary = fb.get("focus", {})
	var focus_box := Panel.new()
	focus_box.position = Vector2(56, 404)
	focus_box.size = Vector2(848, 40)
	focus_box.add_theme_stylebox_override("panel", HubUi.plate_style(Color(0.10, 0.16, 0.20, 0.95), Color(0.30, 0.92, 0.86, 0.8)))
	_root.add_child(focus_box)
	var ftext := "NEXT ROUND FOCUS:  " + (str(focus.get("text", "")) if not focus.is_empty() else "Repeat what worked, on purpose.")
	var fl := _label(ftext, Vector2(70, 414), Vector2(820, 22), 14, Color(0.70, 1.0, 0.94))
	_root.add_child(fl)
	_sections.append(focus_box)
	_sections.append(fl)

	var rehearse := Button.new()
	rehearse.text = "Rehearse with this focus"
	rehearse.position = Vector2(56, 456)
	rehearse.size = Vector2(420, 40)
	rehearse.add_theme_font_size_override("font_size", 14)
	HubUi.apply_button_style(rehearse, true)
	var fill := HubUi.button_style(Color(0.13, 0.42, 0.40, 1.0), Color(0.40, 0.98, 0.90))
	rehearse.add_theme_stylebox_override("normal", fill)
	rehearse.add_theme_stylebox_override("hover", HubUi.button_style(Color(0.17, 0.52, 0.49, 1.0), Color(0.6, 1.0, 0.95)))
	rehearse.add_theme_stylebox_override("focus", HubUi.button_style(Color(0.17, 0.52, 0.49, 1.0), Color(1.0, 0.92, 0.5)))
	rehearse.pressed.connect(func():
		if not focus.is_empty():
			GameState.coach_focus[scenario_id] = focus
			GameState.save_game()
		Telemetry.log_event({"event": "coach_rehearse", "scenario_id": scenario_id, "focus_tag": str(focus.get("tag", ""))})
		queue_free()
		on_rehearse.call())
	_root.add_child(rehearse)
	var cont := Button.new()
	cont.text = "Continue"
	cont.position = Vector2(488, 456)
	cont.size = Vector2(416, 40)
	cont.add_theme_font_size_override("font_size", 14)
	HubUi.apply_button_style(cont, false)
	cont.pressed.connect(func():
		GameState.save_game()
		queue_free()
		on_continue.call())
	_root.add_child(cont)
	rehearse.grab_focus()
	Telemetry.log_event({"event": "coach_card", "scenario_id": scenario_id,
		"grow_tag": str(fb.get("grow", {}).get("tag", "")), "focus_tag": str(focus.get("tag", "")),
		"pattern": str(fb.get("pattern", "")) != ""})
	_reveal()

## Sections slide in one after another so the feedback reads like a conversation.
func _reveal() -> void:
	Sfx.play("open")
	if bool(GameState.get_setting("reduced_motion", false)):
		return
	for s in _sections:
		s.modulate.a = 0.0
	var t := create_tween()
	for s in _sections:
		var y0: float = s.position.y
		s.position.y += 10
		t.tween_callback(func(): Sfx.play("tick", -6.0))
		t.tween_property(s, "modulate:a", 1.0, 0.18)
		t.parallel().tween_property(s, "position:y", y0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.12)

func _section(pos: Vector2, kicker: String, head: String, body: String, starter: String, accent: Color) -> Control:
	var box := Control.new()
	box.position = pos
	box.size = Vector2(660, 110)
	_root.add_child(box)
	var bar := ColorRect.new()
	bar.color = accent
	bar.position = Vector2(0, 2)
	bar.size = Vector2(3, 80 if starter == "" else 108)
	box.add_child(bar)
	box.add_child(_label(kicker, Vector2(12, 0), Vector2(640, 16), 11, accent))
	box.add_child(_label(head, Vector2(12, 18), Vector2(640, 20), 14, Color(0.97, 0.96, 0.92)))
	var b := _para(body, Vector2(12, 40), 640.0, 13, Color(0.82, 0.86, 0.94))
	box.add_child(b)
	if starter != "":
		var q := Panel.new()
		q.position = Vector2(12, 82)
		q.size = Vector2(640, 26)
		q.add_theme_stylebox_override("panel", HubUi.plate_style(Color(0.14, 0.13, 0.08, 0.9), Color(accent, 0.5)))
		box.add_child(q)
		var ql := _label("Try saying:  " + starter, Vector2(22, 86), Vector2(620, 20), 13, Color(1.0, 0.92, 0.70))
		box.add_child(ql)
	return box

## Wrapping paragraph (RichTextLabel wraps reliably without a container).
func _para(text: String, pos: Vector2, width: float, fs: int, color: Color) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.text = text
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.position = pos
	rt.size = Vector2(width, 20)
	rt.custom_minimum_size = Vector2(width, 0)
	rt.add_theme_font_size_override("normal_font_size", fs + GameState.ui_font_delta())
	rt.add_theme_color_override("default_color", color)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rt

func _label(text: String, pos: Vector2, size: Vector2, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.clip_text = true
	l.add_theme_font_size_override("font_size", fs + GameState.ui_font_delta())
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _tex(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null
