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
# "Connect" (notice a student's asset, then bridge content to it) adds an asset-based,
# funds-of-knowledge path alongside the discourse moves (QUALITATIVE_RESEARCH_AUDIT.md).
const MOVES := [
	["Elicit", "elicit"], ["Extend", "extend"], ["Revoice", "revoice"],
	["Tell", "tell"], ["Praise", "praise"], ["Connect", "connect"],
	["Redirect", "redirect"], ["Wait", "wait"],
]
const MOVE_HELP := {
	"elicit": "Elicit: ask how the student got that answer.",
	"extend": "Extend: press the idea one step further.",
	"revoice": "Revoice: restate their thinking so it is public and checkable.",
	"tell": "Tell: explain it directly. Useful sometimes, but it can take over their thinking.",
	"praise": "Praise: name a specific useful behavior, not just 'good job'.",
	"connect": "Connect: notice the student's world, then bridge the content to it.",
	"redirect": "Redirect: bring attention back with the least-intrusive move that works.",
	"wait": "Wait: hold silence until the Wait-Time bar turns green, then choose a move.",
}

var persona_id := "noah_g5_fractions"
var display_name := "Noah"
var target_concept := "grade 5 fractions"
var opening_line := ""
var win_line := "Oh... I think I get it now!"
var target_badge := "echo"
var win_moves: Array = ["elicit", "extend", "revoice", "wait"]  # moves that work for THIS student

# Funds of knowledge / asset framing (Moll & Gonzalez): a student's real-world strengths.
var assets: Array = []
var asset_hint := ""
var connect_line := ""
var connect_resolves := false   # if true, connecting-to-an-asset is a second valid win path
var _asset_learned := false     # the teacher has noticed/interpreted this student's asset
var _scenario_context: Dictionary = {}

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
var _turns := 0
var _transcript: Array = []     # running dialogue [{speaker, text}] for multi-turn coherence
var _move_history: Array = []    # recent [{tag, targets}] so the coach can fade / avoid repeats
var _port_tween: Tween = null    # portrait bounce on emotion change
var _last_wait_ms: int = 0       # wait time of the move in flight (for telemetry)
var _last_input_mode := "menu"
var _last_free_text := ""

# Node refs built in _ready().
var _name_label: Label
var _student_name_label: Label
var _student_rect: ColorRect
var _student_tex: TextureRect
var _emote: TextureRect
var _layer: Control
var _dialogue: Label
var _coach: Label
var _result: Label
var _dialogue_tween: Tween
var _coach_tween: Tween
var _wait_bar: ProgressBar
var _bond_fill: ColorRect
var _bond_label: Label
var _bars: Dictionary = {}   # key -> ProgressBar
var _buttons: Array = []
var _text_input: LineEdit = null     # free-text teacher utterance box
var _type_toggle: Button = null      # menu <-> type switch
var _send_btn: Button = null
var _mic_btn: Button = null
var _continue_btn: Button = null
var _type_mode: bool = false
var _item_buttons: Array = []
var _wait_item_ready := false
var _practice_goal_active := false

func _ready() -> void:
	_apply_upgrade_baselines()
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
	_apply_relationship_headstart()
	_refresh_intro()
	_refresh_bond()

## Warm demander / care ethic: a relationship built in earlier periods carries over and
## makes this student a little easier to reach (trust precedes risk-taking).
func _apply_relationship_headstart() -> void:
	var b := GameState.bond(persona_id)
	var upgrade_bonus := GameState.relationship_start_bonus()
	if upgrade_bonus > 0.0:
		engagement = clampf(engagement + upgrade_bonus * 100.0, 0.0, 100.0)
		rapport = clampf(rapport + upgrade_bonus * 100.0, 0.0, 100.0)
	if b <= 0.0:
		_refresh_meters()
		return
	understanding = clampf(understanding + b * 0.10, 0.0, 1.0)
	engagement = clampf(engagement + b * 15.0, 0.0, 100.0)
	rapport = clampf(rapport + b * 20.0, 0.0, 100.0)
	_refresh_meters()

func _apply_upgrade_baselines() -> void:
	composure = GameState.max_composure()

## Lesson-plan import / any scenario may override a persona's lines and targets for its
## content, via a "persona_overrides" map in the scenario JSON.
func _apply_scenario_overrides() -> void:
	var path := Game.scenario_path(Game.current_scenario_id)
	if not FileAccess.file_exists(path):
		_scenario_context = _build_scenario_context({}, {})
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_scenario_context = _build_scenario_context({}, {})
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		_scenario_context = _build_scenario_context({}, {})
		return
	var ov = d.get("persona_overrides", {})
	if typeof(ov) != TYPE_DICTIONARY:
		_scenario_context = _build_scenario_context(d, {})
		return
	var po = ov.get(persona_id, {})
	if typeof(po) != TYPE_DICTIONARY:
		_scenario_context = _build_scenario_context(d, {})
		return
	if po.has("target_label"):
		target_concept = str(po["target_label"])
	if po.has("opening_line"):
		opening_line = str(po["opening_line"])
	if po.has("win_line"):
		win_line = str(po["win_line"])
	if po.has("win_moves"):
		win_moves = po["win_moves"]
	_scenario_context = _build_scenario_context(d, po)

