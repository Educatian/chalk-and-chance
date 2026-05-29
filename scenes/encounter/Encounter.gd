extends Control
## The classroom encounter: read-act-observe loop against one LLM-driven student.
## Four meters (Engagement / Order / Rapport class-side, Composure = your HP), the
## seven teaching moves, and a Wait-Time Ring that rewards a 3 to 5s pause.
## See GAME_CONCEPT.md sections 3.2 to 3.7 and 7.

const Art = preload("res://scripts/Art.gd")
## UI is authored in a 480x270 space and scaled up to fill the 960x540 viewport,
## so a single constant drives the resolution (GAME_CONCEPT.md section 8).
const UI_SCALE := 2.0
const WIN_UNDERSTANDING := 0.80
const WAIT_FULL_MS := 3000.0

# Move menu: [display label, judge tag]. Order follows GAME_CONCEPT.md 3.4.
const MOVES := [
	["Elicit", "elicit"], ["Extend", "extend"], ["Revoice", "revoice"],
	["Tell", "tell"], ["Praise", "praise"], ["Redirect", "redirect"], ["Wait", "wait"],
]

var persona_id := "noah_g5_fractions"
var display_name := "Noah"
var target_concept := "grade 5 fractions"
var opening_line := ""
var win_line := "Oh... I think I get it now!"
var target_badge := "echo"
var win_moves: Array = ["elicit", "extend", "revoice", "wait"]  # moves that work for THIS student

# Class meters (0..100) and player HP.
var engagement := 40.0
var order := 70.0
var rapport := 50.0
var composure := 100.0
# Per-student internal value (0..1); the win gate (GAME_CONCEPT.md 7.3).
var understanding := 0.15

var _resolved := false
var _busy := false
var _ready_at_ms := 0

# Node refs built in _ready().
var _name_label: Label
var _student_rect: ColorRect
var _student_tex: TextureRect
var _emote: TextureRect
var _layer: Control
var _dialogue: Label
var _coach: Label
var _wait_bar: ProgressBar
var _bars: Dictionary = {}   # key -> ProgressBar
var _buttons: Array = []

func _ready() -> void:
	_build_ui()
	_refresh_meters()
	_set_dialogue("You walk over to %s's desk." % display_name)
	_set_coach("Read the student, then choose a move. Tip: surface their reasoning before correcting. Waiting 3s before you act earns a bonus.")
	_update_portrait("neutral")
	_arm_turn()

func setup(data: Dictionary) -> void:
	persona_id = str(data.get("persona_id", persona_id))
	display_name = str(data.get("display_name", display_name))
	_load_persona()
	_apply_scenario_overrides()    # a custom (imported) lesson can rewrite lines/targets to its content
	Game.note_visit(persona_id)    # equity: this student was called on
	_refresh_intro()

## Lesson-plan import / any scenario may override a persona's lines and targets for its
## content, via a "persona_overrides" map in the scenario JSON.
func _apply_scenario_overrides() -> void:
	var path := Game.scenario_path(Game.current_scenario_id)
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	var ov = d.get("persona_overrides", {})
	if typeof(ov) != TYPE_DICTIONARY:
		return
	var po = ov.get(persona_id, {})
	if typeof(po) != TYPE_DICTIONARY:
		return
	if po.has("target_label"):
		target_concept = str(po["target_label"])
	if po.has("opening_line"):
		opening_line = str(po["opening_line"])
	if po.has("win_line"):
		win_line = str(po["win_line"])
	if po.has("win_moves"):
		win_moves = po["win_moves"]

## Reads display fields from data/persona_library/<id>.json (falls back to defaults).
func _load_persona() -> void:
	var path := "res://data/persona_library/%s.json" % persona_id
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)   # Variant
	if typeof(data) != TYPE_DICTIONARY:
		return
	target_concept = str(data.get("target_label", target_concept))
	opening_line = str(data.get("opening_line", opening_line))
	win_line = str(data.get("win_line", win_line))
	target_badge = str(data.get("badge", target_badge))
	win_moves = data.get("win_moves", win_moves)

