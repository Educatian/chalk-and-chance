extends Control
const Content = preload("res://scripts/Content.gd")
const UiText = preload("res://scripts/UiText.gd")
## The classroom encounter: read-act-observe loop against one LLM-driven student.
## Four meters (Engagement / Order / Rapport class-side, Composure = your HP), the
## seven teaching moves, and a Wait-Time Ring that rewards a 3 to 5s pause.
## See GAME_CONCEPT.md sections 3.2 to 3.7 and 7.

const Art = preload("res://scripts/Art.gd")
const PixelUi = preload("res://scripts/PixelUi.gd")
const PathJudge = preload("res://scripts/PathJudge.gd")
const Scaffold = preload("res://scripts/Scaffold.gd")
const CoachFeedback = preload("res://scripts/CoachFeedback.gd")
const CompactButtonStyle = preload("res://scenes/encounter/CompactButtonStyle.gd")
const InputFeel = preload("res://scripts/InputFeel.gd")
const TurnBeat = preload("res://scripts/TurnBeat.gd")
const UiKit = preload("res://scripts/UiKit.gd")
const Tuning = preload("res://scripts/Tuning.gd")
const ThinkRing = preload("res://scripts/ThinkRing.gd")
const ResultsCard = preload("res://scripts/ResultsCard.gd")
## v2 layout (480x270 authored = 1 unit per texel): portrait panel left, meters and the
## student's line in chalkboard panels right, verdict + coach line, move buttons below.
const PORTRAIT_PANEL := Rect2(8, 20, 140, 140)
const METER_PANEL := Rect2(154, 20, 318, 76)
const LINE_PANEL := Rect2(154, 100, 318, 60)
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
## One-line hints under each move button (interface microcopy, not lesson content).
const MOVE_HINTS := {
	"elicit": "ask how they got it", "extend": "push one step further", "revoice": "say it back to them",
	"tell": "explain it directly", "praise": "name what worked", "connect": "link to their world",
	"redirect": "bring focus back", "wait": "hold the silence",
}
const MOVE_HELP := {
	"elicit": "Elicit: ask how the student got that answer.",
	"extend": "Extend: press the idea one step further.",
	"revoice": "Revoice: say their idea back so everyone can check it.",
	"tell": "Tell: explain it yourself. Sometimes you have to. Often it does their thinking for them.",
	"praise": "Praise: say exactly what they did. 'Good job' doesn't count.",
	"connect": "Connect: find out what they're into, then hook the lesson to it.",
	"redirect": "Redirect: get them back on task with the smallest move that works.",
	"wait": "Wait: stay quiet until the Wait-Time bar goes green. Then pick a move.",
}

var persona_id := "noah_g5_fractions"
var display_name := "Noah"
var target_concept := "grade 5 fractions"
var opening_line := ""
var win_line := "Oh... I think I get it now!"
var target_badge := "echo"
var win_moves: Array = ["elicit", "extend", "revoice", "wait"]  # moves that work for THIS student
var _persona_data: Dictionary = {}
var _pj: RefCounted = null  # PathJudge: 2-3 defensible, context-sensitive paths
var _last_fit: Dictionary = {}
var _scaffold := {"level": 3, "name": "Full", "reason": ""}   # Scaffold.level_for() result
var _miss_streak := 0
var _stepped_in := false
var _scaffold_badge: Label

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
var _win_understanding := WIN_UNDERSTANDING

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
var _ring: Control                # B1: think-time ring around the student (ThinkRing)
var _thinking := false           # WT-I: the student is thinking after a question
var _think_resp: Dictionary = {} # their answer, held until the think time is over
var _think_t0 := 0
var _long_fired := false         # idle past Tuning.WT_LONG_MS already cost engagement
var _praise_btn: Button          # B3: its hint says live whether praise would be specific
var _shown_emotion := "neutral"   # the portrait state the player can read
var _noticed_cat := ""            # B2: category last noticed (prompt again when it changes)
var _notice_panel: Control        # B2: "what do you notice?" strip over the move row
var _notice_btns: Array = []
var _notice_hidden: Array = []    # move buttons hidden while the strip is up
var _notice_bonus := false        # B2: a correct read boosts the next landed move
var _notice_prompts := 0          # B2: extra inputs this encounter (reported)

# Node refs built in _ready().
var _name_label: Label
var _need_label: Label
var _student_name_label: Label
var _student_rect: ColorRect
var _student_tex: TextureRect
var _emote: TextureRect
var _backdrop: TextureRect
var _layer: Control
var _dialogue: Label
var _coach: Label
var _result: Label
var _dialogue_tween: Tween
var _coach_tween: Tween
var _bond_fill: ColorRect
var _bond_label: Label
var _bars: Dictionary = {}   # key -> ColorRect fill
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
# Turn-resolution beat: while a beat plays, result/coach text is held and revealed in order.
var _hold_text := false
var _pending_result := ""
var _pending_coach := ""
var _outcome_chip: Label = null
var _meters_live := false      # false while building: bars snap; true after: bars animate
var _meter_delay := 0.0

func _ready() -> void:
	_apply_upgrade_baselines()
	_build_ui()
	_refresh_meters()
	_set_dialogue("You walk over to %s's desk." % display_name)
	_set_coach("Look at them first. Find out what they think before you correct it. After you ask, let the ring fill. That's their thinking time.")
	_update_portrait("neutral")
	_meters_live = true
	_arm_turn()

func setup(data: Dictionary) -> void:
	persona_id = str(data.get("persona_id", persona_id))
	display_name = str(data.get("display_name", display_name))
	_load_persona()
	_apply_scenario_overrides()
	_pj = PathJudge.for_persona(_persona_data, win_moves)
	if _persona_data.has("paths"):
		win_moves = _pj.all_moves()    # a custom (imported) lesson can rewrite lines/targets to its content
	_refresh_backdrop()
	Game.note_visit(persona_id)    # equity: this student was called on
	_apply_relationship_headstart()
	_apply_adaptive_difficulty()
	_refresh_intro()
	_refresh_bond()
	_scaffold = Scaffold.level_for(Scaffold.skills_for_moves(win_moves))
	_apply_scaffold()
	_refresh_praise_hint()
	_maybe_prompt_notice()   # B2: the strip names this student

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

func _apply_adaptive_difficulty() -> void:
	var skills: Array = []
	for move in win_moves:
		var skill := str(Competency.TAG_SKILL.get(str(move), ""))
		if skill != "" and not (skill in skills):
			skills.append(skill)
	var d := Game.adaptive_difficulty(skills)
	var level := str(d.get("level", "standard"))
	if level == "scaffold":
		understanding = clampf(understanding + 0.05, 0.0, 1.0)
		engagement = clampf(engagement + 6.0, 0.0, 100.0)
		rapport = clampf(rapport + 4.0, 0.0, 100.0)
		_win_understanding = 0.75
	elif level == "challenge":
		understanding = clampf(understanding - 0.03, 0.0, 1.0)
		engagement = clampf(engagement - 4.0, 0.0, 100.0)
		rapport = clampf(rapport - 3.0, 0.0, 100.0)
		_win_understanding = 0.85
	else:
		_win_understanding = WIN_UNDERSTANDING
	if level != "standard" and _coach != null:
		_set_coach("%s, based on your past rounds. Read them, then pick the move that fits." % Game.adaptive_difficulty_label(d))
	_refresh_meters()

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
	if po.has("win_moves") and not _persona_data.has("paths"):
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
		"backdrop": str(scenario.get("backdrop", "")),
		"story_hook": str(scenario.get("story_hook", "")),
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
	var data = Content.localize(path, JSON.parse_string(txt))   # Variant, with the language overlay
	if typeof(data) != TYPE_DICTIONARY:
		return
	_persona_data = data
	if str(data.get("display_name", "")) != "":
		display_name = str(data["display_name"])   # localized name, whatever the caller passed
	target_concept = str(data.get("target_label", target_concept))
	opening_line = str(data.get("opening_line", opening_line))
	win_line = str(data.get("win_line", win_line))
	target_badge = str(data.get("badge", target_badge))
	win_moves = data.get("win_moves", win_moves)
	assets = data.get("assets", assets)
	asset_hint = str(data.get("asset_hint", asset_hint))
	connect_line = str(data.get("connect_line", connect_line))
	connect_resolves = bool(data.get("connect_resolves", connect_resolves))