func _build_scenario_context(scenario: Dictionary, persona_override: Dictionary) -> Dictionary:
	var objective_labels: Array = []
	for o in scenario.get("objectives", []):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			objective_labels.append(str(o.get("label", "")))
	return {
		"id": str(scenario.get("id", Game.current_scenario_id)),
		"title": str(scenario.get("title", "Current lesson")),
		"format": str(scenario.get("format", "")),
		"arrangement": str(scenario.get("arrangement", "")),
		"objectives": objective_labels,
		"active_student": {
			"persona_id": persona_id,
			"name": display_name,
			"target_label": str(persona_override.get("target_label", target_concept)),
			"opening_line": str(persona_override.get("opening_line", opening_line)),
			"win_moves": persona_override.get("win_moves", win_moves),
			"asset_hint": asset_hint,
		},
	}

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
	assets = data.get("assets", assets)
	asset_hint = str(data.get("asset_hint", asset_hint))
	connect_line = str(data.get("connect_line", connect_line))
	connect_resolves = bool(data.get("connect_resolves", connect_resolves))

func _refresh_intro() -> void:
	if _name_label != null:
		_name_label.text = "ENCOUNTER  -  %s  (%s)" % [display_name, target_concept]
	if _student_name_label != null:
		_student_name_label.text = display_name
	if opening_line != "":
		_set_dialogue("%s: \"%s\"" % [display_name, opening_line])
		TTSClient.speak(persona_id, opening_line, "neutral")
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
	_bars["composure"].max_value = GameState.max_composure()

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

	_student_name_label = _make_label(display_name, Vector2(372, 108), 9, Color.WHITE)
	_student_name_label.size = Vector2(84, 12)

	# Persistent relationship (warm demander). Carries across periods, unlike the class meters.
	# Drawn as ColorRects (like the gym bars) so the height is exactly controlled.
	_bond_label = _make_label("Bond", Vector2(372, 122), 8, Color(0.96, 0.76, 0.86))
	var bondbg := ColorRect.new()
	bondbg.position = Vector2(372, 134)
	bondbg.size = Vector2(84, 8)
	bondbg.color = Color(0, 0, 0, 0.5)
	bondbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bondbg)
	_bond_fill = ColorRect.new()
	_bond_fill.position = Vector2(372, 134)
	_bond_fill.size = Vector2(0, 8)
	_bond_fill.color = Color(0.95, 0.55, 0.70)
	_bond_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bond_fill)

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
	_make_label(_wait_label_text(false), Vector2(300, 26), 7, Color(0.8, 0.85, 0.95))
	_wait_bar = ProgressBar.new()
	_wait_bar.position = Vector2(300, 40)
	_wait_bar.size = Vector2(60, 10)
	_wait_bar.min_value = 0
	_wait_bar.max_value = GameState.wait_threshold_ms()
	_wait_bar.value = 0
	_wait_bar.show_percentage = false
	_set_wait_bar_ready(false)
	_layer.add_child(_wait_bar)

	# Student utterance shown in a speech bubble (9-slice) when art is present.
	_build_dialogue_box()

	# Result chip + coach tip box.
	_result = _make_label("", Vector2(16, 162), 7, Color(0.96, 0.86, 0.50))
	_result.size = Vector2(448, 12)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach = _make_label("", Vector2(16, 174), 7, Color(0.70, 0.90, 0.75))
	_coach.size = Vector2(448, 18)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Move buttons: two rows with enough theme-minimum height to avoid overlap.
	var n := MOVES.size()
	var cols := 4
	var bw := 88.0
	var row_y := [194.0, 232.0]
	var short_labels := {
		"redirect": "Redir.",
	}
	for i in range(n):
		var b := Button.new()
		var tag: String = MOVES[i][1]
		b.text = str(short_labels.get(tag, MOVES[i][0]))
		b.position = Vector2(8 + (i % cols) * (bw + 4.0), row_y[int(i / cols)])
		b.size = Vector2(bw, 36)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 7)
		b.pressed.connect(_on_move.bind(tag))
		b.mouse_entered.connect(_preview_move.bind(tag))
		b.focus_entered.connect(_preview_move.bind(tag))
		_layer.add_child(b)
		_buttons.append(b)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

	# Free-text input (hidden until the player toggles to Type mode), sharing the move row.
	_text_input = LineEdit.new()
	_text_input.position = Vector2(8, 226)
	_text_input.size = Vector2(274, 36)
	_text_input.placeholder_text = "Type teacher talk..."
	_text_input.add_theme_font_size_override("font_size", 8)
	_text_input.visible = false
	_text_input.text_submitted.connect(func(_t): _on_type_submit())
	_layer.add_child(_text_input)

	_mic_btn = Button.new()
	_mic_btn.text = "Mic"
	_mic_btn.position = Vector2(288, 226)
	_mic_btn.size = Vector2(40, 36)
	_mic_btn.add_theme_font_size_override("font_size", 7)
	_mic_btn.visible = false
	_mic_btn.disabled = not VoiceInput.is_supported()
	_mic_btn.tooltip_text = "Speak teacher talk" if VoiceInput.is_supported() else "Voice input is not supported in this browser."
	_mic_btn.pressed.connect(_start_voice_input)
	_layer.add_child(_mic_btn)

	_send_btn = Button.new()
	_send_btn.text = "Say"
	_send_btn.position = Vector2(332, 226)
	_send_btn.size = Vector2(50, 36)
	_send_btn.add_theme_font_size_override("font_size", 8)
	_send_btn.visible = false
	_send_btn.pressed.connect(func(): _on_type_submit())
	_layer.add_child(_send_btn)

	# Mode toggle (top of the move row, far right).
	_type_toggle = Button.new()
	_type_toggle.text = "Type"
	_type_toggle.position = Vector2(388, 226)
	_type_toggle.size = Vector2(76, 36)
	_type_toggle.add_theme_font_size_override("font_size", 8)
	_type_toggle.pressed.connect(_toggle_input_mode)
	_layer.add_child(_type_toggle)

	_build_item_row()