func _refresh_intro() -> void:
	if _name_label != null:
		_name_label.text = "ENCOUNTER  -  %s  (%s)" % [display_name, target_concept]
	if opening_line != "":
		_set_dialogue("%s: \"%s\"" % [display_name, opening_line])
	_update_portrait("neutral")

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# All other UI lives in a 480x270-authored layer scaled up to the viewport.
	_layer = Control.new()
	_layer.scale = Vector2(UI_SCALE, UI_SCALE)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	_name_label = _make_label("ENCOUNTER  -  %s (grade 5 fractions)" % display_name, Vector2(10, 6), 9, Color(0.95, 0.93, 0.85))
	_name_label.size = Vector2(340, 14)

	# Meters block, top-left.
	_bars["engagement"] = _make_meter("Engagement", 26, Color(0.30, 0.80, 0.40))
	_bars["order"] = _make_meter("Order", 44, Color(0.35, 0.65, 0.95))
	_bars["rapport"] = _make_meter("Rapport", 62, Color(0.95, 0.70, 0.30))
	_bars["composure"] = _make_meter("Composure", 84, Color(0.90, 0.35, 0.45))

	# Student sprite, top-right (placeholder; affect portrait swaps in later).
	_student_rect = ColorRect.new()
	_student_rect.position = Vector2(372, 22)
	_student_rect.size = Vector2(84, 84)
	_student_rect.color = Color(0.80, 0.28, 0.30)
	_student_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_student_rect)

	# Affect portrait overlay; shown only when an imagegen2 PNG is present.
	_student_tex = TextureRect.new()
	_student_tex.position = Vector2(372, 22)
	_student_tex.size = Vector2(84, 84)
	_student_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # respect the 84x84 box, not the 128px source
	_student_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_student_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_student_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_student_tex.visible = false
	_layer.add_child(_student_tex)

	_make_label(display_name, Vector2(372, 108), 9, Color.WHITE)

	# Overhead emote bubble reflecting the student's reaction.
	_emote = TextureRect.new()
	_emote.position = Vector2(442, 12)
	_emote.size = Vector2(22, 22)
	_emote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_emote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emote.visible = false
	_layer.add_child(_emote)

	# Wait-Time Ring (a bar in M1).
	_make_label("Wait-Time", Vector2(300, 26), 8, Color(0.8, 0.85, 0.95))
	_wait_bar = ProgressBar.new()
	_wait_bar.position = Vector2(300, 40)
	_wait_bar.size = Vector2(60, 10)
	_wait_bar.min_value = 0
	_wait_bar.max_value = WAIT_FULL_MS
	_wait_bar.value = 0
	_wait_bar.show_percentage = false
	_layer.add_child(_wait_bar)

	# Student utterance shown in a speech bubble (9-slice) when art is present.
	_build_dialogue_box()

	# Coach tip box.
	_coach = _make_label("", Vector2(16, 174), 8, Color(0.70, 0.90, 0.75))
	_coach.size = Vector2(448, 40)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Move buttons row.
	var n := MOVES.size()
	var bw := 466.0 / float(n)
	for i in range(n):
		var b := Button.new()
		b.text = MOVES[i][0]
		b.position = Vector2(8 + i * bw, 224)
		b.size = Vector2(bw - 4, 40)
		b.add_theme_font_size_override("font_size", 8)
		var tag: String = MOVES[i][1]
		b.pressed.connect(_on_move.bind(tag))
		_layer.add_child(b)
		_buttons.append(b)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _build_dialogue_box() -> void:
	var bub := Art.tex("res://assets/ui/bubble_9slice.png")
	var text_color := Color(0.96, 0.96, 0.92)
	var w := 448.0
	if bub != null:
		var np := NinePatchRect.new()
		np.texture = bub
		np.position = Vector2(10, 114)
		np.size = Vector2(356, 54)
		np.patch_margin_left = 14
		np.patch_margin_right = 14
		np.patch_margin_top = 14
		np.patch_margin_bottom = 14
		np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(np)
		var tailtex := Art.tex("res://assets/ui/bubble_tail.png")
		if tailtex != null:
			var tail := Sprite2D.new()
			tail.texture = tailtex
			tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tail.flip_v = true   # point up toward the portrait
			tail.position = Vector2(346, 116)
			_layer.add_child(tail)
		text_color = Color(0.10, 0.12, 0.22)
		w = 332.0
	else:
		var dbox := ColorRect.new()
		dbox.position = Vector2(10, 120)
		dbox.size = Vector2(460, 48)
		dbox.color = Color(0.12, 0.15, 0.26)
		dbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(dbox)
	_dialogue = _make_label("", Vector2(20, 122), 9, text_color)
	_dialogue.size = Vector2(w, 42)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _make_label(txt: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _layer != null:
		_layer.add_child(l)
	else:
		add_child(l)
	return l

func _make_meter(name_txt: String, y: float, fill: Color) -> ProgressBar:
	_make_label(name_txt, Vector2(10, y - 2), 8, Color(0.85, 0.88, 0.95))
	var bar := ProgressBar.new()
	bar.position = Vector2(86, y)
	bar.size = Vector2(150, 12)
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	bar.add_theme_stylebox_override("fill", sb)
	_layer.add_child(bar)
	return bar

# --- turn loop ---------------------------------------------------------------

func _arm_turn() -> void:
	_busy = false
	_ready_at_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _busy or _resolved:
		return
	var elapsed := float(Time.get_ticks_msec() - _ready_at_ms)
	_wait_bar.value = min(elapsed, WAIT_FULL_MS)

func _on_move(tag: String) -> void:
	if _busy or _resolved:
		return
	_busy = true
	var wait_ms := Time.get_ticks_msec() - _ready_at_ms
	var payload := {
		"session_id": "m1",
		"scenario_id": "questioning_forest_elicit",
		"target_behavior": "elicit_student_thinking",
		"active_persona_id": persona_id,
		"runtime_state": {
			"understanding": understanding,
			"engagement": engagement / 100.0,
			"trust_in_teacher": rapport / 100.0,
		},
		"teacher_move": {"input_mode": "menu", "menu_tag": tag, "wait_time_ms": wait_ms},
		"win_moves": win_moves,
		"model_profile": "stub",
	}
	if not LLMClient.reply_ready.is_connected(_on_reply):
		LLMClient.reply_ready.connect(_on_reply, CONNECT_ONE_SHOT)
	LLMClient.send_move(payload)

func _on_reply(resp: Dictionary) -> void:
	var deltas: Dictionary = resp.get("meter_deltas", {})
	understanding = clampf(understanding + float(deltas.get("understanding", 0.0)), 0.0, 1.0)
	engagement = clampf(engagement + float(deltas.get("engagement", 0.0)) * 100.0, 0.0, 100.0)
	rapport = clampf(rapport + float(deltas.get("trust", 0.0)) * 100.0, 0.0, 100.0)
	order = clampf(order + float(deltas.get("order", 0.0)) * 100.0, 0.0, 100.0)
	composure = clampf(composure + float(deltas.get("composure", 0.0)) * 100.0, 0.0, 100.0)
	_refresh_meters()

	var utter: Dictionary = resp.get("student_utterance", {})
	_set_dialogue("%s: \"%s\"" % [display_name, str(utter.get("text", "..."))])
	_set_coach("Coach Vee: " + str(resp.get("coach_tip", "")))

	var judge: Dictionary = resp.get("judge", {})
	var tags: Array = judge.get("move_tags", [])
	var targets: bool = bool(judge.get("targets_misconception", false))
	var tag0: String = str(tags[0]) if tags.size() > 0 else ""
	Game.log_move(tag0, bool(judge.get("wait_time_ok", false)), targets)
	_update_portrait(_affect_for(tags))

	if composure <= 0.0:
		_force_recover()
		return

	if _check_win(targets, tags):
		_win()
		return

	_arm_turn()

func _check_win(targets: bool, tags: Array) -> bool:
	if understanding < WIN_UNDERSTANDING:
		return false
	if not targets:
		return false
	for t in tags:
		if t in win_moves:
			return true
	return false

func _win() -> void:
	_resolved = true
	_busy = true
	_disable_moves()
	_set_dialogue("%s: \"%s\"" % [display_name, win_line])
	_set_coach("Coach Vee: They reasoned to it themselves, you did not tell them. That is responsive teaching. Badge earned: %s." % target_badge.to_upper())
	_update_portrait("excited")
	GameState.award_badge(target_badge)
	GameState.record_student(persona_id, {"resolved": true, "best_understanding": understanding})
	_return_to_overworld_after(3.2)

func _force_recover() -> void:
	composure = 40.0
	_refresh_meters()
	_set_coach("Coach Vee: Composure bottomed out. Take a breath. This is data, not failure. Re-attempt the segment.")
	_arm_turn()

func _disable_moves() -> void:
	for b in _buttons:
		b.disabled = true

func _return_to_overworld_after(seconds: float) -> void:
	var t := get_tree().create_timer(seconds)
	await t.timeout
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

# --- view helpers ------------------------------------------------------------

func _refresh_meters() -> void:
	_bars["engagement"].value = engagement
	_bars["order"].value = order
	_bars["rapport"].value = rapport
	_bars["composure"].value = composure

func _affect_for(tags: Array) -> String:
	if "tell" in tags:
		return "withdrawn"
	if understanding >= 0.80:
		return "excited"
	if understanding >= 0.45:
		return "thinking"
	if "redirect" in tags:
		return "frustrated"
	return "confused"

## Swap to an imagegen2 portrait for the given affect if the PNG exists;
## otherwise tint the placeholder rect so state is still legible.
func _update_portrait(affect: String) -> void:
	if _student_tex == null:
		return
	var t := Art.tex("res://assets/portraits/%s_%s.png" % [persona_id, affect])
	if t != null:
		_student_tex.texture = t
		_student_tex.visible = true
		_student_rect.visible = false
	else:
		_student_tex.visible = false
		_student_rect.visible = true
		_student_rect.color = _affect_color(affect)
	_update_emote(affect)

func _update_emote(affect: String) -> void:
	if _emote == null:
		return
	var key := "dots"
	match affect:
		"excited", "frustrated":
			key = "exclaim"
		"confused":
			key = "question"
		_:
			key = "dots"
	var t := Art.tex("res://assets/ui/emote_%s.png" % key)
	if t != null:
		_emote.texture = t
		_emote.visible = true
	else:
		_emote.visible = false

func _affect_color(affect: String) -> Color:
	match affect:
		"excited": return Color(0.35, 0.78, 0.42)
		"thinking": return Color(0.85, 0.70, 0.30)
		"withdrawn": return Color(0.45, 0.45, 0.55)
		"frustrated": return Color(0.85, 0.35, 0.30)
		"confused": return Color(0.78, 0.55, 0.30)
		_: return Color(0.80, 0.28, 0.30)

func _set_dialogue(txt: String) -> void:
	if _dialogue != null:
		_dialogue.text = txt

func _set_coach(txt: String) -> void:
	if _coach != null:
		_coach.text = txt