func _support_level() -> int:
	return Scaffold.FULL if _stepped_in else int(_scaffold["level"])

## Show/hide supports for the current (skill-contingent) support level.
func _apply_scaffold() -> void:
	var lvl := _support_level()
	if _scaffold_badge == null:
		_scaffold_badge = _make_label("", Vector2(400, 6), UiText.S_MICRO, Color.WHITE)
		_scaffold_badge.clip_text = true
		_scaffold_badge.size = Vector2(76, 10)
		_scaffold_badge.mouse_filter = Control.MOUSE_FILTER_PASS
		PixelUi.scale_tree(_scaffold_badge, UI_SCALE)
	_scaffold_badge.text = Scaffold.badge_text(int(_scaffold["level"]), _stepped_in)
	_scaffold_badge.tooltip_text = str(_scaffold.get("reason", ""))
	_scaffold_badge.add_theme_color_override("font_color", Scaffold.badge_color(int(_scaffold["level"]), _stepped_in))
	_refresh_intro()
	if _text_input != null:
		var starter := ""
		if lvl == Scaffold.FULL and _pj != null and not _pj.paths.is_empty():
			var opener := str((_pj.paths[0]["steps"] as Array)[0][0])
			starter = str(CoachFeedback.MOVES.get(opener, {}).get("starter", ""))
		_text_input.placeholder_text = ("Try: " + starter) if starter != "" and starter.begins_with("\"") else "Type what you'd say..."
	if lvl < Scaffold.PARTIAL and _result != null and str(_result.text).contains(": "):
		_set_result("")
	if not _stepped_in:
		match lvl:
			Scaffold.FULL:
				pass
			Scaffold.PARTIAL:
				_set_coach("Watch them first.")
			_:
				_set_coach("")

func _refresh_intro() -> void:
	var show_need := _support_level() >= Scaffold.PARTIAL
	if _name_label != null:
		_name_label.text = ("ENCOUNTER  -  %s  (%s)" % [display_name, target_concept]) if show_need else "ENCOUNTER  -  %s" % display_name
	if _need_label != null:
		_need_label.text = ("Need: %s" % target_concept) if show_need else "Need: read %s's cues" % display_name
	if _student_name_label != null:
		_student_name_label.text = display_name
	if opening_line != "":
		_set_dialogue("%s: \"%s\"" % [display_name, opening_line])
		TTSClient.speak(persona_id, opening_line, "neutral")
	_update_portrait("neutral")

func _refresh_backdrop() -> void:
	if _backdrop == null:
		return
	var tex := Art.tex(Art.scenario_backdrop_path(_scenario_context, str(Game.current_scenario_id), false))
	_backdrop.texture = tex
	_backdrop.visible = tex != null

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.modulate = Color(1, 1, 1, 0.16)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	add_child(_backdrop)

	# All other UI lives in a 480x270-authored layer scaled up to the viewport.
	_layer = Control.new()
	_layer.scale = Vector2.ONE
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	var bd_tex := Art.tex("res://assets/v2/ui/encounter_backdrop_modern.png")
	if bd_tex != null:
		var bd := TextureRect.new()
		bd.texture = bd_tex
		bd.position = Vector2.ZERO
		bd.size = Vector2(480, 270)
		bd.stretch_mode = TextureRect.STRETCH_SCALE
		bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bd.modulate = Color(0.55, 0.57, 0.62)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bd)
	var title_frame := UiKit.panel("board")
	title_frame.position = Vector2(4, 1)
	title_frame.size = Vector2(392, 17)
	_layer.add_child(title_frame)
	for r in [PORTRAIT_PANEL, METER_PANEL, LINE_PANEL]:
		var pnl := UiKit.panel("board")
		pnl.position = r.position
		pnl.size = r.size
		_layer.add_child(pnl)
	_name_label = _make_label("ENCOUNTER  -  %s (grade 5 fractions)" % display_name, Vector2(10, 4), UiText.S_TITLE, Color("f2eedd"))
	_name_label.add_theme_font_override("font", UiKit.pixel_font())
	_name_label.size = Vector2(380, 12)
	_name_label.clip_text = true
	# The most important guidance sits inside the line panel, in the focus colour.
	_need_label = _make_label("Need: find out how they're thinking", LINE_PANEL.position + Vector2(10, 4), UiText.S_CAPTION, Color("ffd34e"))
	_need_label.size = Vector2(298, 12)
	_need_label.clip_text = true

	# Meters block, top-left.
	_bars["engagement"] = _make_meter("Engagement", 28, Color("5fbf6a"))
	_bars["order"] = _make_meter("Order", 43, Color("6fa8e8"))
	_bars["rapport"] = _make_meter("Rapport", 58, Color("e0a93a"))
	_bars["composure"] = _make_meter("Composure", 73, Color("ec8a6e"))

	# Student sprite, top-right (placeholder; affect portrait swaps in later).
	_student_rect = ColorRect.new()
	_student_rect.position = PORTRAIT_PANEL.position + Vector2(6, 6)
	_student_rect.size = Vector2(128, 128)
	_student_rect.color = Color(0.80, 0.28, 0.30)
	_student_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_student_rect)

	# Affect portrait overlay; shown only when an imagegen2 PNG is present.
	_student_tex = TextureRect.new()
	_student_tex.position = PORTRAIT_PANEL.position + Vector2(6, 4)
	_student_tex.size = Vector2(128, 128)
	_student_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # respect the 84x84 box, not the 128px source
	_student_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_student_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_student_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_student_tex.visible = false
	_layer.add_child(_student_tex)

	_student_name_label = _make_label(display_name, PORTRAIT_PANEL.position + Vector2(8, 124), UiText.S_TITLE, Color("f2eedd"))
	_student_name_label.size = Vector2(124, 12)
	_student_name_label.add_theme_font_override("font", UiKit.pixel_font())
	_student_name_label.add_theme_color_override("font_outline_color", Color("14131c"))
	_student_name_label.add_theme_constant_override("outline_size", 2)

	# Persistent relationship (warm demander). Carries across periods, unlike the class meters.
	# Drawn as ColorRects (like the gym bars) so the height is exactly controlled.
	_bond_label = _make_label("Bond", Vector2(392, 76), UiText.S_CAPTION, Color("d46a9a"))
	var bondbg := ColorRect.new()
	bondbg.position = Vector2(392, 86)
	bondbg.size = Vector2(70, 6)
	bondbg.color = Color(0, 0, 0, 0.5)
	bondbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bondbg)
	_bond_fill = ColorRect.new()
	_bond_fill.position = Vector2(392, 86)
	_bond_fill.size = Vector2(0, 6)
	_bond_fill.color = Color(0.95, 0.55, 0.70)
	_bond_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bond_fill)

	# Overhead emote bubble reflecting the student's reaction.
	_emote = TextureRect.new()
	_emote.position = PORTRAIT_PANEL.position + Vector2(114, 4)
	_emote.size = Vector2(22, 22)
	_emote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_emote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emote.visible = false
	_layer.add_child(_emote)

	# Student utterance shown in a speech bubble (9-slice) when art is present.
	_build_dialogue_box()

	# Result chip + coach tip box.
	_outcome_chip = Juice.make_outcome_chip(_layer, Vector2(10, 164), Vector2(56, 10), UiText.S_TINY)
	_outcome_chip.add_theme_font_override("font", UiKit.pixel_font())
	_outcome_chip.size = Vector2(56, 10)
	_result = _make_label("", Vector2(10, 164), UiText.S_CAPTION, Color("ffd34e"))
	_result.size = Vector2(448, 10)
	_result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_result.clip_text = true
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach = _make_label("", Vector2(10, 175), UiText.S_CAPTION, Color("a8d8b0"))
	_coach.size = Vector2(448, 14)
	_coach.clip_text = true
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_chip.set_meta("shift_labels", [_result, _coach])

	# Move buttons: two compact rows with a reserved mode column.
	var n := MOVES.size()
	var cols := 4
	var bw := 92.0
	var row_y := [190.0, 229.0]
	var short_labels := {}
	for i in range(n):
		var b := Button.new()
		var tag: String = MOVES[i][1]
		b.text = str(short_labels.get(tag, MOVES[i][0]))
		b.position = Vector2(8 + (i % cols) * (bw + 3.0), row_y[int(i / cols)])
		b.size = Vector2(bw, 35)
		b.clip_text = true
		UiKit.style_move_button(b, UiText.S_CAPTION, "res://assets/v2/ui/move_%s.png" % tag, MOVE_HINTS.get(tag, ""), UiText.S_TINY)
		InputFeel.add_hotkey_badge(b, i, UiText.S_TINY)
		b.set_meta("sfx_press", "commit")
		b.pressed.connect(_on_move.bind(tag))
		if tag == "praise":
			_praise_btn = b
		b.mouse_entered.connect(_preview_move.bind(tag))
		b.focus_entered.connect(_preview_move.bind(tag))
		_layer.add_child(b)
		b.size = Vector2(bw, 35)   # re-apply once themed fonts resolve in the tree
		_buttons.append(b)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

	# Free-text input (hidden until the player toggles to Type mode), sharing the move row.
	_text_input = LineEdit.new()
	_text_input.position = Vector2(8, 228)
	_text_input.size = Vector2(270, 30)
	_text_input.placeholder_text = "Type what you'd say..."
	_text_input.add_theme_font_size_override("font_size", 8)
	_text_input.visible = false
	_text_input.text_submitted.connect(func(_t): _on_type_submit())
	_layer.add_child(_text_input)

	_mic_btn = Button.new()
	_mic_btn.text = "Mic"
	_mic_btn.position = Vector2(286, 228)
	_mic_btn.size = Vector2(38, 30)
	CompactButtonStyle.apply(_mic_btn, UiText.S_CAPTION)
	_mic_btn.visible = false
	_mic_btn.disabled = not VoiceInput.is_supported()
	_mic_btn.tooltip_text = "Speak teacher talk" if VoiceInput.is_supported() else "Voice input is not supported in this browser."
	_mic_btn.pressed.connect(_start_voice_input)
	_layer.add_child(_mic_btn)

	_send_btn = Button.new()
	_send_btn.text = "Say"
	_send_btn.position = Vector2(340, 228)
	_send_btn.size = Vector2(46, 30)
	CompactButtonStyle.apply(_send_btn, UiText.S_BODY)
	_send_btn.visible = false
	_send_btn.pressed.connect(func(): _on_type_submit())
	_layer.add_child(_send_btn)

	# Mode toggle uses the reserved right column instead of floating over content.
	_type_toggle = Button.new()
	_type_toggle.text = "Type"
	_type_toggle.position = Vector2(392, 190)
	_type_toggle.size = Vector2(80, 35)
	UiKit.style_move_button(_type_toggle, UiText.S_CAPTION, "res://assets/v2/ui/move_type.png", "say it your way", UiText.S_TINY)
	_type_toggle.pressed.connect(_toggle_input_mode)
	_layer.add_child(_type_toggle)

	_build_item_row()
	PixelUi.scale_tree(_layer, UI_SCALE)
	# B1: the think-time ring sits on the student, in final pixels (built after scaling).
	_ring = ThinkRing.new()
	_ring.name = "ThinkRing"
	_ring.position = PORTRAIT_PANEL.position * UI_SCALE
	_ring.size = PORTRAIT_PANEL.size * UI_SCALE
	_ring.visible = false
	_layer.add_child(_ring)
	# Move hints are measured before their font resolves; pin them to their slot.
	if _type_toggle != null:
		_type_toggle.size = Vector2(80, 35) * UI_SCALE
		var th := _type_toggle.get_node_or_null("MoveHint") as Label
		if th != null:
			th.size = Vector2(72, 10) * UI_SCALE
	for b in _buttons:
		(b as Button).size = Vector2(92, 35) * UI_SCALE   # margins/icon are final-px; pin after scaling
		var h := (b as Node).get_node_or_null("MoveHint") as Label
		if h != null:
			h.size = Vector2(84, 10) * UI_SCALE
	UiText.keep_centered(_layer)