func _build_item_row() -> void:
	var x := 244.0
	var y := 72.0
	for id in GameState.equipped_item_ids():
		var item_id := str(id)
		var b := Button.new()
		b.position = Vector2(x, y)
		b.size = Vector2(28, 28)
		b.set_meta("item_id", item_id)
		b.tooltip_text = "%s x%d\n%s" % [Items.name_for(item_id), GameState.item_count(item_id), Items.desc_for(item_id)]
		b.disabled = not GameState.can_use_item(item_id, "encounter")
		b.pressed.connect(_use_item.bind(item_id))
		var tex := Art.tex(Items.icon_for(item_id))
		if tex != null:
			b.icon = tex
			b.expand_icon = true
		else:
			b.text = Items.short_name_for(item_id)
			b.add_theme_font_size_override("font_size", 6)
		_layer.add_child(b)
		_item_buttons.append(b)
		x += 32.0

func _refresh_item_buttons() -> void:
	for b in _item_buttons:
		var id := str(b.get_meta("item_id", ""))
		if id != "":
			b.disabled = not GameState.can_use_item(id, "encounter") or _busy or _resolved
			b.tooltip_text = "%s x%d\n%s" % [Items.name_for(id), GameState.item_count(id), Items.desc_for(id)]

func _use_item(id: String) -> void:
	if _busy or _resolved:
		return
	var result := GameState.use_item(id, "encounter", {"scenario_id": str(Game.current_scenario_id), "persona_id": persona_id, "turn": _turns})
	Telemetry.log_event({"event": "item_used" if bool(result.get("ok", false)) else "item_blocked",
		"item_id": id, "scope": "encounter", "persona_id": persona_id, "turn": _turns,
		"remaining": int(result.get("remaining", GameState.item_count(id)))})
	if not bool(result.get("ok", false)):
		_set_result("Item unavailable.")
		return
	match id:
		"breathing_reset":
			composure = clampf(composure + 18.0, 0.0, GameState.max_composure())
			_set_result("Breathing Reset used  |  Composure +18")
			_set_coach("Coach Vee: you regulated before responding. That protects the next instructional choice.")
		"student_profile_card":
			_asset_learned = true
			rapport = clampf(rapport + 4.0, 0.0, 100.0)
			var hint := asset_hint if asset_hint != "" else "%s needs you to learn their thinking before correcting it." % display_name
			_set_result("Student Profile Card used  |  Asset cue revealed")
			_set_coach("Coach Vee: learner profile cue: %s" % hint)
		"noticing_lens":
			_set_result("Noticing Lens used  |  Look for %s" % ", ".join(win_moves))
			_set_coach("Coach Vee: attend to the student's reasoning need before choosing. Useful moves here: %s." % ", ".join(win_moves))
		"wait_meter_pin":
			_wait_item_ready = true
			_set_result("Wait Meter Pin used  |  next move gets full wait-time credit")
			_set_coach("Coach Vee: your next move will be treated as deliberate think time. Use it before pressing reasoning.")
		"lesson_map":
			understanding = clampf(understanding + 0.04, 0.0, 1.0)
			composure = clampf(composure + 4.0, 0.0, GameState.max_composure())
			_set_result("Lesson Map used  |  Understanding +4  |  Composure +4")
			_set_coach("Coach Vee: you checked the lesson path before acting. Now choose the move that fits the learner.")
		"practice_goal_card":
			_practice_goal_active = true
			_set_result("Practice Goal set  |  clear this encounter for bonus XP")
			_set_coach("Coach Vee: focus goal: make one evidence-rich move before resolving the misconception.")
		_:
			_set_result("%s cannot be used in this encounter." % Items.name_for(id))
	_refresh_meters()
	_refresh_bond()
	_refresh_item_buttons()

