extends Node
## Dev: headless checks for the feel pass (input helpers, turn beat, honest feedback).
## Prints FEEL PASS/FAIL.
## Run: godot --headless --path . res://scenes/dev/FeelCheck.tscn
const InputFeel = preload("res://scripts/InputFeel.gd")
const TurnBeat = preload("res://scripts/TurnBeat.gd")
const CompletionFx = preload("res://scenes/encounter/CompletionFx.gd")
const UiText = preload("res://scripts/UiText.gd")
const ResultsCard = preload("res://scripts/ResultsCard.gd")
var fails := 0

func _ok(label: String, cond: bool) -> void:
	print("FEEL | [%s] %s" % ["OK " if cond else "XX", label])
	if not cond:
		fails += 1

func _key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	return e

func _ready() -> void:
	_check_hotkeys()
	_check_skip()
	_check_move_buffer()
	_check_grid_path()
	await _check_hotkey_press()
	_check_outcomes()
	_check_beat_order()
	await _check_juice()
	_check_text_scale()
	_check_results_grade()
	_check_praise_kinds()
	_check_voiced()
	_check_retry_focus()
	_check_ladder()
	_check_encounter_grades()
	_check_roster_safe_lines()
	_check_net_guard()
	_check_korean_catalogue()
	print("FEEL %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)

## Results card: grades stay honest and C/D never get a celebration colour.
func _check_results_grade() -> void:
	_ok("all objectives + 95% of best is S", ResultsCard.classroom_rank(0.95, 5, 5) == "S")
	_ok("a missed objective caps the grade at C", ResultsCard.classroom_rank(0.95, 4, 5) == "C")
	_ok("under half the objectives is D", ResultsCard.classroom_rank(0.95, 2, 5) == "D")
	_ok("low share with all objectives is still low", ResultsCard.classroom_rank(0.45, 3, 3) == "D")
	_ok("weakest part is the lowest share", ResultsCard.weakest([{"frac": 0.9}, {"frac": 0.2}, {"frac": 0.5}]) == 1)
	_ok("C/D grade colour is calm, not alarm red", ResultsCard.grade_color("D").r < 0.85 and ResultsCard.grade_color("D") == ResultsCard.grade_color("C"))

## B3: generic praise is not evidence of behaviour-specific praise; specific praise is.
func _check_praise_kinds() -> void:
	_ok("generic praise scores 0 for specific-praise skill", Competency.score_y("praise", {"praise_kind": "generic"}, {"trust": 0.02}) == 0)
	_ok("specific praise with trust gain scores 1", Competency.score_y("praise", {"praise_kind": "specific"}, {"trust": 0.08}) == 1)
	_ok("generic praise moves no understanding", float(load("res://scripts/Tuning.gd").PRAISE_GENERIC_DELTAS["understanding"]) == 0.0)

## B6: a visit alone is not a heard voice; each student counts once however often heard.
func _check_voiced() -> void:
	var keep := Game.lesson
	Game.start_lesson("discussion_fractions", 60.0)
	Game.note_visit("noah_g5_fractions")
	_ok("a visit alone does not count as heard", Game.voiced_count() == 0)
	Game.note_voiced("noah_g5_fractions")
	Game.note_voiced("noah_g5_fractions")
	Game.note_voiced("priya_quiet")
	_ok("heard students count once each", Game.voiced_count() == 2)
	Game.lesson = keep

## B8: the carried-forward objective moves to the front, flagged, nothing lost or duplicated.
func _check_retry_focus() -> void:
	var Ow = load("res://scenes/overworld/Overworld.gd")
	var objs := [{"metric": "attention_min"}, {"metric": "engaged_min"}, {"metric": "waittime_min"}]
	var out: Array = Ow.apply_retry_focus(objs, "waittime_min")
	_ok("retry focus becomes objective 1", out.size() == 3 and str(out[0]["metric"]) == "waittime_min" and bool(out[0].get("retry", false)))
	_ok("other objectives keep their order", str(out[1]["metric"]) == "attention_min" and str(out[2]["metric"]) == "engaged_min")
	_ok("unknown metric leaves objectives unchanged", Ow.apply_retry_focus(objs, "connect_min") == objs)
	_ok("source objectives are not mutated", not objs[2].has("retry"))

## B4: every ladder card has a step that works, and the bonus step is the lowest one.
func _check_ladder() -> void:
	var Ow = load("res://scenes/overworld/Overworld.gd")
	_ok("lowest working step skips steps that fail", Ow.lowest_working_tier([{"tier": 1, "works": false}, {"tier": 3, "works": true}, {"tier": 4, "works": true}]) == 3)
	var ow = Ow.new()
	for ev in ow.INTERRUPTS:
		if bool(ev.get("ladder", false)):
			var tiers := {}
			for o in ev["options"]:
				tiers[int(o["tier"])] = true
			_ok("ladder card '%s' has all four steps and a working one" % str(ev["text"]).left(24), tiers.size() == 4 and Ow.lowest_working_tier(ev["options"]) > 0)
	# No card text may name a roster student: the card fills names in from the students shown.
	var names: Array = []
	for f in DirAccess.get_files_at("res://data/persona_library"):
		if f.ends_with(".json"):
			names.append(str(JSON.parse_string(FileAccess.get_file_as_string("res://data/persona_library/" + f)).get("display_name", "")))
	var named := []
	for ev in ow.INTERRUPTS:
		for o in ev["options"]:
			for n in names:
				if n != "" and (str(o["label"]).contains(n) or str(o.get("coach", "")).contains(n)):
					named.append("%s in '%s'" % [n, str(o["label"])])
	_ok("no interrupt option names a fixed student (%s)" % ", ".join(named), named.is_empty())
	ow.free()

## Encounter grades use their own scale; saved ranks are only ever raised.
func _check_encounter_grades() -> void:
	var m := "1:1 Encounter"
	_ok("flawless encounter (120) is S", GameState._rank_for_score(120, m) == "S")
	_ok("solid win (113) is A", GameState._rank_for_score(113, m) == "A")
	_ok("one-detour floor (107) is B", GameState._rank_for_score(107, m) == "B")
	_ok("scraped win (97) is C", GameState._rank_for_score(97, m) == "C")
	_ok("weak score (60) is D", GameState._rank_for_score(60, m) == "D")
	_ok("classroom keeps the general scale", GameState._rank_for_score(120, "Classroom") == "C")
	var recs := [{"mode": m, "score": 121, "rank": "D"}, {"mode": m, "score": 40, "rank": "B"}, {"mode": "Lecture", "score": 121, "rank": "C"}]
	GameState.upgrade_saved_ranks(recs)
	_ok("saved encounter rank is raised from its score", recs[0]["rank"] == "S")
	_ok("saved encounter rank is never lowered", recs[1]["rank"] == "B")
	_ok("other modes are left as stored", recs[2]["rank"] == "C")

## Story lines name students only if they are in this lesson's roster.
func _check_roster_safe_lines() -> void:
	var N = load("res://scripts/Narrative.gd")
	var beat := {"text": "{talia_dominator} steered it.", "fallback": "One loud voice steered it."}
	_ok("roster name is filled in", N.line_text(beat, {"roster": [{"id": "talia_dominator", "name": "Talia"}]}) == "Talia steered it.")
	_ok("missing student falls back to the no-name line", N.line_text(beat, {"roster": [{"id": "sam_withdrawn", "name": "Sam"}]}) == "One loud voice steered it.")
	var bad := 0
	for c in (N._load().get("chapters", {}) as Dictionary).values():
		for b in c.get("intro", []) + [c.get("outro_win", {}), c.get("outro_retry", {})]:
			if str(b.get("text", "")).contains("{") and str(b.get("fallback", "")) == "":
				bad += 1
	_ok("every chapter line that names a student has a fallback", bad == 0)

## Debug builds refuse the hosted API unless opted in; release builds are unchanged.
func _check_net_guard() -> void:
	var G = load("res://scripts/NetGuard.gd")
	var api := "https://chalk-and-chance-api.jewoong-moon.workers.dev/turn"
	_ok("debug build refuses the hosted API by default", not G.decide(api, true, false))
	_ok("debug build allows it with the explicit opt-in", G.decide(api, true, true))
	_ok("release build is unchanged (hosted API allowed)", G.decide(api, false, false))
	_ok("local backend stays allowed in debug", G.decide("http://127.0.0.1:8008/turn", true, false) and G.decide("http://localhost:8008/turn", true, false))
	_ok("this headless debug run is not opted in", not G.allowed(api))

## The Korean catalogue translates exact text, formatted text and "Prefix: rest" text,
## picking the template that leaves nothing in English.
func _check_korean_catalogue() -> void:
	var T = load("res://scripts/PatternTranslation.gd").new()
	_ok("Korean catalogue loads", T.load_catalogue("res://i18n/ui_ko.json", "ko"))
	TranslationServer.add_translation(T)
	var keep := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	_ok("exact key", tr("Play") == "시작")
	_ok("formatted line keeps its numbers in Korean order", tr("Turn 3  Elicit  ->  \"Hi\"  ->  why.").begins_with("3턴"))
	_ok("coach prefix + formatted tip both translate", tr("Coach Vee:  Start with X. Wait longer than feels normal, and get everyone talking.").contains("부터 시작해요"))
	_ok("unknown text passes through unchanged", tr("Zzqx unknown line.") == "Zzqx unknown line.")
	TranslationServer.set_locale(keep)
	TranslationServer.remove_translation(T)
	var C = load("res://scripts/Content.gd")
	_ok("overlay merge keeps English where Korean is null", C.merge({"l": [{"t": "a", "k": 1}, {"t": "b"}]}, {"l": [null, {"t": "나"}]}) == {"l": [{"t": "a", "k": 1}, {"t": "나"}]})

func _check_hotkeys() -> void:
	_ok("1 maps to move 0", InputFeel.hotkey_index(_key(KEY_1)) == 0)
	_ok("8 maps to move 7", InputFeel.hotkey_index(_key(KEY_8)) == 7)
	_ok("keypad 3 maps to move 2", InputFeel.hotkey_index(_key(KEY_KP_3)) == 2)
	_ok("0 is not a move", InputFeel.hotkey_index(_key(KEY_0)) == -1)
	_ok("key release is ignored", InputFeel.hotkey_index(_key(KEY_2, false)) == -1)
	_ok("key repeat is ignored", InputFeel.hotkey_index(_key(KEY_2, true, true)) == -1)

func _check_skip() -> void:
	_ok("Enter skips", InputFeel.is_skip_press(_key(KEY_ENTER)))
	_ok("Shift alone does not skip", not InputFeel.is_skip_press(_key(KEY_SHIFT)))
	_ok("key repeat does not skip", not InputFeel.is_skip_press(_key(KEY_SPACE, true, true)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_ok("left click skips", InputFeel.is_skip_press(click))
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	_ok("pad button skips", InputFeel.is_skip_press(pad))
	_ok("mouse motion does not skip", not InputFeel.is_skip_press(InputEventMouseMotion.new()))

func _check_move_buffer() -> void:
	var b := InputFeel.MoveBuffer.new()
	b.window_ms = 150
	_ok("empty buffer yields nothing", b.take(0) == Vector2i.ZERO)
	b.press(Vector2i(1, 0), 1000)
	_ok("fresh tap is replayed", b.take(1100) == Vector2i(1, 0))
	_ok("a tap is replayed only once", b.take(1101) == Vector2i.ZERO)
	b.press(Vector2i(0, 1), 1000)
	_ok("stale tap is dropped", b.take(1200) == Vector2i.ZERO)
	b.press(Vector2i(0, 1), 1000)
	b.press(Vector2i(-1, 0), 1050)
	_ok("latest tap wins", b.take(1100) == Vector2i(-1, 0))
	b.press(Vector2i(0, -1), 1000)
	b.clear()
	_ok("clear empties the buffer", b.take(1001) == Vector2i.ZERO)

func _check_hotkey_press() -> void:
	var hits: Array = []
	var buttons: Array = []
	for i in 3:
		var btn := Button.new()
		btn.pressed.connect(func(): hits.append(i))
		add_child(btn)
		buttons.append(btn)
	await get_tree().process_frame
	_ok("hotkey 2 presses the second button", InputFeel.press_hotkey(buttons, _key(KEY_2)) and hits == [1])
	buttons[2].disabled = true
	_ok("disabled button is not pressed", not InputFeel.press_hotkey(buttons, _key(KEY_3)) and hits == [1])
	buttons[0].visible = false
	_ok("hidden button is not pressed", not InputFeel.press_hotkey(buttons, _key(KEY_1)) and hits == [1])
	_ok("out-of-range hotkey is ignored", not InputFeel.press_hotkey(buttons, _key(KEY_9)))
	for btn in buttons:
		btn.queue_free()

func _check_outcomes() -> void:
	_ok("on-target move reads as right", TurnBeat.outcome(true, "advance") == TurnBeat.RIGHT)
	_ok("'right idea, too early' reads as early, not wrong", TurnBeat.outcome(false, "early") == TurnBeat.EARLY)
	_ok("a miss reads as wrong", TurnBeat.outcome(false, "miss") == TurnBeat.WRONG)
	var cues := [TurnBeat.cue(TurnBeat.RIGHT), TurnBeat.cue(TurnBeat.EARLY), TurnBeat.cue(TurnBeat.WRONG)]
	_ok("right / early / wrong each have their own cue", cues[0] != cues[1] and cues[1] != cues[2] and cues[0] != cues[2])
	_ok("early and wrong have different labels", TurnBeat.label(TurnBeat.EARLY) != TurnBeat.label(TurnBeat.WRONG))
	for c in cues + ["commit", "win", "bump", "turn_neutral"]:
		_ok("Sfx has cue '%s'" % c, Sfx._streams.has(c))
	_ok("rank D gets no confetti", CompletionFx.confetti_count("D") == 0)
	_ok("rank B gets less confetti than S", CompletionFx.confetti_count("B") < CompletionFx.confetti_count("S"))

func _check_beat_order() -> void:
	var log: Array = []
	var beat := TurnBeat.new()
	beat.at(0.42, func(): log.append("coach"))
	beat.at(0.12, func(): log.append("cue"))
	beat.at(0.75, func(): log.append("end"))
	beat.advance(0.05)
	_ok("nothing fires before its time", log.is_empty())
	beat.advance(0.10)
	_ok("cue fires first, alone", log == ["cue"])
	beat.advance(0.30)
	_ok("coach line follows the cue", log == ["cue", "coach"])
	_ok("beat not done before the end step", not beat.is_done())
	beat.finish()
	_ok("finish runs the rest in order, once", log == ["cue", "coach", "end"] and beat.is_done())
	beat.finish()
	_ok("finishing twice does not repeat steps", log.size() == 3)

func _check_juice() -> void:
	var owner := Node.new()
	add_child(owner)
	var hits: Array = []
	var beat := TurnBeat.new()
	beat.at(5.0, func(): hits.append(1))
	Juice.play_beat(owner, beat)
	_ok("Juice tracks a running beat", Juice.has_beat(owner))
	_ok("skip_beats reports it skipped", Juice.skip_beats(owner))
	_ok("skipping runs the pending step", hits == [1] and not Juice.has_beat(owner))
	var freed := TurnBeat.new()
	freed.at(0.01, func(): hits.append(2))
	Juice.play_beat(owner, freed)
	owner.free()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok("a freed owner's beat is dropped, never run", hits == [1])
	var bar := ColorRect.new()
	add_child(bar)
	bar.size = Vector2(10, 4)
	var was: bool = bool(GameState.get_setting("reduced_motion", false))
	GameState.settings["reduced_motion"] = true
	Juice.bar_to(bar, Vector2(80, 4))
	_ok("reduced motion: bars snap to their value", bar.size == Vector2(80, 4))
	GameState.settings["reduced_motion"] = false
	Juice.bar_to(bar, Vector2(20, 4))
	_ok("with motion: bars ease (not instant)", bar.size != Vector2(20, 4))
	GameState.settings["reduced_motion"] = was
	bar.queue_free()

func _check_text_scale() -> void:
	var theme := ThemeDB.get_project_theme()
	var was: bool = bool(GameState.get_setting("large_text", false))
	GameState.settings["large_text"] = false
	UiText.apply_text_scale()
	var normal := theme.get_font_size(&"font_size", UiText.HUD)
	GameState.settings["large_text"] = true
	UiText.apply_text_scale()
	var large := theme.get_font_size(&"font_size", UiText.HUD)
	_ok("HUD text style exists in the theme", normal == int(UiText.BASE_SIZES[UiText.HUD]))
	_ok("Large text grows every themed label", large > normal)
	GameState.settings["large_text"] = was
	UiText.apply_text_scale()

func _check_grid_path() -> void:
	# 5x3 room with a wall at (2,0) and (2,1): the path must go around through row 2.
	var walls := {Vector2i(2, 0): true, Vector2i(2, 1): true}
	var walkable := func(t: Vector2i) -> bool:
		return t.x >= 0 and t.y >= 0 and t.x < 5 and t.y < 3 and not walls.has(t)
	var p := InputFeel.grid_path(Vector2i(0, 0), Vector2i(4, 0), walkable)
	_ok("path goes around the wall", p.size() == 9 and not p.has(Vector2i(2, 0)) and p[0] == Vector2i(0, 0) and p[-1] == Vector2i(4, 0))
	var steps_ok := true
	for i in range(1, p.size()):
		var d: Vector2i = p[i] - p[i - 1]
		steps_ok = steps_ok and (absi(d.x) + absi(d.y) == 1)
	_ok("path moves one tile at a time", steps_ok)
	_ok("blocked goal gives no path", InputFeel.grid_path(Vector2i(0, 0), Vector2i(2, 0), walkable).is_empty())
	walls[Vector2i(2, 2)] = true
	_ok("walled-off goal gives no path", InputFeel.grid_path(Vector2i(0, 0), Vector2i(4, 0), walkable).is_empty())
	_ok("start == goal is a zero-step path", InputFeel.grid_path(Vector2i(1, 1), Vector2i(1, 1), walkable) == [Vector2i(1, 1)])