func _build_item_row() -> void:
	var x := 234.0
	var y := 56.0
	for id in GameState.equipped_item_ids():
		var item_id := str(id)
		var b := Button.new()
		b.position = Vector2(x, y)
		b.size = Vector2(32, 32)
		b.set_meta("item_id", item_id)
		b.tooltip_text = "%s x%d\n%s" % [Items.name_for(item_id), GameState.item_count(item_id), Items.desc_for(item_id)]
		b.disabled = not GameState.can_use_item(item_id, "encounter")
		CompactButtonStyle.apply(b, UiText.S_CAPTION)
		b.pressed.connect(_use_item.bind(item_id))
		var tex := Art.tex(Items.icon_for(item_id))
		if tex != null:
			PixelUi.add_centered_icon(b, tex, 4.0)
		else:
			b.text = Items.short_name_for(item_id)
			CompactButtonStyle.apply(b, UiText.S_MICRO)
		_layer.add_child(b)
		_item_buttons.append(b)
		x += 35.0

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
		_set_result("You can't use that right now.")
		return
	match id:
		"breathing_reset":
			var gain := 22.0 if GameState.teacher_profile_id == "steady" else 18.0
			composure = clampf(composure + gain, 0.0, GameState.max_composure())
			_set_result("Breathing Reset used  |  Composure +%d%s" % [int(gain), " profile bonus" if gain > 18.0 else ""])
			_set_coach("Coach Vee: good, you breathed first. Now try something smaller.")
		"student_profile_card":
			_asset_learned = true
			var rapport_gain := 8.0 if GameState.teacher_profile_id == "listener" else 4.0
			rapport = clampf(rapport + rapport_gain, 0.0, 100.0)
			var hint := asset_hint if asset_hint != "" else "%s needs you to hear their thinking before you correct it." % display_name
			if hint.length() > 72:
				hint = hint.substr(0, 69) + "..."
			_set_result("Student Profile Card used  |  New cue  |  Rapport +%d" % int(rapport_gain))
			_set_coach("Coach Vee: worth knowing. %s" % hint)
		"noticing_lens":
			var ways: Array = []
			if _pj != null:
				for p in _pj.paths:
					ways.append(str(p.get("label", "")))
			_set_result("Noticing Lens used  |  %d ways in" % ways.size())
			_set_coach("Coach Vee: a few things could work with %s: %s. Pick one and stick with it." % [display_name, " / ".join(ways)])
		"wait_meter_pin":
			_wait_item_ready = true
			_set_result("Wait Meter Pin used  |  next move counts as a full pause")
			_set_coach("Coach Vee: your next move counts as if you waited.")
		"lesson_map":
			understanding = clampf(understanding + 0.04, 0.0, 1.0)
			composure = clampf(composure + 4.0, 0.0, GameState.max_composure())
			_set_result("Lesson Map used  |  Understanding +4  |  Composure +4")
			_set_coach("Coach Vee: map checked. Now, what does this student need?")
		"practice_goal_card":
			_practice_goal_active = true
			_set_result("Practice Goal set  |  finish this one for bonus XP")
			_set_coach("Coach Vee: goal. Get them to show their thinking once before you fix the mistake.")
		_:
			_set_result("%s doesn't work here." % Items.name_for(id))
	_refresh_meters()
	_refresh_bond()
	_refresh_item_buttons()