func _toggle_input_mode() -> void:
	_type_mode = not _type_mode
	_type_toggle.text = "Menu" if _type_mode else "Type"
	for b in _buttons:
		b.visible = not _type_mode
	if _text_input != null:
		_text_input.visible = _type_mode
		_send_btn.visible = _type_mode
		if _mic_btn != null:
			_mic_btn.visible = _type_mode
		if _type_mode:
			_text_input.grab_focus()
		elif not _buttons.is_empty():
			_buttons[0].grab_focus()
	if _type_mode:
		_set_result("Type mode: the offline demo classifies common teacher moves locally.")

func _start_voice_input() -> void:
	if _text_input == null:
		return
	if VoiceInput.start_for_line_edit(_text_input):
		_set_result("Listening... speak your teacher talk.")
	else:
		_set_result("Voice input is not available in this browser.")

func _preview_move(tag: String) -> void:
	if _busy or _resolved:
		return
	_set_result(str(MOVE_HELP.get(tag, "")))

func _set_wait_bar_ready(ready: bool) -> void:
	if _wait_bar == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.30, 0.80, 0.40) if ready else Color(0.55, 0.56, 0.62)
	_wait_bar.add_theme_stylebox_override("fill", fill)

func _build_dialogue_box() -> void:
	var bub := Art.tex("res://assets/ui/bubble_9slice.png")
	var text_color := Color(0.96, 0.96, 0.92)
	var w := 448.0
	if bub != null:
		var np := NinePatchRect.new()
		np.texture = bub
		np.position = Vector2(10, 114)
		np.size = Vector2(356, 50)
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
	_dialogue = _make_label("", Vector2(20, 121), 9, text_color)
	_dialogue.size = Vector2(w, 38)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _make_label(txt: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size + GameState.ui_font_delta())
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
	_refresh_item_buttons()

func _process(_delta: float) -> void:
	if _busy or _resolved:
		return
	var elapsed := float(Time.get_ticks_msec() - _ready_at_ms)
	var threshold := float(GameState.wait_threshold_ms())
	_wait_bar.value = min(elapsed, threshold)
	_set_wait_bar_ready(elapsed >= threshold)

func _wait_label_text(ready: bool) -> String:
	var seconds := float(GameState.wait_threshold_ms()) / 1000.0
	return ("Wait %.2fs: READY" if ready else "Wait %.2fs before choosing") % seconds

func _on_move(tag: String) -> void:
	if _busy or _resolved:
		return
	# Connect is handled locally: it is deterministic asset/relationship state, not an
	# LLM round-trip. First press NOTICES the asset (attend/interpret); the next CONNECTS.
	if tag == "connect":
		_do_connect()
		return
	_dispatch_move(tag, "")

## Submit a TYPED teacher utterance (free-text mode). The backend classifies it to one
## move tag via the LLM judge, then the SAME pipeline runs. The raw line is what the
## student model and coach see, so it is what goes into the transcript.
func _on_type_submit(text: String = "") -> void:
	if _busy or _resolved:
		return
	var line := (text if text != "" else (_text_input.text if _text_input != null else "")).strip_edges()
	if line == "":
		return
	if _text_input != null:
		_text_input.clear()
	_dispatch_move("", line)

## Shared send path for both menu moves and free text.
func _dispatch_move(tag: String, free_text: String) -> void:
	_busy = true
	Sfx.play("click")
	_turns += 1
	var raw_wait_ms := Time.get_ticks_msec() - _ready_at_ms
	var wait_ms := GameState.effective_wait_ms(raw_wait_ms)
	if _wait_item_ready:
		wait_ms = max(wait_ms, GameState.wait_threshold_ms())
		_wait_item_ready = false
	_last_wait_ms = wait_ms
	var is_free := free_text != ""
	_last_input_mode = "free_text" if is_free else "menu"
	_last_free_text = free_text
	# The transcript holds the real teacher talk: the typed line, or a gloss of the menu move.
	_transcript.append({"speaker": "teacher", "text": (free_text if is_free else _move_gloss(tag))})
	var teacher_move: Dictionary = (
		{"input_mode": "free_text", "text": free_text, "wait_time_ms": wait_ms, "raw_wait_time_ms": raw_wait_ms} if is_free
		else {"input_mode": "menu", "menu_tag": tag, "wait_time_ms": wait_ms, "raw_wait_time_ms": raw_wait_ms})
	var payload := {
		"session_id": "m1",
		"scenario_id": str(Game.current_scenario_id),
		"scenario_context": _scenario_context,
		"target_behavior": "elicit_student_thinking",
		"active_persona_id": persona_id,
		"runtime_state": {
			"understanding": understanding,
			"engagement": engagement / 100.0,
			"trust_in_teacher": rapport / 100.0,
			"misconception_resolved": understanding >= 0.8,
			"turns_elapsed": _turns,
		},
		"teacher_move": teacher_move,
		"win_moves": win_moves,
		"dialogue_tail": _transcript.slice(maxi(0, _transcript.size() - 6)),
		"move_history": _move_history.slice(maxi(0, _move_history.size() - 6)),
		"model_profile": "openrouter_gemini",
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
	composure = clampf(composure + float(deltas.get("composure", 0.0)) * 100.0, 0.0, GameState.max_composure())
	_refresh_meters()

	var utter: Dictionary = resp.get("student_utterance", {})
	_set_dialogue("%s: \"%s\"" % [display_name, str(utter.get("text", "..."))])
	_set_coach("Coach Vee: " + str(resp.get("coach_tip", "")))

	var judge: Dictionary = resp.get("judge", {})
	var tags: Array = judge.get("move_tags", [])
	var targets: bool = bool(judge.get("targets_misconception", false))
	var tag0: String = str(tags[0]) if tags.size() > 0 else ""
	_set_result(_result_text(tag0, targets, bool(judge.get("wait_time_ok", false)), deltas))
	Sfx.play("good" if targets else "bad")
	Game.log_move(tag0, bool(judge.get("wait_time_ok", false)), targets)
	# Accumulate the student's reply + the move outcome for coherence and adaptive coaching.
	_transcript.append({"speaker": display_name, "text": str(utter.get("text", ""))})
	_move_history.append({"tag": tag0, "targets": targets})
	# Warm demander: appropriate demand that lands builds the bond; cold takeover erodes it.
	if targets:
		GameState.add_bond(persona_id, 0.05)
	elif "tell" in tags:
		GameState.add_bond(persona_id, -0.04)
	_refresh_bond()
	# Prefer the student model's own felt emotion; fall back to the move-derived affect.
	var emo := _emotion_for(str(utter.get("emotion_shown", "")), tags)
	_update_portrait(emo)
	# Speak the line aloud in this student's voice (optional; silent if backend/TTS off).
	TTSClient.speak(persona_id, str(utter.get("text", "")), emo)

	# Record the full input->output turn for analysis (xAPI-style JSONL).
	Telemetry.log_turn({
		"scenario_id": str(Game.current_scenario_id) if "current_scenario_id" in Game else "",
		"persona_id": persona_id,
		"turn": _turns,
		"move": {"tag": tag0, "wait_ms": _last_wait_ms, "input_mode": _last_input_mode, "text": _last_free_text},
		"judge": {"tags": tags, "targets": targets, "wait_ok": bool(judge.get("wait_time_ok", false))},
		"deltas": deltas,
		"meters": {
			"understanding": understanding, "engagement": engagement, "order": order,
			"rapport": rapport, "composure": composure, "bond": GameState.bond(persona_id),
		},
		"emotion_shown": emo,
		"student_text": str(utter.get("text", "")),
		"coach_tip": str(resp.get("coach_tip", "")),
	})

	# Live ECD competency estimate (in-engine multivariate Elo over the same evidence).
	Competency.observe(tag0, persona_id, win_moves, judge, deltas)

	if composure <= 0.0:
		_force_recover()
		return

	if _check_win(targets, tags):
		_win("reasoning")
		return

	_arm_turn()

## Connect: notice a student's funds of knowledge, then bridge the content to it.
## A second, asset-based route to reaching some students (softens single-right-move).
func _do_connect() -> void:
	_busy = true
	if not _asset_learned:
		_asset_learned = true
		rapport = clampf(rapport + 6.0, 0.0, 100.0)
		engagement = clampf(engagement + 5.0, 0.0, 100.0)
		GameState.add_bond(persona_id, 0.10)
		_refresh_meters()
		_refresh_bond()
		var hint := asset_hint if asset_hint != "" else "You pause to learn what %s cares about beyond this task." % display_name
		_set_dialogue("You take a beat to notice %s, not just the task." % display_name)
		_set_coach("Coach Vee (notice): %s  Press Connect again to bridge the content to it." % hint)
		_update_portrait("thinking")
		_arm_turn()
		return
	# Bridge content to the now-known asset.
	rapport = clampf(rapport + 10.0, 0.0, 100.0)
	engagement = clampf(engagement + 12.0, 0.0, 100.0)
	composure = clampf(composure + 3.0, 0.0, GameState.max_composure())
	GameState.add_bond(persona_id, 0.18)
	if connect_resolves:
		# A landed asset-bridge is itself a valid route to the insight (the connect_line
		# states the full understanding), so it crosses the win gate.
		understanding = maxf(understanding, WIN_UNDERSTANDING + 0.05)
	_refresh_meters()
	_refresh_bond()
	var line := connect_line if connect_line != "" else "Oh... when you put it in my world, it actually makes sense."
	_set_dialogue("%s: \"%s\"" % [display_name, line])
	TTSClient.speak(persona_id, line, "excited" if connect_resolves else "thinking")
	Game.log_move("connect", false, connect_resolves)
	_update_portrait("excited" if connect_resolves else "thinking")
	if connect_resolves and understanding >= WIN_UNDERSTANDING:
		_win("connect")
		return
	if connect_resolves:
		_set_coach("Coach Vee: you connected it to %s's world (funds of knowledge). Keep going, they are with you." % display_name)
	else:
		_set_coach("Coach Vee: connecting built real trust (bond up). For %s the academic unlock is still the right move, but now they will let you lead." % display_name)
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

func _win(route: String = "reasoning") -> void:
	_resolved = true
	_busy = true
	_disable_moves()
	_update_portrait("excited")
	Telemetry.log_event({"event": "resolve", "persona_id": persona_id, "route": route,
		"turns": _turns, "understanding": understanding, "badge": target_badge,
		"bond": GameState.bond(persona_id)})
	Telemetry.upload_competency()
	Telemetry.flush()   # push this lesson's events to the learner's cloud account
	var reward := GameState.award_badge(target_badge)
	if _practice_goal_active:
		GameState.add_teacher_xp(35, "practice_goal:%s" % str(Game.current_scenario_id))
	Sfx.play("badge")
	_show_badge_card(target_badge, reward)
	var warm := GameState.bond(persona_id) >= 0.4
	GameState.record_student(persona_id, {"resolved": true, "best_understanding": understanding, "bond": GameState.bond(persona_id)})
	if route == "connect":
		# The connect_line is already shown as the resolving dialogue.
		_set_coach("Coach Vee: you reached %s through their own world, not by telling. Funds of knowledge in action. Badge: %s." % [display_name, target_badge.to_upper()])
	else:
		_set_dialogue("%s: \"%s\"" % [display_name, win_line])
		TTSClient.speak(persona_id, win_line, "excited")
		if warm:
			_set_coach("Coach Vee: warmth AND high expectations. You held the bar and they trusted you to. Warm demander. Badge: %s." % target_badge.to_upper())
		else:
			_set_coach("Coach Vee: they reasoned to it themselves, you did not tell them. Solid. (Build the relationship too; connection makes the next period easier.) Badge: %s." % target_badge.to_upper())
	_show_competency_panel()
	_show_continue_button()

## A compact end-of-lesson readout of the player's live ECD competency estimates
## (in-engine multivariate Elo). Shows the skills with evidence this session as bars.
func _show_competency_panel() -> void:
	for b in _buttons:
		b.visible = false
	if _text_input != null:
		_text_input.visible = false
	if _send_btn != null:
		_send_btn.visible = false
	if _mic_btn != null:
		_mic_btn.visible = false
	if _type_toggle != null:
		_type_toggle.visible = false
	for b in _item_buttons:
		b.visible = false

	var rows: Array = Competency.summary().filter(func(r): return r["n"] > 0)
	if rows.is_empty():
		return
	rows = rows.slice(0, 4)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.06, 0.10, 0.94)
	panel.position = Vector2(34, 194)
	panel.size = Vector2(436, 68 + rows.size() * 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)
	_make_label("Your teaching competencies this lesson", Vector2(48, 198), 8, Color(0.95, 0.85, 0.55)).size = Vector2(390, 12)
	_make_label("Bars are live practice estimates from moves you actually used. n = evidence count.", Vector2(48, 212), 7, Color(0.72, 0.78, 0.88)).size = Vector2(400, 20)
	var y := 236
	for r in rows:
		_make_label(str(r["label"]), Vector2(50, y), 7, Color(0.86, 0.90, 0.96)).size = Vector2(140, 11)
		var bg := ColorRect.new()
		bg.position = Vector2(196, y + 1)
		bg.size = Vector2(160, 8)
		bg.color = Color(0, 0, 0, 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bg)
		var fill := ColorRect.new()
		fill.position = Vector2(196, y + 1)
		var p: float = r["prob"]
		fill.size = Vector2(maxf(2.0, 160.0 * p), 8)
		fill.color = Color(0.35, 0.78, 0.42) if p >= 0.6 else (Color(0.85, 0.70, 0.30) if p >= 0.4 else Color(0.85, 0.45, 0.35))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(fill)
		_make_label("n=%d" % int(r["n"]), Vector2(362, y), 7, Color(0.6, 0.66, 0.74)).size = Vector2(36, 11)
		y += 14
	_make_label(_competency_next_step(rows), Vector2(48, y + 2), 7, Color(0.72, 0.92, 0.78)).size = Vector2(404, 28)