func _toggle_input_mode() -> void:
	if _notice_panel != null and _notice_panel.visible:
		return   # B2: read the student first
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
		_set_result("Type it out. Offline, the game guesses which move you meant.")

func _start_voice_input() -> void:
	if _text_input == null:
		return
	if VoiceInput.start_for_line_edit(_text_input):
		_set_result("Listening... go ahead.")
	else:
		_set_result("This browser can't use the mic.")

func _preview_move(tag: String) -> void:
	if _busy or _resolved or _support_level() < Scaffold.PARTIAL:
		return
	_set_result(str(MOVE_HELP.get(tag, "")))

func _build_dialogue_box() -> void:
	# The student's line sits in the chalkboard panel (LINE_PANEL), written in chalk.
	var box_rect := LINE_PANEL
	var text_rect := Rect2(LINE_PANEL.position + Vector2(10, 17), LINE_PANEL.size - Vector2(20, 23))
	var holder := Control.new()
	holder.name = "DialogueBubble"
	holder.position = box_rect.position
	holder.size = box_rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(holder)
	_dialogue = _make_label("", text_rect.position, UiText.S_TITLE, Color("f2eedd"))
	_dialogue.name = "DialogueText"
	_dialogue.size = text_rect.size
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.set_meta("qa_container_rect", box_rect)
	_dialogue.set_meta("qa_text_rect", text_rect)
	_dialogue.set_meta("qa_min_padding", 6.0)

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

## Drawn as ColorRects (like the gym/lecture bars) so the 12px height is exactly
## controlled; ProgressBar inflates to its theme minimum and buried the Need line.
func _make_meter(name_txt: String, y: float, fill: Color) -> ColorRect:
	_make_label(name_txt, Vector2(162, y - 3), UiText.S_CAPTION, Color("f2eedd"))
	var bg := ColorRect.new()
	bg.position = Vector2(228, y)
	bg.size = Vector2(150, 10)
	bg.color = Color("14131c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bg)
	var fr := ColorRect.new()
	fr.position = Vector2(228, y)
	fr.size = Vector2(150, 10)
	fr.color = fill
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(fr)
	return fr

# --- turn loop ---------------------------------------------------------------

func _arm_turn() -> void:
	_busy = false
	_ready_at_ms = Time.get_ticks_msec()
	_long_fired = false
	_maybe_prompt_notice()
	_refresh_praise_hint()
	_refresh_item_buttons()

func _process(_delta: float) -> void:
	if _resolved:
		if _ring != null:
			_ring.visible = false
		return
	if _ring == null:
		return
	var now := Time.get_ticks_msec()
	if _thinking:
		# WT-I: the student thinks; the answer arrives when the ring is full.
		var t := float(GameState.wait_threshold_ms())
		_ring.show_state(ThinkRing.THINK, float(now - _think_t0) / t, tr("thinking..."))
		if now - _think_t0 >= int(t):
			_end_thinking(false)
		return
	if _busy:
		return
	if _notice_panel != null and _notice_panel.visible:
		_ring.show_state(ThinkRing.HIDDEN, 0.0, "")   # B2: reading first; the pause starts after
		return
	# WT-II: let the answer land, then the go cue. Long silence costs a little engagement.
	var idle := now - _ready_at_ms
	if _support_level() == Scaffold.OFF and idle < Tuning.WT_LONG_MS:
		_ring.show_state(ThinkRing.HIDDEN, 0.0, "")   # B5: count the pause yourself
	elif idle < Tuning.WT2_WINDOW_MS:
		_ring.show_state(ThinkRing.LAND, float(idle) / Tuning.WT2_WINDOW_MS, tr("let it land"))
	elif idle < Tuning.WT_LONG_MS or _turns == 0:   # the opening line is reading time
		_ring.show_state(ThinkRing.READY, 1.0, tr("your move"))
	else:
		_ring.show_state(ThinkRing.HIDDEN, 0.0, "")
		if not _long_fired:
			_long_fired = true
			engagement = clampf(engagement + Tuning.WT_LONG_ENGAGEMENT, 0.0, 100.0)
			_refresh_meters()
			Juice.float_text(_layer, tr("drifting"), _ring.position + Vector2(_ring.size.x * 0.5 - 30, _ring.size.y - 40), Color("aab6c8"), UiText.fs(14))
			Telemetry.log_event({"event": "wait_too_long", "scenario_id": str(Game.current_scenario_id),
				"persona_id": persona_id, "turn": _turns, "idle_ms": idle, "engagement_delta": Tuning.WT_LONG_ENGAGEMENT})

## WT-I over: reveal the held answer. cut = the teacher spoke into the think time, so the
## thought breaks (ring shatters, student drops it) and the question earns no wait credit.
func _end_thinking(cut: bool) -> void:
	_thinking = false
	var resp := _think_resp
	_think_resp = {}
	var held_ms := Time.get_ticks_msec() - _think_t0
	if cut:
		var judge: Dictionary = resp.get("judge", {})
		judge["wait_time_ok"] = false
		resp["judge"] = judge
		resp["cut"] = true
		resp["meter_deltas"] = Tuning.CUT_DELTAS.duplicate()
		resp["student_utterance"] = {"text": tr(Tuning.CUT_LINE), "emotion_shown": "frustrated"}
		resp["coach_tip"] = "You talked into their thinking time and %s lost the thought. After you ask, let the ring fill." % display_name
		_ring.shatter()
		Sfx.play("turn_wrong", -4.0, 1.3)
		if _student_tex != null:
			Juice.shake(_student_tex, 6.0, 6)
	else:
		_ring.show_state(ThinkRing.READY, 1.0, "")
		Sfx.play("tick")
	Telemetry.log_event({"event": "think_time", "scenario_id": str(Game.current_scenario_id),
		"persona_id": persona_id, "turn": _turns, "held_ms": held_ms, "cut": cut,
		"threshold_ms": GameState.wait_threshold_ms()})
	_on_reply(resp)

## Reply arrives: after a question (Tuning.THINK_TAGS) the student thinks first (WT-I).
func _on_reply_gate(resp: Dictionary) -> void:
	var tags: Array = resp.get("judge", {}).get("move_tags", [])
	var tag0 := str(tags[0]) if tags.size() > 0 else ""
	if tag0 in Tuning.THINK_TAGS and not _resolved:
		_think_resp = resp
		_thinking = true
		_think_t0 = Time.get_ticks_msec()
		_update_portrait("thinking")
		_set_dialogue(tr("%s is thinking...") % display_name)
		return
	_on_reply(resp)

func _on_move(tag: String) -> void:
	if _notice_panel != null and _notice_panel.visible:
		return
	if _thinking:
		_end_thinking(true)   # the press is spent speaking over them
		return
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
	if _notice_panel != null and _notice_panel.visible:
		return
	if _thinking:
		_end_thinking(true)
		return
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
	_turns += 1
	var raw_wait_ms := Time.get_ticks_msec() - _ready_at_ms
	var wait_ms := GameState.effective_wait_ms(raw_wait_ms)
	if _wait_item_ready:
		wait_ms = max(wait_ms, GameState.wait_threshold_ms())
		_wait_item_ready = false
	# B1 WT-II: a pause of Tuning.WT2_WINDOW_MS after their answer counts as waited (sent
	# as a full wait so backend/stub judge it the same way); think time is checked after.
	if wait_ms >= Tuning.WT2_WINDOW_MS:
		wait_ms = maxi(wait_ms, maxi(int(WAIT_FULL_MS), GameState.wait_threshold_ms()))
	elif _ring != null:
		Juice.float_text(_layer, tr("too soon"), _ring.position + Vector2(_ring.size.x * 0.5 - 30, _ring.size.y - 40), Color("ffb27a"), UiText.fs(14))
	_last_wait_ms = wait_ms
	if _ring != null:
		_ring.show_state(ThinkRing.HIDDEN, 0.0, "")
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
			"misconception_resolved": understanding >= _win_understanding,
			"turns_elapsed": _turns,
		},
		"teacher_move": teacher_move,
		"win_moves": win_moves,
		"dialogue_tail": _transcript.slice(maxi(0, _transcript.size() - 6)),
		"move_history": _move_history.slice(maxi(0, _move_history.size() - 6)),
		"model_profile": "openrouter_gemini",
	}
	if not LLMClient.reply_ready.is_connected(_on_reply_gate):
		LLMClient.reply_ready.connect(_on_reply_gate, CONNECT_ONE_SHOT)
	LLMClient.send_move(payload)

## B2: when the student's readable state changes (and at the start), ask what you notice
## before the next move. One tap; the move row is covered until you answer.
func _maybe_prompt_notice() -> void:
	if _resolved or _thinking:
		return
	if _notice_panel != null and _notice_panel.visible:
		(_notice_panel.get_node("Q") as Label).text = tr("Read %s first: what do you notice?") % display_name
		return
	var truth: Array = Tuning.NOTICE_TRUTH.get(_shown_emotion, ["distracted"])
	var cat := str(truth[0])
	if cat == _noticed_cat or _notice_prompts >= Tuning.NOTICE_MAX_PROMPTS:
		return
	_notice_prompts += 1
	if _notice_panel == null:
		_build_notice_panel()
	(_notice_panel.get_node("Q") as Label).text = tr("Read %s first: what do you notice?") % display_name
	_notice_panel.visible = true
	_notice_hidden = []
	for b in _buttons + [_text_input, _send_btn, _mic_btn, _type_toggle]:   # the strip replaces the move row until you answer
		if b != null and (b as Control).visible:
			(b as Control).visible = false
			_notice_hidden.append(b)
	_notice_btns[0].grab_focus()

func _build_notice_panel() -> void:
	_notice_panel = UiKit.panel("board")
	_notice_panel.name = "NoticePanel"
	_notice_panel.position = Vector2(8, 188) * UI_SCALE
	_notice_panel.size = Vector2(380, 76) * UI_SCALE
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_notice_panel)
	var q := Label.new()
	q.name = "Q"
	q.position = Vector2(14, 8)
	q.add_theme_font_size_override("font_size", UiText.fs(14))
	q.add_theme_color_override("font_color", Color("f2eedd"))
	_notice_panel.add_child(q)
	q.size = Vector2(_notice_panel.size.x - 28, 22)
	var bw := (_notice_panel.size.x - 28 - 3 * 8) / 4.0
	for i in range(Tuning.NOTICE_CHIPS.size()):
		var chip := str(Tuning.NOTICE_CHIPS[i])
		var b := Button.new()
		b.text = tr(str(Tuning.NOTICE_LABELS[chip]))
		UiKit.style_button(b, UiText.fs(14))
		InputFeel.add_hotkey_badge(b, i, UiText.fs(12))
		b.pressed.connect(_on_notice.bind(chip))
		_notice_panel.add_child(b)
		b.position = Vector2(14 + i * (bw + 8), 40)
		b.size = Vector2(bw, 52)
		_notice_btns.append(b)

func _on_notice(chip: String) -> void:
	var truth: Array = Tuning.NOTICE_TRUTH.get(_shown_emotion, ["distracted"])
	var right := chip in truth
	_noticed_cat = str(truth[0])
	_notice_panel.visible = false
	for b in _notice_hidden:
		if is_instance_valid(b):
			(b as Control).visible = true
	_notice_hidden = []
	_notice_bonus = right
	if _buttons.size() > 0:
		_buttons[0].grab_focus()
	Competency.observe_skill("noticing", "notice::%s" % persona_id, right)
	Telemetry.log_event({"event": "notice", "scenario_id": str(Game.current_scenario_id), "persona_id": persona_id,
		"turn": _turns, "chip": chip, "shown": _shown_emotion, "right": right, "prompt_n": _notice_prompts})
	if right:
		Sfx.play("tick")
		_set_result(tr("You read them right. If your next move lands, it counts a bit more."))
		_release_result()
	else:
		Sfx.play("turn_neutral")
		# One whole sentence per reading (a label dropped into a sentence reads badly in Korean).
		_set_coach("Coach Vee: " + tr("Look again. Their face and posture say %s. Answer that." % str(Tuning.NOTICE_LABELS[str(truth[0])]).to_lower()))
		_release_coach()
	_ready_at_ms = Time.get_ticks_msec()   # the pause starts once you have read them

func _refresh_praise_hint() -> void:
	if _praise_btn != null:
		var ph := _praise_btn.get_node_or_null("MoveHint") as Label
		if ph != null:
			ph.text = tr("names what they just did") if _praise_specific() else tr("nothing to name yet")

## B3: praise is specific only when there is something nameable: the last move landed, or
## praise fits the student's path now (a designed "catch them doing it right" moment).
func _praise_specific() -> bool:
	if not _move_history.is_empty() and bool(_move_history[-1].get("targets", false)):
		return true
	return _pj != null and _pj.fits_now("praise")