func _competency_next_step(rows: Array) -> String:
	var lowest: Dictionary = rows[0]
	for r in rows:
		if float(r["prob"]) < float(lowest["prob"]):
			lowest = r
	return "Next practice focus: %s. Try one move that gives this bar cleaner evidence next time." % str(lowest["label"])

func _show_continue_button() -> void:
	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.position = Vector2(372, 176)
	_continue_btn.size = Vector2(92, 24)
	_continue_btn.add_theme_font_size_override("font_size", 8)
	_continue_btn.pressed.connect(func(): SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn"))
	_layer.add_child(_continue_btn)
	_continue_btn.grab_focus()

func _show_badge_card(badge_id: String, reward: Dictionary = {}) -> void:
	if badge_id == "":
		return
	var card := Panel.new()
	card.position = Vector2(292, 110)
	card.size = Vector2(178, 78 if bool(reward.get("level_up", false)) else 62)
	_layer.add_child(card)
	var text := "BADGE UNLOCKED\n%s" % badge_id.to_upper()
	if bool(reward.get("level_up", false)):
		text += "\nLEVEL %d  +1 UPGRADE" % int(reward.get("level_after", GameState.teacher_level))
	var lbl := _make_label(text, Vector2(306, 122), 8, Color(0.96, 0.86, 0.50))
	lbl.size = Vector2(150, 58)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not bool(GameState.get_setting("reduced_motion", false)):
		card.scale = Vector2(0.88, 0.88)
		card.pivot_offset = card.size / 2.0
		var tw := create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _force_recover() -> void:
	composure = minf(40.0, GameState.max_composure())
	_refresh_meters()
	_set_coach("Coach Vee: Composure bottomed out. Take a breath. This is data, not failure. Re-attempt the segment.")
	_arm_turn()

func _result_text(tag: String, targets: bool, wait_ok: bool, deltas: Dictionary) -> String:
	var parts: Array = []
	var understanding_delta := int(round(float(deltas.get("understanding", 0.0)) * 100.0))
	var engagement_delta := int(round(float(deltas.get("engagement", 0.0)) * 100.0))
	var rapport_delta := int(round(float(deltas.get("trust", 0.0)) * 100.0))
	var order_delta := int(round(float(deltas.get("order", 0.0)) * 100.0))
	if understanding_delta != 0:
		parts.append("Understanding %s" % _signed(understanding_delta))
	if engagement_delta != 0:
		parts.append("Engagement %s" % _signed(engagement_delta))
	if rapport_delta != 0:
		parts.append("Rapport %s" % _signed(rapport_delta))
	if order_delta != 0:
		parts.append("Order %s" % _signed(order_delta))
	if tag == "wait" and not wait_ok:
		parts.append("Too soon: hold the pause longer")
	elif targets:
		parts.append("This addressed %s's need" % display_name)
	elif tag != "":
		parts.append("Not the move %s needs yet" % display_name)
	if _last_input_mode == "free_text":
		parts.append("classified as %s" % tag.capitalize())
	return "  |  ".join(parts)

func _signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)

func _disable_moves() -> void:
	for b in _buttons:
		b.disabled = true
	if _text_input != null:
		_text_input.editable = false
	if _send_btn != null:
		_send_btn.disabled = true
	if _mic_btn != null:
		_mic_btn.disabled = true
	if _type_toggle != null:
		_type_toggle.disabled = true
	for b in _item_buttons:
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

func _refresh_bond() -> void:
	var b := GameState.bond(persona_id)
	if _bond_fill != null:
		_bond_fill.size = Vector2(84.0 * clampf(b, 0.0, 1.0), 8.0)
	if _bond_label != null:
		_bond_label.text = "Bond %d%%" % int(round(b * 100.0))

# The 12-emotion spectrum (positive/open -> negative/closed). Filenames are
# assets/portraits/<persona_id>_<emotion>.png. Each emotion degrades to the next
# best AVAILABLE portrait so a missing file never renders as a broken/flat box.
const EMOTION_FALLBACK := {
	"neutral":    ["neutral", "thinking"],
	"curious":    ["curious", "engaged", "thinking", "neutral"],
	"thinking":   ["thinking", "neutral"],
	"engaged":    ["engaged", "curious", "excited", "thinking", "neutral"],
	"excited":    ["excited", "proud", "engaged", "thinking", "neutral"],
	"proud":      ["proud", "excited", "warming", "neutral"],
	"warming":    ["warming", "engaged", "neutral", "thinking"],
	"shy":        ["shy", "withdrawn", "anxious", "neutral"],
	"confused":   ["confused", "thinking", "anxious", "neutral"],
	"anxious":    ["anxious", "shy", "confused", "withdrawn", "neutral"],
	"frustrated": ["frustrated", "anxious", "withdrawn", "neutral"],
	"withdrawn":  ["withdrawn", "shy", "frustrated", "neutral"],
}