func _on_reply(resp: Dictionary) -> void:
	var ptags: Array = resp.get("judge", {}).get("move_tags", [])
	if ptags.size() > 0 and str(ptags[0]) == "praise":
		var pj: Dictionary = resp.get("judge", {})
		pj["praise_kind"] = "specific" if _praise_specific() else "generic"
		resp["judge"] = pj
		if pj["praise_kind"] == "generic":
			resp["meter_deltas"] = Tuning.PRAISE_GENERIC_DELTAS.duplicate()
			resp["coach_tip"] = "That praise was generic. They hadn't done anything yet to name. Praise right after they show their thinking, and say what they did."
	var before := _meter_snapshot()
	_hold_text = true
	_meter_delay = TURN_CUE_AT
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
	# Path judge is authoritative for fit: the same move can be right now and early later.
	var fit := {}
	if str(judge.get("praise_kind", "")) == "generic":
		fit = {"fit": "miss", "credit": 0.0, "path_id": "", "path_label": "", "done": false, "note": "the praise named nothing they did"}
		targets = false
	elif tag0 != "" and _pj != null:
		fit = _pj.evaluate(tag0, bool(judge.get("wait_time_ok", false)), bool(resp.get("cut", false)))
		targets = str(fit["fit"]) == "advance"
		var credit := float(fit["credit"])
		if _notice_bonus and str(fit["fit"]) == "advance":
			credit += Tuning.NOTICE_CREDIT_BONUS   # B2: you read them right first
			fit["credit"] = credit
		_notice_bonus = false
		understanding = clampf(understanding - float(deltas.get("understanding", 0.0)) + credit, 0.0, 1.0)
		deltas["understanding"] = credit
		_refresh_meters()
		if str(fit["fit"]) == "early":
			resp["coach_tip"] = "%s is the right idea for %s, just not yet: %s." % [tag0.capitalize(), display_name, str(fit["note"]).trim_prefix("right idea, too early: ")]
			_set_coach("Coach Vee: " + str(resp["coach_tip"]))
	_last_fit = fit
	_update_contingency(targets, tag0)
	_set_result(_result_text(tag0, targets, bool(judge.get("wait_time_ok", false)), deltas))
	var kind := TurnBeat.outcome(targets, str(fit.get("fit", "")))
	Game.log_move(tag0, bool(judge.get("wait_time_ok", false)), targets)
	# Accumulate the student's reply + the move outcome for coherence and adaptive coaching.
	_transcript.append({"speaker": display_name, "text": str(utter.get("text", ""))})
	_move_history.append({"turn": _turns, "tag": tag0, "targets": targets, "construct": Competency.TAG_SKILL.get(tag0, ""),
		"reaction": str(utter.get("text", "")), "meter": _result_text(tag0, targets, bool(judge.get("wait_time_ok", false)), deltas),
		"student": display_name, "fit": str(fit.get("fit", "")), "path": str(fit.get("path_label", "")), "note": str(fit.get("note", "")),
		"scaffold": _support_level()})
	if targets and tag0 in Tuning.VOICE_TAGS:
		Game.note_voiced(persona_id)   # B6: their thinking was heard
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
		"scaffold": {"level": int(_scaffold["level"]), "effective": _support_level(), "stepped_in": _stepped_in,
			"prob": float(_scaffold.get("prob", 0.5)), "evidence": int(_scaffold.get("evidence", 0))},
		"move": {"tag": tag0, "wait_ms": _last_wait_ms, "input_mode": _last_input_mode, "text": _last_free_text,
			"praise_kind": str(judge.get("praise_kind", "")), "think_cut": bool(resp.get("cut", false))},
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

	# Judgment, scoring and logging are done. Game state continues immediately (same
	# timing as before); only the presentation is staged by the beat.
	_play_turn_beat(kind, before)
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
	var before := _meter_snapshot()
	_meter_delay = TURN_CUE_AT
	_hold_text = true
	if not _asset_learned:
		_asset_learned = true
		rapport = clampf(rapport + 6.0, 0.0, 100.0)
		engagement = clampf(engagement + 5.0, 0.0, 100.0)
		GameState.add_bond(persona_id, 0.10)
		_refresh_meters()
		_refresh_bond()
		var hint := asset_hint if asset_hint != "" else "You ask %s what they're into outside of class." % display_name
		_set_dialogue("You stop and actually look at %s." % display_name)
		_set_coach("Coach Vee: %s  Press Connect again to tie the lesson to it." % hint)
		_update_portrait("thinking")
		_play_turn_beat(TurnBeat.NEUTRAL, before)
		_arm_turn()
		return
	# Bridge content to the now-known asset.
	rapport = clampf(rapport + 10.0, 0.0, 100.0)
	engagement = clampf(engagement + 12.0, 0.0, 100.0)
	composure = clampf(composure + 3.0, 0.0, GameState.max_composure())
	GameState.add_bond(persona_id, 0.18)
	var cfit: Dictionary = _pj.evaluate("connect") if _pj != null else {}
	var connect_advances := str(cfit.get("fit", "")) == "advance"
	if not connect_resolves and connect_advances:
		understanding = clampf(understanding + float(cfit["credit"]), 0.0, 1.0)
	if connect_resolves:
		# A landed asset-bridge is itself a valid route to the insight (the connect_line
		# states the full understanding), so it crosses the win gate.
		understanding = maxf(understanding, WIN_UNDERSTANDING + 0.05)
	_refresh_meters()
	_refresh_bond()
	var line := connect_line if connect_line != "" else "Oh... when you put it in my world, it actually makes sense."
	_set_dialogue("%s: \"%s\"" % [display_name, line])
	TTSClient.speak(persona_id, line, "excited" if connect_resolves else "thinking")
	Game.log_move("connect", false, connect_resolves or connect_advances)
	_move_history.append({"turn": _turns, "tag": "connect", "targets": connect_resolves or connect_advances, "construct": "funds_of_knowledge",
		"reaction": line, "meter": "Rapport up | Engagement up", "student": display_name,
		"fit": str(cfit.get("fit", "")), "path": str(cfit.get("path_label", ""))})
	_update_portrait("excited" if connect_resolves else "thinking")
	var ckind := TurnBeat.RIGHT if (connect_resolves or connect_advances) else TurnBeat.NEUTRAL
	_play_turn_beat(ckind, before)
	if connect_resolves and understanding >= WIN_UNDERSTANDING:
		_win("connect")
		return
	if connect_resolves:
		_set_coach("Coach Vee: you hooked it to something %s cares about. They're with you now. Keep going." % display_name)
	else:
		_set_coach("Coach Vee: that built some trust. %s still needs the lesson move, but now they'll let you lead." % display_name)
	_arm_turn()

## Contingent support: three misses in a row -> Coach Vee steps in with the need and
## one way in; the next fitting move hands control back to the player.
func _update_contingency(targets: bool, tag: String) -> void:
	if tag == "":
		return
	if targets:
		_miss_streak = 0
		if _stepped_in:
			_stepped_in = false
			_apply_scaffold()
		return
	_miss_streak += 1
	if _miss_streak >= Scaffold.STEP_IN_AFTER and not _stepped_in and int(_scaffold["level"]) < Scaffold.FULL:
		_stepped_in = true
		_apply_scaffold()
		var way := ""
		if _pj != null and not _pj.paths.is_empty():
			var p: Dictionary = _pj.paths[0]
			way = " One way in: %s (start with %s)." % [str(p.get("label", "")), str((p["steps"] as Array)[0][0]).capitalize()]
		_set_coach("Coach Vee steps in: %s needs %s.%s" % [display_name, target_concept.to_lower(), way])
		Telemetry.log_event({"event": "scaffold_step_in", "persona_id": persona_id, "scenario_id": str(Game.current_scenario_id), "level": int(_scaffold["level"])})

func _check_win(targets: bool, tags: Array) -> bool:
	if understanding < _win_understanding:
		return false
	if not targets:
		return false
	for t in tags:
		if t in win_moves:
			return true
	# Degraded judge response: backend marked the move on-target and the
	# understanding gate is crossed, but omitted move_tags. Treat as a win.
	if tags.is_empty():
		return true
	return false

func _win(route: String = "reasoning") -> void:
	_resolved = true
	_busy = true
	_disable_moves()
	Telemetry.log_event({"event": "resolve", "persona_id": persona_id, "route": route,
		"turns": _turns, "understanding": understanding, "badge": target_badge,
		"bond": GameState.bond(persona_id)})
	Telemetry.upload_competency()
	Telemetry.flush()   # push this lesson's events to the learner's cloud account
	var reward := GameState.award_badge(target_badge)
	if _practice_goal_active:
		GameState.add_teacher_xp(35, "practice_goal:%s" % str(Game.current_scenario_id))
	var run_record := GameState.record_leaderboard({
		"scenario_id": str(Game.current_scenario_id),
		"title": str(_scenario_context.get("title", display_name)),
		"mode": "1:1 Encounter",
		"badge": target_badge,
		"score": int(round(understanding * 100.0)) + maxi(0, 42 - _turns * 4) + int(round(GameState.bond(persona_id) * 30.0)),
		"detail": "%s reached in %d turns; bond %d%%" % [display_name, _turns, int(round(GameState.bond(persona_id) * 100.0))],
		"level_up": bool(reward.get("level_up", false)),
		"trace": Game.evidence_trace_from_moves(_move_history),
		"trace_steps": Game.evidence_trace_steps_from_moves(_move_history),
	})
	var warm := GameState.bond(persona_id) >= 0.4
	GameState.record_student(persona_id, {"resolved": true, "best_understanding": understanding, "bond": GameState.bond(persona_id)})
	# Land the turn beat now (its cue is muted once resolved) and go straight to the win.
	Juice.skip_beats(self)
	_present_win(route, warm, reward, run_record)

func _present_win(route: String, warm: bool, reward: Dictionary, run_record: Dictionary) -> void:
	_update_portrait("excited")
	Sfx.play("win")
	if route == "connect":
		# The connect_line is already shown as the resolving dialogue.
		_set_coach("Coach Vee: you got to %s through something they already know. You never had to tell them. Badge: %s." % [display_name, target_badge.to_upper()])
	else:
		_set_dialogue("%s: \"%s\"" % [display_name, win_line])
		TTSClient.speak(persona_id, win_line, "excited")
		if warm:
			_set_coach("Coach Vee: you were kind and you didn't lower the bar. They trusted you to hold it. Badge: %s." % target_badge.to_upper())
		else:
			_set_coach("Coach Vee: they got there on their own. Solid. Get to know them a bit next time, it makes tomorrow easier. Badge: %s." % target_badge.to_upper())
	_show_session_complete_panel(target_badge, reward, run_record)

## Product-grade end-of-encounter readout: reward, level, score, rank, evidence, next focus.
func _show_session_complete_panel(badge_id: String, reward: Dictionary, run_record: Dictionary) -> void:
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
	if _dialogue != null:
		_dialogue.visible = false
	if _result != null:
		_result.visible = false
	if _coach != null:
		_coach.visible = false

	var parts := _result_parts()
	var weak := ResultsCard.weakest(parts)
	var rank := str(run_record.get("rank", "-"))
	var card := ResultsCard.build(_layer, {
		"title": "Done with %s  ·  score %d" % [display_name, int(run_record.get("score", 0))],
		"rank": rank,
		"verdict": ResultsCard.verdict(rank, str(parts[weak]["label"])),
		"parts": parts,
		"rewards": {"badge": badge_id if bool(reward.get("badge_new", false)) else "",
			"caption": "First clear reward" if bool(reward.get("badge_new", false)) else "Completion",
			"none": tr("You already have the %s badge.") % tr(badge_id.capitalize()),
			"level_up": bool(reward.get("level_up", false)),
			"level_after": int(reward.get("level_after", GameState.teacher_level)), "items": reward.get("items_awarded", {})},
		"moments": _pivotal_moments(),
		"next": tr(str(NEXT_TARGET[weak])),
		"buttons": [{"label": "Return to room", "primary": true,
			"cb": func(): SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")}],
	})
	card.name = "SessionComplete"
	for b in card.find_children("*", "Button", true, false):
		_continue_btn = b

## Teaching-language next target for the weakest part (understanding, pace, bond).
const NEXT_TARGET := [
	"Ask for their thinking first (Elicit), then build on what they said (Extend) before you explain anything.",
	"Read the Need line and pick the move it points to. You'll get there in fewer turns.",
	"Hook it to something they care about. Stay warm and keep the bar high.",
]

## The three score parts the run score is made of, each with the decision behind it.
func _result_parts() -> Array:
	var landed := 0
	for m in _move_history:
		if bool(m.get("targets", false)):
			landed += 1
	var u := int(round(understanding * 100.0))
	var pace := maxi(0, 42 - _turns * 4)
	var bond_pts := int(round(GameState.bond(persona_id) * 30.0))
	return [
		{"label": "Understanding", "frac": u / 100.0, "value": "%d" % u,
			"cause": tr("{landed} of {total} moves landed on their path").format({"landed": landed, "total": _move_history.size()})},
		{"label": "Pace", "frac": pace / 42.0, "value": "%d" % pace,
			"cause": (tr("reached it in %d turn") if _turns == 1 else tr("reached it in %d turns")) % _turns},
		{"label": "Bond", "frac": bond_pts / 30.0, "value": "%d" % bond_pts,
			"cause": "they trust you more now" if bond_pts >= 10 else "not much connection yet"},
	]

## A4: up to three turning points from this encounter: the first move that landed, the
## first early/missed move, and the deciding move. Each reads: move -> reaction -> why.
func _pivotal_moments() -> Array:
	var picks: Array = []
	var first_hit := -1
	var first_off := -1
	for i in range(_move_history.size()):
		var fit := str(_move_history[i].get("fit", ""))
		if first_hit < 0 and fit == "advance":
			first_hit = i
		if first_off < 0 and fit in ["early", "miss"]:
			first_off = i
	for i in [first_hit, first_off, _move_history.size() - 1]:
		if i >= 0 and not i in picks:
			picks.append(i)
	picks.sort()
	var out: Array = []
	for i in picks:
		out.append(_moment_line(_move_history[i]))
	return out

func _moment_line(m: Dictionary) -> Dictionary:
	var fit := str(m.get("fit", ""))
	var tag := str(m.get("tag", ""))
	var said := str(m.get("reaction", ""))
	if said.length() > 56:
		said = said.substr(0, 54).strip_edges() + "…"
	var why := ""
	var kind := "neutral"
	match fit:
		"advance":
			kind = "right"
			why = ("it fit where they were (%s)" % str(m["path"]).to_lower()) if str(m.get("path", "")) != "" else "it fit where they were"
		"early":
			kind = "early"
			why = str(m.get("note", "")) if str(m.get("note", "")) != "" else "right idea, too early"
		"miss":
			kind = "wrong"
			why = str(m.get("note", "")) if str(m.get("note", "")) != "" else "it wasn't what they needed"
		_:
			why = "it kept the conversation open"
	return {"kind": kind, "text": "Turn %d  %s  ->  \"%s\"  ->  %s." % [int(m.get("turn", 0)), tr(tag.capitalize()), said, _tr_reason(why)]}

## A reason built from a PathJudge note or path label, translated piece by piece.
func _tr_reason(why: String) -> String:
	var cut := why.find(": ")
	if cut > 0:
		var head := why.substr(0, cut)
		return tr(head) + ": " + tr(why.substr(cut + 2))
	return tr(why)

func _show_badge_card(badge_id: String, reward: Dictionary = {}) -> void:
	if badge_id == "":
		return
	var card := Panel.new()
	card.position = Vector2(292, 110)
	var item_text := _items_awarded_text(reward.get("items_awarded", {}))
	card.size = Vector2(178, 94 if item_text != "" else (78 if bool(reward.get("level_up", false)) else 62))
	_layer.add_child(card)
	var text := "BADGE UNLOCKED\n%s" % badge_id.to_upper()
	if bool(reward.get("level_up", false)):
		text += "\nLEVEL %d  +1 UPGRADE" % int(reward.get("level_after", GameState.teacher_level))
	if item_text != "":
		text += "\nITEMS %s" % item_text
	var lbl := _make_label(text, Vector2(306, 122), UiText.S_BODY, Color(0.96, 0.86, 0.50))
	lbl.size = Vector2(150, 76)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not bool(GameState.get_setting("reduced_motion", false)):
		card.scale = Vector2(0.88, 0.88)
		card.pivot_offset = card.size / 2.0
		var tw := create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _force_recover() -> void:
	composure = minf(40.0, GameState.max_composure())
	_refresh_meters()
	_set_coach("Coach Vee: you're running on empty. Breathe. It happens to everyone. Try that part again.")
	_arm_turn()

func _result_text(tag: String, targets: bool, wait_ok: bool, deltas: Dictionary) -> String:
	var parts: Array = ["Understanding %d%%" % int(round(understanding * 100.0))]
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
	var fit_kind := str(_last_fit.get("fit", ""))
	if tag == "wait" and not wait_ok:
		parts.append("Too soon. Hold the pause longer")
	elif targets:
		var path := str(_last_fit.get("path_label", ""))
		parts.append(("On a path that works: %s" % path) if path != "" and path != "Core move" else "That's what %s needed" % display_name)
		if str(_last_fit.get("note", "")) != "":
			parts.append(str(_last_fit["note"]).capitalize())
	elif fit_kind == "early":
		parts.append("Right idea, too early")
	elif tag != "":
		parts.append("Not the move %s needs yet" % display_name)
	if _last_input_mode == "free_text":
		parts.append("read as %s" % tag.capitalize())
	# Each part is its own catalogue key; the joined line would match none.
	return "  |  ".join(parts.map(func(p): return tr(str(p))))

func _items_awarded_text(items) -> String:
	if typeof(items) != TYPE_DICTIONARY:
		return ""
	var dict: Dictionary = items
	var parts: Array = []
	for id in dict.keys():
		var amount := int(dict[id])
		if amount > 0:
			parts.append("%s x%d" % [Items.short_name_for(str(id)), amount])
	return ", ".join(parts)

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
	_set_meter_fill("engagement", engagement / 100.0)
	_set_meter_fill("order", order / 100.0)
	_set_meter_fill("rapport", rapport / 100.0)
	_set_meter_fill("composure", composure / maxf(1.0, GameState.max_composure()))

## Fill widths are set in post-scale_tree pixels (all callers run after _build_ui).
func _set_meter_fill(key: String, frac: float) -> void:
	var fill: ColorRect = _bars.get(key, null)
	if fill == null:
		return
	var target := Vector2(150.0 * UI_SCALE * clampf(frac, 0.0, 1.0), 10.0 * UI_SCALE)
	if _meters_live:
		Juice.bar_to(fill, target, 0.35, _meter_delay)
	else:
		fill.size = target

func _refresh_bond() -> void:
	var b := GameState.bond(persona_id)
	if _bond_fill != null:
		var target := Vector2(70.0 * UI_SCALE * clampf(b, 0.0, 1.0), 6.0 * UI_SCALE)
		if _meters_live:
			Juice.bar_to(_bond_fill, target, 0.35, _meter_delay)
		else:
			_bond_fill.size = target
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
		"extend": return "Okay. And what if you take that one step further?"
		"revoice": return "So what you're saying is..."
		"tell": return "Here, let me just show you how it works."
		"praise": return "You walked me through how you got that. That's what I want to see." if _praise_specific() else "Good job!"
		"redirect": return "Hey, eyes back on the problem."
		"wait": return "(waits quietly)"
		"connect": return "What are you really good at outside of school?"
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
	_shown_emotion = emotion
	if _student_tex == null:
		return
	var chain: Array = EMOTION_FALLBACK.get(emotion, [emotion, "neutral", "thinking"])
	var t: Texture2D = null
	for affect in chain:
		t = Art.tex("res://assets/v2/portraits/%s_%s.png" % [persona_id, affect])
		if t == null:
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
	_student_tex.scale = Vector2(0.94, 0.94)
	_port_tween = create_tween()
	_port_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_port_tween.tween_property(_student_tex, "scale", Vector2.ONE, 0.22)

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
	if _hold_text:
		_pending_coach = txt
		return
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
	if is_dialogue:
		# Soft per-student "voice" blips while the line types out (pitch fixed per student).
		var base_pitch := 0.88 + float(absi(hash(persona_id)) % 30) / 100.0
		var last := [0]
		tween_ref.tween_method(func(v: float):
			var c := int(v)
			label.visible_characters = c
			if c - last[0] >= 3:
				last[0] = c
				Sfx.play("type", -12.0, base_pitch * randf_range(0.96, 1.04)),
			0.0, float(txt.length()), duration)
	else:
		tween_ref.tween_property(label, "visible_characters", txt.length(), duration)
	if is_dialogue:
		_dialogue_tween = tween_ref
	else:
		_coach_tween = tween_ref

func _set_result(txt: String) -> void:
	if _hold_text:
		_pending_result = txt
		return
	if _result != null:
		_result.text = txt

# --- turn-resolution beat ------------------------------------------------------

const TURN_CUE_AT := 0.12     # outcome cue, chip, meter motion, deltas
const TURN_COACH_AT := 0.42   # coach line starts revealing
const TURN_END_AT := 0.75     # control returns (wait-time ring restarts here)

func _meter_snapshot() -> Dictionary:
	return {"engagement": engagement, "order": order, "rapport": rapport, "composure": composure}

## Student reaction is already showing (portrait + line). Then: outcome cue + chip + meters
## easing + floating deltas, then the coach line, then control comes back. Any press skips.
func _play_turn_beat(kind: String, before: Dictionary) -> void:
	Juice.skip_beats(self)
	_hold_text = true
	# Clear last turn's coach line so the old advice never sits next to the new verdict.
	if _coach != null:
		_coach.text = ""
	var beat := TurnBeat.new()
	beat.at(TURN_CUE_AT, func():
		if not _resolved:
			Sfx.play(TurnBeat.cue(kind))
		_show_outcome(kind)
		_release_result()
		_float_meter_deltas(before))
	beat.at(TURN_COACH_AT, _release_coach)
	beat.at(TURN_END_AT, func():
		_hold_text = false
		_meter_delay = 0.0)
	Juice.play_beat(self, beat)

func _release_result() -> void:
	var t := _pending_result
	_pending_result = ""
	if t != "" and _result != null:
		_result.text = _display_result(t)

## Display form of the result line (the stored/logged form is unchanged): the verdict
## phrase first, then only the changes, without the running "Understanding NN%" total.
func _display_result(t: String) -> String:
	var parts: Array = Array(t.split("  |  "))
	if parts.size() > 1 and str(parts[0]).begins_with("Understanding ") and str(parts[0]).ends_with("%"):
		parts.pop_front()
	var verdict := ""
	for i in range(parts.size() - 1, -1, -1):
		var ptxt := str(parts[i])
		if not (ptxt.contains("+") or ptxt.contains("-")) or ptxt.begins_with("On a path") or ptxt.begins_with("Not the move") or ptxt.begins_with("Right idea"):
			verdict = ptxt
			parts.remove_at(i)
			break
	if verdict != "":
		parts.push_front(verdict)
	return "  ·  ".join(parts)

func _release_coach() -> void:
	var t := _pending_coach
	_pending_coach = ""
	if t != "" and _coach != null:
		_reveal_label(_coach, t, false)

func _show_outcome(kind: String) -> void:
	Juice.show_outcome(_outcome_chip, kind)

## "+6" / "-10" next to each meter that moved, coloured by direction.
func _float_meter_deltas(before: Dictionary) -> void:
	var now := _meter_snapshot()
	for key in ["engagement", "order", "rapport", "composure"]:
		var d := int(round(float(now[key]) - float(before.get(key, now[key]))))
		var fill: ColorRect = _bars.get(key, null)
		if d == 0 or fill == null:
			continue
		var col := Color(0.55, 0.95, 0.60) if d > 0 else Color(1.0, 0.62, 0.52)
		var maxv := GameState.max_composure() if key == "composure" else 100.0
		var frac := clampf(float(now[key]) / maxf(1.0, maxv), 0.0, 1.0)
		var pos := Vector2(fill.position.x + 150.0 * UI_SCALE * frac + 4.0, fill.position.y - 3.0 * UI_SCALE)
		Juice.float_text(_layer, _signed(d), pos, col, int(8 * UI_SCALE))

## Any press (key, click, pad, touch) first finishes a running text reveal, so impatient
## readers are never stuck watching text trickle in. Handled in _input so the same press
## does not also fire the focused move button. Typing in the free-text box is left alone.
func _input(event: InputEvent) -> void:
	if not InputFeel.is_skip_press(event):
		return
	if event is InputEventKey and _text_input != null and _text_input.has_focus():
		return
	var skipped := Juice.skip_beats(self)
	for tw in [_dialogue_tween, _coach_tween]:
		if tw != null and tw.is_valid() and tw.is_running():
			tw.kill()
			skipped = true
	if skipped:
		if _dialogue != null:
			_dialogue.visible_characters = -1
		if _coach != null:
			_coach.visible_characters = -1
		get_viewport().set_input_as_handled()

## Number keys 1-8 choose a move directly (menu mode only).
func _unhandled_key_input(event: InputEvent) -> void:
	if _notice_panel != null and _notice_panel.visible:
		if InputFeel.press_hotkey(_notice_btns, event):
			get_viewport().set_input_as_handled()
		return
	if _busy or _resolved or _type_mode:
		return
	if InputFeel.press_hotkey(_buttons, event):
		get_viewport().set_input_as_handled()