## Map the student model's free-form emotion_shown (or a move-derived affect) onto one
## of the 12 canonical emotion keys.
func _emotion_for(emotion_shown: String, tags: Array) -> String:
	var e := emotion_shown.strip_edges().to_lower()
	var syn := {
		"guarded": "withdrawn", "shutdown": "withdrawn", "shut_down": "withdrawn",
		"defiant": "frustrated", "annoyed": "frustrated", "angry": "frustrated",
		"nervous": "anxious", "worried": "anxious", "scared": "anxious",
		"embarrassed": "shy", "timid": "shy", "bashful": "shy",
		"interested": "curious", "wondering": "curious",
		"happy": "warming", "relieved": "warming", "calm": "neutral", "warm": "warming",
		"confident": "proud", "pleased": "proud",
		"aha": "excited", "surprised": "excited", "delighted": "excited",
		"attentive": "engaged", "focused": "engaged",
		"puzzled": "confused", "unsure": "confused",
		"pondering": "thinking",
	}
	if syn.has(e):
		e = syn[e]
	if EMOTION_FALLBACK.has(e):
		return e
	return _affect_for(tags)

## A short readable paraphrase of a menu move, so the transcript the student model and
## the coach see reads like real teacher talk (not bare tags).
func _move_gloss(tag: String) -> String:
	match tag:
		"elicit": return "Can you walk me through how you got that?"
		"extend": return "Okay, and what happens if you push that idea further?"
		"revoice": return "So what you're saying is..."
		"tell": return "Here's how it actually works: let me show you."
		"praise": return "I like how you explained your thinking there."
		"redirect": return "Let's bring our focus back to the problem."
		"wait": return "(waits quietly, giving you time to think)"
		"connect": return "Tell me about something you're really good at outside class."
		_: return "(addresses the student)"

func _affect_for(tags: Array) -> String:
	if "tell" in tags:
		return "withdrawn"
	if understanding >= 0.80:
		return "excited"
	if understanding >= 0.45:
		return "thinking"
	if "redirect" in tags:
		return "frustrated"
	if "elicit" in tags or "extend" in tags:
		return "engaged"
	return "confused"

## Swap to the best AVAILABLE imagegen2 portrait for the given emotion; if none of the
## fallback chain exists yet, tint the placeholder rect so state is still legible.
func _update_portrait(emotion: String) -> void:
	if _student_tex == null:
		return
	var chain: Array = EMOTION_FALLBACK.get(emotion, [emotion, "neutral", "thinking"])
	var t: Texture2D = null
	for affect in chain:
		t = Art.tex("res://assets/portraits/%s_%s.png" % [persona_id, affect])
		if t != null:
			break
	if t != null:
		_student_tex.texture = t
		_student_tex.visible = true
		_student_rect.visible = false
		_bounce_portrait()
	else:
		_student_tex.visible = false
		_student_rect.visible = true
		_student_rect.color = _affect_color(emotion)
	_update_emote(emotion)

## A quick squash-and-pop when the portrait/emotion changes, so reactions feel alive.
func _bounce_portrait() -> void:
	if _student_tex == null:
		return
	_student_tex.pivot_offset = _student_tex.size * 0.5
	if _port_tween != null and _port_tween.is_valid():
		_port_tween.kill()
	_student_tex.scale = Vector2(0.82, 1.12)   # squash on impact
	_port_tween = create_tween()
	_port_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_port_tween.tween_property(_student_tex, "scale", Vector2.ONE, 0.35)

func _update_emote(affect: String) -> void:
	if _emote == null:
		return
	var key := "dots"
	match affect:
		"excited", "proud", "frustrated", "anxious":
			key = "exclaim"
		"confused", "curious":
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
		"proud": return Color(0.30, 0.72, 0.55)
		"warming": return Color(0.55, 0.80, 0.50)
		"engaged": return Color(0.45, 0.75, 0.40)
		"curious": return Color(0.55, 0.72, 0.85)
		"thinking": return Color(0.85, 0.70, 0.30)
		"neutral": return Color(0.70, 0.70, 0.72)
		"shy": return Color(0.78, 0.62, 0.72)
		"withdrawn": return Color(0.45, 0.45, 0.55)
		"anxious": return Color(0.80, 0.72, 0.40)
		"frustrated": return Color(0.85, 0.35, 0.30)
		"confused": return Color(0.78, 0.55, 0.30)
		_: return Color(0.80, 0.28, 0.30)

func _set_dialogue(txt: String) -> void:
	if _dialogue != null:
		_reveal_label(_dialogue, txt, true)

func _set_coach(txt: String) -> void:
	if _coach != null:
		_reveal_label(_coach, txt, false)

func _reveal_label(label: Label, txt: String, is_dialogue: bool) -> void:
	label.text = txt
	if str(GameState.get_setting("text_reveal", "typewriter")) == "instant" or bool(GameState.get_setting("reduced_motion", false)):
		label.visible_characters = -1
		return
	var tween_ref := _dialogue_tween if is_dialogue else _coach_tween
	if tween_ref != null and tween_ref.is_valid():
		tween_ref.kill()
	label.visible_characters = 0
	var duration := clampf(float(txt.length()) / 72.0, 0.18, 1.8)
	tween_ref = create_tween()
	tween_ref.tween_property(label, "visible_characters", txt.length(), duration)
	if is_dialogue:
		_dialogue_tween = tween_ref
	else:
		_coach_tween = tween_ref

func _set_result(txt: String) -> void:
	if _result != null:
		_result.text = txt
