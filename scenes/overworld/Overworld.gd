extends Node2D
const Content = preload("res://scripts/Content.gd")
## Top-down classroom (US-style rows of individual desks; students seated facing the
## viewer with a desk in front). Exposes walkability + NPC lookup for the grid-moving
## Player. See GAME_CONCEPT.md sections 3.1 and 9.1.

const Art = preload("res://scripts/Art.gd")
const Seating = preload("res://scripts/Seating.gd")
const Narrative = preload("res://scripts/Narrative.gd")
const UiText = preload("res://scripts/UiText.gd")
const InputFeel = preload("res://scripts/InputFeel.gd")
const UiKit = preload("res://scripts/UiKit.gd")
const CoachCard = preload("res://scenes/ui/CoachCard.gd")
const ResultsCard = preload("res://scripts/ResultsCard.gd")
const Scaffold = preload("res://scripts/Scaffold.gd")
const Tuning = preload("res://scripts/Tuning.gd")
# Character-to-environment ratio: TILE 40 with a 24x13 room fills the 960x540 viewport
# while keeping the whole class visible (needed for the management/withitness layer).
# Student 1.35 tiles ~= 54px (~10% of screen height); teacher 1.7 tiles ~= 68px. This is
# ~2.5x larger relative to before (was 32px tiles in a sparse 30x17 room).
const TILE := 32   # 16-texel v2 tiles drawn at 2 px per texel
const COLS := 24
const ROWS := 13
const STUDENT_TILES_TALL := 1.35   # fallback placeholder height only
## One texel density for the whole room. Tiles, furniture and character sheets are all
## authored at 32 texels per tile, so everything is drawn at TILE/32 screen px per texel
## (1.25 at TILE 40). Characters are no longer normalised to a "tiles tall" target, which
## had put floor, students and teacher at three different densities.
const PX_PER_TEXEL := TILE / 16.0
const V2 := "res://assets/v2/"
## The room is a stage inside the 960x540 design frame: HUD bands above and below,
## the front wall (one extra tile tall) above row 0, gutters left and right.
const DESIGN := Vector2(960, 540)
const ROOM_ORIGIN := Vector2(96, 78)
const SEAT_FEET_Y := TILE - 1.0   # seated student's feet: bottom of the seat tile, behind the desk
const FLOOR_TILE := "res://assets/tiles/floor.png"
const DESK_TILE := "res://assets/tiles/desk.png"
const V2_DESK := "res://assets/v2/furniture/student_desk.png"
const V2_TEACHER_DESK := "res://assets/v2/furniture/teacher_desk.png"
const SEAT_FEET := 0.60    # student feet position within the seat tile (fraction of TILE)
const DESK_SCALE := 1.35   # desk width relative to a tile (overhangs a little)
const DESK_Y := 0.30       # desk top within the tile (fraction of TILE)

# Seating, roster, period and objectives are defined per scenario (data/scenarios/*.json);
# the arrangement comes from Seating.seats_for() (SEATING_ARRANGEMENTS.md, SCENES_AND_MISSIONS.md).

# Live classroom-management layer (proximity control + withitness). Teaches the teacher to
# circulate and scan rather than camp in one spot (orchestration / Kounin withitness).
const PROX_TILES := 3            # within this Manhattan distance = proximity control
const OFFTASK_RISE := 7.0        # base drift per second
const OFFTASK_AWAY_MULT := 2.2   # faster drift while the teacher faces the board (back to class)
const OFFTASK_RECOVER := 26.0    # per second while the teacher is near a student
const WITHIT_RECOVER := 5.0      # per second class-wide while the teacher faces the class

# Lesson ecology: a period clock and interrupt events the teacher must triage while
# managing the room (orchestration under competing demands).
const PERIOD_SECONDS := 150.0
const INTERRUPT_MIN := 11.0
const INTERRUPT_MAX := 20.0

# Each interrupt offers options; the least-intrusive/proactive choice usually costs the
# least Composure and adds the least off-task ("noise"). dcomp = Composure delta,
# dnoise = added to every student's off-task, ddis = disruptions added.
var INTERRUPTS := [
	{
		"text": "The intercom crackles. \"Attendance to the office, please.\"",
		"options": [
			{"label": "Give them a 30-second task, then do it", "dcomp": -6.0, "dnoise": 4.0, "ddis": 0,
			 "coach": "Good. They had something to do while you dealt with it."},
			{"label": "Stop teaching and do it now", "dcomp": -12.0, "dnoise": 16.0, "ddis": 0,
			 "coach": "Dead time. The class drifted while you stopped everything."},
		],
	},
	{
		"text": "Knock at the door. Another teacher needs a quick word.",
		"options": [
			{"label": "Set a task, go to the door, keep facing in", "dcomp": -7.0, "dnoise": 6.0, "ddis": 0,
			 "coach": "You could still see the whole room from the door. That's the move."},
			{"label": "Step out into the hall", "dcomp": -8.0, "dnoise": 22.0, "ddis": 1,
			 "coach": "The second you left, they were off. Stay where you can see them."},
		],
	},
	{
		"text": "A student walks in late, mid-lesson.",
		"ladder": true,
		"options": [
			{"label": "Nod at an open seat, keep going", "dcomp": -3.0, "dnoise": 5.0, "ddis": 0, "tier": 2, "works": true,
			 "coach": "Just a nod. The lesson never stopped."},
			{"label": "Walk them to a seat while you keep talking", "dcomp": -4.0, "dnoise": 8.0, "ddis": 0, "tier": 1, "works": false,
			 "coach": "You left the board for that. A nod from where you stood would have done it."},
			{"label": "Say quietly: \"Grab a seat, we're on page 4\"", "dcomp": -4.0, "dnoise": 7.0, "ddis": 0, "tier": 3, "works": true,
			 "coach": "Fine, but a nod would have done it without a word."},
			{"label": "Stop and question them in front of everyone", "dcomp": -10.0, "dnoise": 14.0, "ddis": 1, "tier": 4, "works": true,
			 "coach": "Doing that in front of everyone cost you, and them. Talk to them after class."},
		],
	},
	{
		"text": "Two students start a loud side conversation.",
		"ladder": true,
		"pair": true,
		"options": [
			{"label": "Walk toward them, keep talking", "dcomp": -2.0, "dnoise": -10.0, "ddis": 0, "tier": 1, "works": true,
			 "coach": "You walked over and they stopped. Can't get quieter than that."},
			{"label": "Catch their eye and pause", "dcomp": -3.0, "dnoise": -4.0, "ddis": 0, "tier": 2, "works": true,
			 "coach": "The look worked. Walking over would have cost you nothing, though."},
			{"label": "Say their names quietly, keep teaching", "dcomp": -4.0, "dnoise": 0.0, "ddis": 0, "tier": 3, "works": true,
			 "coach": "It worked. You didn't need words, though. Walking closer would have done it."},
			{"label": "Call them out across the room", "dcomp": -9.0, "dnoise": 12.0, "ddis": 1, "tier": 4, "works": true,
			 "coach": "Yelling across the room just pulled everybody else off task too."},
		],
	},
	{
		"text": "Two students start arguing over a shared calculator, voices rising.",
		"ladder": true,
		"pair": true,
		"options": [
			{"label": "Move toward them, keep talking", "dcomp": -5.0, "dnoise": 10.0, "ddis": 1, "tier": 1, "works": false,
			 "coach": "Standing close won't stop a fight that's already going. They needed a quick word."},
			{"label": "Give them a stern look", "dcomp": -5.0, "dnoise": 8.0, "ddis": 1, "tier": 2, "works": false,
			 "coach": "A look won't settle who gets the calculator. Tell them how to share it, quick."},
			{"label": "Say: \"One calculator, take turns, {a} first\"", "dcomp": -3.0, "dnoise": -6.0, "ddis": 0, "tier": 3, "works": true,
			 "coach": "That's it. Smallest thing that actually fixed it."},
			{"label": "Stop the class and lecture both about sharing", "dcomp": -10.0, "dnoise": 14.0, "ddis": 1, "tier": 4, "works": true,
			 "coach": "Stopped the argument. Stopped the lesson too. A quick quiet word would have done it."},
		],
	},
]

const COLOR_BG := Color(0.10, 0.09, 0.12)
const COLOR_FLOOR := Color(0.46, 0.37, 0.28)
const COLOR_WALL := Color(0.20, 0.22, 0.30)
const COLOR_DESK := Color(0.55, 0.40, 0.22)

# Which seat (col index, row index into SEAT_COLS/SEAT_ROWS) each student occupies.
var _seats: Array = []        # seat tiles for the loaded arrangement
var _format: String = ""      # scenario format (discussion/group_work/...) -> idle animation
var _objectives: Array = []   # scenario objectives, scored at debrief
var _offtask_rise := OFFTASK_RISE
var _attempt := 1
var _scenario_title := "Lesson"
var _badge := ""
var _scenario_cfg: Dictionary = {}
var _lesson_won := false
var _last_moves: Array = []

var _walls: Dictionary = {}   # Vector2i -> true
var _npcs: Dictionary = {}    # Vector2i -> { persona_id, display_name, node, offtask, fill }
var _player: Node2D = null

# HUD for the live classroom state.
var _attention_fill: ColorRect = null
var _disrupt_label: Label = null
var _equity_label: Label = null
var _objective_label: Label = null
var _objective_toggle: Button = null
var _hud: Node2D = null
var _objective_plate: Panel = null
var _objectives_open := false
var _objective_toast_left := 0.0
var _last_objectives_met := -1
var _room_cue := ""
var _interact_label: Label = null
var _coach_hint: Label = null
var _disruptions := 0

# Lesson ecology state.
var input_locked := false        # Player checks this to freeze movement during overlays
var _composure := 100.0
var _composure_fill: ColorRect = null
var _clock_label: Label = null
var _period_left := PERIOD_SECONDS
var _next_interrupt := 9.0
var _interrupt_clock_left := 0.0   # B4: seconds the clock still runs while a card is open
var _lesson_over := false
var _overlay: Control = null
var _pending_card := {}   # results card data, shown after the reflection step
var _back_secs := 0.0      # time spent facing the board (A5: the cause behind attention)
var _room_support := 3     # B5: Scaffold level for room management (behavior_mgmt estimate)

func _ready() -> void:
	var cfg := _load_scenario(Game.current_scenario_id)
	_scenario_cfg = cfg
	_scenario_title = str(cfg.get("title", "Lesson"))
	_room_support = int(Scaffold.level_for(["behavior_mgmt"])["level"])
	_format = str(cfg.get("format", ""))
	_offtask_rise = float(cfg.get("offtask_rise", OFFTASK_RISE))
	# Resume the in-progress period (returning from an encounter) or start a fresh one.
	if Game.lesson_active(Game.current_scenario_id):
		_period_left = float(Game.lesson.get("period_left", cfg.get("period_seconds", PERIOD_SECONDS)))
		_composure = float(Game.lesson.get("composure", GameState.max_composure()))
		_disruptions = int(Game.lesson.get("disruptions", 0))
	else:
		Game.start_lesson(Game.current_scenario_id, float(cfg.get("period_seconds", PERIOD_SECONDS)))
		_period_left = float(cfg.get("period_seconds", PERIOD_SECONDS))
		_composure = GameState.max_composure()
		GameState.note_attempt(Game.current_scenario_id)
	_objectives = cfg.get("objectives", [])
	if str(Game.retry_focus.get("scenario_id", "")) == str(Game.current_scenario_id):
		_objectives = apply_retry_focus(_objectives, str(Game.retry_focus.get("metric", "")))
	_badge = str(cfg.get("badge", ""))
	_seats = Seating.seats_for(str(cfg.get("arrangement", "ushape")))
	# Deliberate-practice fade: each replay makes the room drift faster.
	_attempt = GameState.attempt_count(Game.current_scenario_id)
	_offtask_rise *= 1.0 + 0.12 * float(min(_attempt - 1, 4))

	# Characters and furniture share one draw layer and are ordered by row (y-sort), so a
	# student behind a desk, the desk, and the teacher walking past overlap correctly.
	y_sort_enabled = true
	_build_room()
	var occupied: Dictionary = {}
	for entry in cfg.get("roster", []):
		var idx: int = int(entry.get("seat", 0))
		if idx >= 0 and idx < _seats.size():
			var tile: Vector2i = _seats[idx]
			if occupied.has(tile):
				continue  # duplicate/colliding seat in roster; skip to avoid orphaned, unscored sprite
			occupied[tile] = true
			_spawn_npc(tile, str(entry.get("id", "")), str(entry.get("name", "Student")))
	# Restore each student's off-task level if resuming the period.
	var ot_saved: Dictionary = Game.lesson.get("offtask", {})
	for st in _npcs.keys():
		_npcs[st]["offtask"] = float(ot_saved.get(_npcs[st]["persona_id"], 0.0))
	_build_seating(occupied)
	_spawn_player(Vector2i(11, 2))
	_add_badge_strip()
	_build_hud()
	UiText.keep_centered(self, DESIGN, ROOM_ORIGIN)
	if (Game.lesson.get("moves", []) as Array).is_empty() and Game.lesson.get("disruptions", 0) == 0:
		CoachCard.show_focus_banner(self, str(Game.current_scenario_id))
	Telemetry.log_event({
		"event": "classroom_start", "scenario_id": str(Game.current_scenario_id),
		"title": _scenario_title, "format": _format, "attempt": _attempt,
		"objectives": _objectives.size(), "students": _npcs.size(),
		"composure": _composure, "resumed": Game.lesson_active(Game.current_scenario_id),
	})

func setup(_data: Dictionary) -> void:
	pass

func _load_scenario(id: String) -> Dictionary:
	var path := Game.scenario_path(id)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = Content.localize(path, JSON.parse_string(f.get_as_text()))
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				return d
	return {"title": "Lesson", "arrangement": "ushape", "period_seconds": PERIOD_SECONDS,
			"roster": [], "objectives": []}

## Placeholder color for a student before their art is generated (from persona "color").
func _persona_color(id: String) -> Color:
	var path := "res://data/persona_library/%s.json" % id
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY and d.has("color"):
				var c = d["color"]
				if c is Array and c.size() >= 3:
					return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(0.80, 0.28, 0.30)

# --- world geometry ----------------------------------------------------------

func _build_room() -> void:
	_add_rect(Vector2(0, -TILE), Vector2(COLS * TILE, (ROWS + 1) * TILE), COLOR_BG, -20)
	if Art.tex(V2 + "tiles/floor_0.png") == null:
		_build_room_legacy()
		return
	# Modern classroom (docs/ui-design-plan.md 5.1). US is the default; the "Classroom
	# look" setting switches to the Korean variant. Same grid, seats and walls either way.
	var st := _room_style()
	var room := V2 + "room_%s/" % st
	var common := V2 + "room_common/"
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			_v2_sprite(room + "floor_%d.png" % (absi(hash(Vector2i(x, y))) % 4), Vector2(x * TILE, y * TILE), -19)
	# Front of the room: carpet area (US) / play mat (KR) in front of the board.
	for x in range(9, 15):
		for y in range(1, 3):
			var piece := ("t" if y == 1 else "b")
			if x == 9:
				piece += "l"
			elif x == 14:
				piece += "r"
			_v2_sprite(room + "rug_%s.png" % piece, Vector2(x * TILE, y * TILE), -18)
	# Front wall, drawn one tile above the room over row 0.
	var front := {1: room + "front_door.png", 20: common + "front_clock.png"}
	if st == "us":
		front.merge({3: common + "anchor_0.png", 5: common + "anchor_1.png", 7: common + "anchor_3.png",
			16: common + "anchor_2.png", 18: common + "anchor_4.png"})
	else:
		front.merge({4: common + "anchor_3.png", 17: common + "anchor_1.png"})
	for x in range(COLS):
		_walls[Vector2i(x, 0)] = true
		var path: String = front.get(x, common + "front_plain.png")
		if x >= 9 and x <= 14:
			path = room + "board_%d.png" % (x - 9)
		_v2_sprite(path, Vector2(x * TILE, -TILE), -10)
	# Windows along one side, displays and storage along the other, storage at the back.
	var left_wall: Array
	var right_wall: Array
	var back_wall: Array
	var ww := "windowwall_%s" if st == "us" else "windowwall_kr_%s"
	# Left: one continuous window wall in two long runs, plain wall between and at the ends.
	left_wall = ["wall_cap", ww % "top", ww % "mid", ww % "mid", ww % "bottom", "wall_cap",
		ww % "top", ww % "mid", ww % "mid", ww % "bottom", "wall_cap"]
	if st == "us":
		# Right: a display zone near the front, plain wall, a reading corner at the back.
		right_wall = ["wall_cap", "bulletin_0", "bulletin_1", "wall_cap", "purifier", "wall_cap", "wall_cap",
			"plant", "bookshelf_0", "bookshelf_1", "bookshelf_2"]
		# Back: a cubby bank and a supply station; plain wall elsewhere.
		back_wall = ["wall_cap", "wall_cap", "wall_cap", "bins_0", "bins_1", "bins_2", "bins_0", "bins_1",
			"wall_cap", "wall_cap", "wall_cap", "wall_cap", "wall_cap", "wall_cap", "wall_cap", "wall_cap",
			"wall_cap", "sink", "bins_2", "plant", "wall_cap", "wall_cap", "wall_cap", "wall_cap"]
	else:
		right_wall = ["wall_cap", "bulletin_0", "bulletin_2", "wall_cap", "purifier", "wall_cap", "wall_cap",
			"wall_cap", "plant", "bookshelf_0", "wall_cap"]
		# Back: the locker bank and the cleaning-tool corner.
		back_wall = ["wall_cap", "cleaning", "wall_cap", "lockers_0", "lockers_1", "lockers_2", "lockers_0",
			"lockers_1", "lockers_2", "lockers_0", "lockers_1", "lockers_2", "wall_cap", "wall_cap", "wall_cap",
			"wall_cap", "bulletin_1", "bulletin_3", "wall_cap", "wall_cap", "plant", "wall_cap", "wall_cap", "wall_cap"]
	for y in range(1, ROWS - 1):
		_walls[Vector2i(0, y)] = true
		_walls[Vector2i(COLS - 1, y)] = true
		_v2_sprite(common + "%s.png" % left_wall[(y - 1) % left_wall.size()], Vector2(0, y * TILE), -10)
		_v2_sprite(common + "%s.png" % right_wall[(y - 1) % right_wall.size()], Vector2((COLS - 1) * TILE, y * TILE), -10)
	for x in range(0, COLS):
		_walls[Vector2i(x, ROWS - 1)] = true
		_v2_sprite(common + "%s.png" % back_wall[x % back_wall.size()], Vector2(x * TILE, (ROWS - 1) * TILE), -10)
	# Teacher's desk spans two tiles at the front-left.
	_walls[Vector2i(2, 2)] = true
	_walls[Vector2i(3, 2)] = true
	var td := Node2D.new()
	td.position = Vector2(2 * TILE, 2 * TILE)
	td.z_index = 1
	var tdt := Art.tex(V2 + "room_%s/teacher_desk.png" % _room_style())
	if tdt == null:
		tdt = Art.tex(V2_TEACHER_DESK)
	var tds := Sprite2D.new()
	tds.texture = tdt
	tds.centered = false
	tds.scale = Vector2(PX_PER_TEXEL, PX_PER_TEXEL)
	tds.position = Vector2(round((2 * TILE - tdt.get_width() * PX_PER_TEXEL) / 2.0), round(TILE - 1 - tdt.get_height() * PX_PER_TEXEL))
	td.add_child(tds)
	add_child(td)

## "us" (default) or "kr", from the Classroom look setting.
func _room_style() -> String:
	return "kr" if bool(GameState.get_setting("korean_classroom", false)) else "us"

func _v2_tile(tile: Vector2i, rel: String, z: int) -> void:
	_v2_sprite(V2 + rel, Vector2(tile.x * TILE, tile.y * TILE), z)

func _v2_sprite(path: String, pos: Vector2, z: int) -> void:
	var t := Art.tex(path)
	if t == null:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PX_PER_TEXEL, PX_PER_TEXEL)
	s.position = pos
	s.z_index = z
	add_child(s)

## Pre-v2 room (32-texel tiles), kept as a fallback if the v2 art is missing.
func _build_room_legacy() -> void:
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			_put_tile(Vector2i(x, y), "res://assets/tiles/floor.png", COLOR_FLOOR, -19, false)
	for x in range(COLS):
		_add_wall(Vector2i(x, 0))
		_add_wall(Vector2i(x, ROWS - 1))
	for y in range(ROWS):
		_add_wall(Vector2i(0, y))
		_add_wall(Vector2i(COLS - 1, y))
	for x in range(9, 15):
		_decor(Vector2i(x, 0), "res://assets/tiles/board.png")
	_add_desk(Vector2i(2, 2))
	_add_desk(Vector2i(3, 2))

## Seats holding a student get their desk drawn over the student in _spawn_npc; the
## remaining seats show a standalone (empty) desk here.
func _build_seating(occupied: Dictionary) -> void:
	for s in _seats:
		if not occupied.has(s):
			_add_desk(s)
	if Art.tex(V2 + "room_%s/rug_m.png" % _room_style()) != null:
		_dress_room(occupied)

## Non-blocking set dressing that makes the seating read as an intentional group: a rug
## spanning the space the desks enclose, empty chairs at empty desks, backpacks by the
## occupied ones, a few worksheets on the floor. Nothing here touches _walls.
func _dress_room(occupied: Dictionary) -> void:
	if _seats.is_empty():
		return
	var minx := 99
	var maxx := -1
	var miny := 99
	var maxy := -1
	for s in _seats:
		minx = mini(minx, s.x)
		maxx = maxi(maxx, s.x)
		miny = mini(miny, s.y)
		maxy = maxi(maxy, s.y)
	# Rug inside the seating block (one tile in from the desks), at least 3x2.
	var rx0 := minx + 1
	var rx1 := maxx - 1
	var ry0 := miny + 1
	var ry1 := maxy - 1
	if rx1 - rx0 >= 2 and ry1 - ry0 >= 1:
		for x in range(rx0, rx1 + 1):
			for y in range(ry0, ry1 + 1):
				var t := Vector2i(x, y)
				if _seats.has(t):
					continue
				var piece := "m"
				if y == ry0:
					piece = "t"
				elif y == ry1:
					piece = "b"
				if x == rx0:
					piece = (piece + "l") if piece != "m" else "l"
				elif x == rx1:
					piece = (piece + "r") if piece != "m" else "r"
				_v2_tile(t, "room_%s/area_%s.png" % [_room_style(), piece], -18)
	var i := 0
	for s in _seats:
		i += 1
		if not occupied.has(s):
			_decor_sprite("room_%s/chair.png" % _room_style(), Vector2(s.x * TILE + 4, s.y * TILE - 2), Vector2i(s.x, s.y))
		elif i % 2 == 0:
			_decor_sprite("furniture/backpack_%d.png" % (i % 6), Vector2(s.x * TILE + TILE - 2, s.y * TILE + 14), Vector2i(s.x, s.y))
	# Margin zones (review note): a reading corner at the back right and floor plants in
	# the front corners. Walkable, and skipped wherever a layout puts a seat nearby.
	var corner := Rect2i(18, 9, 4, 2)
	var corner_free := true
	for s2 in _seats:
		if Rect2i(corner.position - Vector2i.ONE, corner.size + Vector2i(2, 2)).has_point(s2):
			corner_free = false
	if corner_free:
		var room := "room_%s/" % _room_style()
		for x in range(corner.position.x, corner.end.x):
			for y in range(corner.position.y, corner.end.y):
				var piece := ("t" if y == corner.position.y else "b")
				if x == corner.position.x:
					piece += "l"
				elif x == corner.end.x - 1:
					piece += "r"
				_v2_tile(Vector2i(x, y), room + "rug_%s.png" % piece, -18)
		var ci := 0
		for t in [Vector2(18.3, 9.4), Vector2(19.6, 10.2), Vector2(20.9, 9.5)]:
			_decor_sprite("room_common/cushion_%d.png" % ci, Vector2(t.x * TILE, t.y * TILE), Vector2i(int(t.x), int(t.y)))
			ci += 1
	for t in [Vector2i(1, 1), Vector2i(COLS - 2, 1)]:
		if not _seats.has(t) and not _walls.has(t):
			_decor_sprite("room_common/floor_plant.png", Vector2(t.x * TILE + 4, t.y * TILE - 6), t)
	for k in range(4):
		var h := absi(hash(Vector2i(k * 7 + 3, k * 5 + 1)))
		var t := Vector2i(2 + h % (COLS - 4), 3 + (h / 7) % (ROWS - 5))
		if not _walls.has(t) and not _seats.has(t):
			_v2_sprite(V2 + "furniture/floor_paper.png", Vector2(t.x * TILE + 8 + h % 12, t.y * TILE + 10 + h % 10), -17)

## Pick the idle loop from the student's drift (presentation only; drift itself is
## computed above and is unchanged). A faced student raises a hand: "you can talk to me".
## A3: proximity and withitness made visible. A small green "calm" when standing near a
## student drops them a drift band (never while they are already settled, so parking
## beside one student earns nothing), and a "?" over students behind you while you face
## the board.
func _room_feedback(info: Dictionary, ot: float, near: bool, unseen: bool) -> void:
	var band := 0 if ot < 35.0 else (1 if ot < 65.0 else 2)
	var node: Node2D = info.get("node", null)
	var fill: ColorRect = info.get("fill", null)
	if node == null or fill == null:
		return
	if near and band < int(info.get("band", band)):
		Juice.float_text(node, "calm", fill.position + Vector2(-2, -16), Color("7fe08a"), UiText.fs(12))
	info["band"] = band
	var q: Label = info.get("q", null)
	if q == null and unseen:
		q = Label.new()
		q.text = "?"
		q.position = fill.position + Vector2(8, -22)
		q.z_index = 9
		q.add_theme_font_size_override("font_size", UiText.fs(14))
		q.add_theme_color_override("font_color", Color("ffd34e"))
		q.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		q.add_theme_constant_override("outline_size", 4)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(q)
		info["q"] = q
	if q != null:
		q.visible = unseen

## B5: name the drifting student in HUD text only while room support is Partial/Full.
func _room_names_shown() -> bool:
	return _room_support >= Scaffold.PARTIAL

func _set_student_state(info: Dictionary, faced: bool) -> void:
	var a = info.get("anim", null)
	if not (a is AnimatedSprite2D) or not a.sprite_frames.has_animation("focused"):
		return
	var ot := float(info.get("offtask", 0.0))
	var want := "hand" if faced else ("focused" if ot < 35.0 else ("restless" if ot < 65.0 else "drifting"))
	if a.animation != want:
		a.play(want)

## A y-sorted decor sprite (chairs, backpacks) that belongs to a tile row.
func _decor_sprite(rel: String, pos: Vector2, row_tile: Vector2i) -> void:
	var t := Art.tex(V2 + rel)
	if t == null:
		return
	var holder := Node2D.new()
	holder.position = Vector2(row_tile.x * TILE, row_tile.y * TILE)
	holder.z_index = 1
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.scale = Vector2(PX_PER_TEXEL, PX_PER_TEXEL)
	s.position = pos - holder.position
	holder.add_child(s)
	add_child(holder)

## Standalone (empty) desk on a seat tile; blocks the tile. Same cut-out desk, at the same
## texel density and placement, as the desks in front of seated students.
func _add_desk(tile: Vector2i) -> void:
	_walls[tile] = true
	var holder := Node2D.new()
	holder.position = Vector2(tile.x * TILE, tile.y * TILE)
	holder.z_index = 1
	holder.add_child(_desk_sprite())
	add_child(holder)

## The desk cut out of desk.png (floor pixels removed), at the room's texel density, sitting
## on the bottom of its tile and centred. Falls back to the full tile if the cut-out fails.
func _desk_sprite() -> Node2D:
	var v2 := Art.tex(V2 + "room_%s/desk.png" % _room_style())
	if v2 == null:
		v2 = Art.tex(V2_DESK)
	if v2 != null:
		var d := Sprite2D.new()
		d.texture = v2
		d.centered = false
		d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		d.scale = Vector2(PX_PER_TEXEL, PX_PER_TEXEL)
		d.position = Vector2(round((TILE - v2.get_width() * PX_PER_TEXEL) / 2.0), round(TILE - v2.get_height() * PX_PER_TEXEL + 2))
		return d
	var cut := Art.cutout(DESK_TILE, FLOOR_TILE)
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cut != null:
		s.texture = cut
		s.scale = Vector2(PX_PER_TEXEL, PX_PER_TEXEL)
		var sz := Vector2(cut.get_width(), cut.get_height()) * PX_PER_TEXEL
		s.position = Vector2(round((TILE - sz.x) / 2.0), round(TILE - 1.0 - sz.y))
	else:
		var full := Art.tex(DESK_TILE)
		if full != null:
			s.texture = full
			s.scale = Vector2(TILE / float(full.get_width()), TILE / float(full.get_height()))
	return s

func _add_wall(tile: Vector2i, color: Color = COLOR_WALL) -> void:
	_put_tile(tile, "res://assets/tiles/wall.png", color, -10, true)

## Places a textured tile if the PNG is imported, else a flat ColorRect. Marks the tile
## as a wall (blocking) when is_wall is true.
func _put_tile(tile: Vector2i, tex_path: String, color: Color, z: int, is_wall: bool) -> void:
	if is_wall:
		_walls[tile] = true
	var t := Art.tex(tex_path)
	if t != null:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(TILE / float(t.get_width()), TILE / float(t.get_height()))
		s.position = Vector2(tile.x * TILE, tile.y * TILE)
		s.z_index = z
		add_child(s)
	else:
		_add_rect(Vector2(tile.x * TILE, tile.y * TILE), Vector2(TILE, TILE), color, z)

func _decor(tile: Vector2i, tex_path: String) -> void:
	var t := Art.tex(tex_path)
	if t != null:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(TILE / float(t.get_width()), TILE / float(t.get_height()))
		s.position = Vector2(tile.x * TILE, tile.y * TILE)
		s.z_index = -9
		add_child(s)

func _add_rect(pos: Vector2, size: Vector2, color: Color, z: int) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

## Shows earned badges as icons in the top-right (GAME_CONCEPT.md gym-badge progression).
func _add_badge_strip() -> void:
	var order := ["routine", "echo", "balance", "mirror", "insight"]
	var x := DESIGN.x - 36.0
	for id in order:
		if not GameState.has_badge(id):
			continue
		var t := Art.tex("res://assets/ui/badge_%s.png" % id)
		if t == null:
			continue
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.position = Vector2(x, 9)
		r.size = Vector2(28, 28)
		r.z_index = 60
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_node().add_child(r)
		x -= 30.0

# --- actors ------------------------------------------------------------------

## Build a looping idle AnimatedSprite2D from a 6-frame strip (<persona>_idle.png, 192x64:
## neutral/breathe/look-left/look-right/hand-raise/lean-work). Returns null if the strip is
## absent, so the caller falls back to the static stand frame. Animation + tempo + start
## frame are picked by scenario format and randomized so the class is not in lockstep.
func _build_idle_anim(persona_id: String, feety: float) -> AnimatedSprite2D:
	var sheet := Art.tex(V2 + "sprites/%s_seated.png" % persona_id)
	if sheet == null:
		sheet = Art.tex("res://assets/sprites/%s_idle.png" % persona_id)
	if sheet == null:
		return null
	var nframes := 7 if sheet.resource_path.contains("/v2/") else 6
	var fw := int(sheet.get_width() / float(nframes))
	var fh := int(sheet.get_height())
	if fw < 8 or fh < 16:
		return null
	var b0 := Art.opaque_bounds(sheet, Rect2i(0, 0, fw, fh))
	if b0.size.y <= 0:
		return null
	var sc := PX_PER_TEXEL
	var frames := SpriteFrames.new()
	var sets := {
		"idle": [0, 1, 0, 2, 0, 3],
		"discuss": [0, 1, 4, 0, 2, 1],
		"work": [0, 5, 0, 1, 5, 0],
	}
	if nframes == 7:
		# v2: animation follows the student's state (see _set_student_state)
		sets = {
			"focused": [0, 1, 0, 1, 0, 6, 0, 1],      # breathing + an occasional blink
			"restless": [2, 0, 3, 0, 2, 3, 0, 6],     # glancing around
			"drifting": [5, 5, 2, 5, 5, 3],           # head down, looking away
			"hand": [4],                              # hand up: the teacher is facing them
		}
	for anim_name in sets:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 2.5)
		for i in sets[anim_name]:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(int(i) * fw, 0, fw, fh)
			frames.add_frame(anim_name, at)
	frames.remove_animation("default")
	var asp := AnimatedSprite2D.new()
	asp.set_meta("figure_h", b0.size.y)
	asp.sprite_frames = frames
	asp.centered = false
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	asp.scale = Vector2(sc, sc)
	asp.position = Vector2(TILE / 2.0 - (float(b0.position.x) + float(b0.size.x) / 2.0) * sc, feety - float(b0.position.y + b0.size.y) * sc)
	var anim := "idle"
	if nframes == 7:
		anim = "focused"
	elif _format == "group_work":
		anim = "work"
	elif _format == "discussion":
		anim = "discuss"
	asp.play(anim)
	asp.speed_scale = 0.7 + randf() * 0.6   # desync tempo per student
	asp.frame = randi() % 6                  # desync starting frame
	return asp

func _spawn_npc(tile: Vector2i, persona_id: String, display_name: String) -> void:
	var node := Node2D.new()
	node.position = Vector2(tile.x * TILE, tile.y * TILE)
	var head_y := 0.0
	var char_spr: Node2D = null    # the character body, animated with an idle/gesture loop
	var sheet := Art.tex("res://assets/sprites/%s_walk.png" % persona_id)
	var t := Art.tex("res://assets/sprites/%s_ow.png" % persona_id)
	# The student sits BEHIND their desk: feet at the bottom of the seat tile, then the desk
	# is drawn after (in front), covering the legs. Same texel density as the room.
	var feety := SEAT_FEET_Y
	var idle_anim := _build_idle_anim(persona_id, feety)
	if idle_anim != null:
		node.add_child(idle_anim)
		char_spr = idle_anim
		head_y = feety - float(idle_anim.get_meta("figure_h")) * PX_PER_TEXEL
	elif sheet != null and sheet.get_width() >= 48 and sheet.get_height() >= 128:
		# Normalize by the DRAWN figure (stand frame), not the cell, so all students match.
		var cw := int(sheet.get_width() / 3.0)
		var ch := int(sheet.get_height() / 4.0)
		var b := Art.opaque_bounds(sheet, Rect2i(cw, 0, cw, ch))
		var sc := PX_PER_TEXEL
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(cw, 0, cw, ch)
		var s := Sprite2D.new()
		s.texture = at
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(sc, sc)
		s.position = Vector2(TILE / 2.0 - (float(b.position.x) + float(b.size.x) / 2.0) * sc, feety - float(b.position.y + b.size.y) * sc)
		node.add_child(s)
		char_spr = s
		head_y = feety - b.size.y * sc
	elif t != null:
		var tb := Art.opaque_bounds(t, Rect2i(0, 0, t.get_width(), t.get_height()))
		# Legacy half-resolution (16x32) sheet: drawn at 2x texels to match 32x64 sheets.
		var sc2 := PX_PER_TEXEL * (64.0 / float(maxi(1, t.get_height())))
		var s2 := Sprite2D.new()
		s2.texture = t
		s2.centered = false
		s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s2.scale = Vector2(sc2, sc2)
		s2.position = Vector2(TILE / 2.0 - (float(tb.position.x) + float(tb.size.x) / 2.0) * sc2, feety - float(tb.position.y + tb.size.y) * sc2)
		node.add_child(s2)
		head_y = feety - tb.size.y * sc2
	else:
		var body := ColorRect.new()
		body.size = Vector2(TILE * 0.7, TILE * STUDENT_TILES_TALL)
		body.position = Vector2(TILE * 0.15, feety - TILE * STUDENT_TILES_TALL)
		body.color = _persona_color(persona_id)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(body)
		head_y = feety - STUDENT_TILES_TALL * TILE

	node.add_child(_desk_sprite())   # in front of the seated student
	_add_talk_emote(node, head_y)

	# Name under the desk, centred, drawn above every body so a student in the next row
	# can never clip it.
	var tag := Label.new()
	tag.text = display_name
	tag.position = Vector2(-TILE * 0.75, TILE + 1)
	tag.size = Vector2(TILE * 2.5, 14)
	tag.theme_type_variation = UiText.NAME
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.z_index = 8
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", UiText.fs(12))
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 5)
	node.add_child(tag)

	# Off-task bar above the head (green = attentive, red = drifting).
	var barbg := ColorRect.new()
	barbg.size = Vector2(24, 4)
	barbg.position = Vector2(4, head_y - 8)
	barbg.color = Color(0, 0, 0, 0.55)
	barbg.z_index = 6
	node.add_child(barbg)
	var barfill := ColorRect.new()
	barfill.size = Vector2(0, 4)
	barfill.position = Vector2(4, head_y - 8)
	barfill.color = Color(0.3, 0.8, 0.4)
	barfill.z_index = 7
	node.add_child(barfill)

	node.z_index = 1
	add_child(node)
	_npcs[tile] = {
		"persona_id": persona_id, "display_name": display_name, "node": node,
		"offtask": 0.0, "fill": barfill, "anim": char_spr,
	}

## A bobbing "!" bubble just above an NPC's head to invite interaction.
func _add_talk_emote(node: Node2D, head_y: float) -> void:
	var t := Art.tex(V2 + "ui/talk_bubble.png")
	var v2 := t != null
	if t == null:
		t = Art.tex("res://assets/ui/emote_exclaim.png")
	if t == null:
		return
	var e := Sprite2D.new()
	e.texture = t
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := PX_PER_TEXEL if v2 else 20.0 / float(t.get_width())
	e.scale = Vector2(sc, sc)
	# Beside the head (upper right), so it never sits on the row above.
	# Reserved slots: the name sits under the desk, the drift bar over the head, and the
	# bubble to the right of the shoulders, so none of them can land on a neighbour's.
	e.position = Vector2(TILE + 6.0, head_y + 20.0) if v2 else Vector2(TILE / 2.0 - 10.0, head_y - 32.0)
	e.z_index = 5
	node.add_child(e)
	var y0 := e.position.y
	var tw := create_tween().set_loops()
	tw.tween_property(e, "position:y", y0 - 4.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(e, "position:y", y0, 0.6).set_trans(Tween.TRANS_SINE)

func _spawn_player(tile: Vector2i) -> void:
	var p := Node2D.new()
	p.set_script(load("res://scenes/overworld/Player.gd"))
	p.position = Vector2(tile.x * TILE, tile.y * TILE)
	p.z_index = 1   # same layer as students and desks; y-sort decides overlap
	p.overworld = self          # set before add_child so _ready() can read TILE
	add_child(p)
	_player = p

# --- live classroom management (proximity + withitness) ----------------------

## Translucent rounded plate that groups HUD text so it reads over any floor art.
func _hud_plate(pos: Vector2, size: Vector2, _accent: Color = Color.WHITE) -> Panel:
	var p := UiKit.panel("board")
	p.position = pos
	p.size = size
	p.z_index = 55
	_hud_node().add_child(p)
	return p

## HUD lives in 960x540 design coordinates on a node placed at -ROOM_ORIGIN, so it frames
## the room instead of sitting on it.
func _hud_node() -> Node2D:
	if _hud == null:
		_hud = Node2D.new()
		_hud.name = "Hud"
		_hud.position = -ROOM_ORIGIN
		_hud.z_index = 50
		add_child(_hud)
	return _hud

const HUD_ATT_W := 150.0
const HUD_COMP_W := 120.0
const OBJ_TOAST_SECONDS := 3.0

## Classroom HUD lives in two bands that never cover a student: the front wall row
## (top, y 0-40) and the back wall row + empty aisle (bottom). Seats are rows 3-10.
## Objectives are collapsed to one line (O or click to expand) and pop open briefly
## when one is met.
func _build_hud() -> void:
	var top := 2.0
	var bot := DESIGN.y - 44.0
	_hud_plate(Vector2(4, top), Vector2(DESIGN.x - 8, 42))
	_hud_plate(Vector2(4, bot), Vector2(DESIGN.x - 8, 42))

	_hud_icon("icon_attention", Vector2(16, top + 13))
	_hud_text("ATTENTION", Vector2(38, top + 5), UiText.HUD)
	_hud_bar_bg(Vector2(38, top + 24), Vector2(HUD_ATT_W + 4, 12))
	_attention_fill = _hud_fill(Vector2(40, top + 26), Vector2(HUD_ATT_W, 8), Color("5fbf6a"))

	_hud_icon("icon_composure", Vector2(212, top + 13))
	_hud_text("COMPOSURE", Vector2(234, top + 5), UiText.HUD, Color("f2eedd"))
	_hud_bar_bg(Vector2(234, top + 24), Vector2(HUD_COMP_W + 4, 12))
	_composure_fill = _hud_fill(Vector2(236, top + 26), Vector2(HUD_COMP_W, 8), Color("ec8a6e"))
	_composure_fill.size = Vector2(HUD_COMP_W * _composure / GameState.max_composure(), 8)

	_hud_icon("icon_clock", Vector2(380, top + 13))
	_hud_text("PERIOD", Vector2(402, top + 3), UiText.HUD)
	_clock_label = _hud_text("2:00", Vector2(402, top + 17), UiText.HUD_VALUE)
	_hud_text("DISRUPTIONS", Vector2(472, top + 3), UiText.HUD)
	_disrupt_label = _hud_text("0", Vector2(472, top + 17), UiText.HUD_VALUE, Color("e0a93a"))
	_hud_text(tr("HEARD"), Vector2(572, top + 3), UiText.HUD)
	_equity_label = _hud_text("0/0", Vector2(572, top + 17), UiText.HUD_VALUE, Color("6fa8e8"))

	_objective_toggle = Button.new()
	_objective_toggle.position = Vector2(648, top + 6)
	_objective_toggle.size = Vector2(164, 30)
	_objective_toggle.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(_objective_toggle, 14 + GameState.ui_font_delta())
	_objective_toggle.z_index = 60
	_objective_toggle.pressed.connect(func(): _set_objectives_open(not _objectives_open, false))
	_hud_node().add_child(_objective_toggle)

	# Expanded objectives: over the left wall columns, clear of every seat.
	_objective_plate = _hud_plate(Vector2(4, ROOM_ORIGIN.y - 30), Vector2(ROOM_ORIGIN.x + 3 * TILE, 300))
	_objective_label = _hud_text("", Vector2(18, ROOM_ORIGIN.y - 18), UiText.HUD, Color("f2eedd"))
	_objective_label.size = Vector2(ROOM_ORIGIN.x + 3 * TILE - 28, 276)
	_objective_label.clip_text = true
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_objectives_open(false, false)

	var vee_tex := Art.tex("res://assets/portraits/coach_vee_neutral.png")
	if vee_tex != null:
		var vee := TextureRect.new()
		vee.texture = vee_tex
		vee.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vee.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vee.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vee.position = Vector2(12, bot + 5)
		vee.size = Vector2(32, 32)
		vee.z_index = 60
		_hud_node().add_child(vee)
	_interact_label = _hud_text("", Vector2(52, bot + 3), UiText.HUD, Color("ffd34e"))
	_interact_label.size = Vector2(620, 18)
	_interact_label.clip_text = true
	var keys := _hud_text("Arrows walk | Z talk | O goals | Esc leave", Vector2(DESIGN.x - 290, bot + 3), UiText.HUD, Color("b9b7a8"))
	keys.size = Vector2(276, 18)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coach_hint = _hud_text("", Vector2(52, bot + 21), UiText.BODY_SMALL_ON_BOARD, Color("a8d8b0"))
	_coach_hint.size = Vector2(DESIGN.x - 70, 18)
	_coach_hint.clip_text = true

func _hud_icon(name: String, pos: Vector2) -> void:
	var t := Art.tex(V2 + "ui/%s.png" % name)
	if t == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.position = pos
	r.size = Vector2(16, 16)
	r.z_index = 60
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_node().add_child(r)

func _hud_text(t: String, pos: Vector2, variation: StringName, color: Variant = null) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style(l, variation, color)
	l.z_index = 60
	_hud_node().add_child(l)
	return l

func _hud_bar_bg(pos: Vector2, size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.position = pos
	bg.size = size
	bg.color = Color("14131c")
	bg.z_index = 60
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_node().add_child(bg)

func _hud_fill(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var f := ColorRect.new()
	f.position = pos
	f.size = size
	f.color = color
	f.z_index = 61
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_node().add_child(f)
	return f

## Collapsed: one line in the top band. Open: list on the left wall. `toast` = auto-open
## for a few seconds (an objective changed), then close again unless the player opened it.
func _set_objectives_open(open: bool, toast: bool) -> void:
	_objectives_open = open
	_objective_toast_left = OBJ_TOAST_SECONDS if (open and toast) else 0.0
	if _objective_plate != null:
		_objective_plate.visible = open
	if _objective_label != null:
		_objective_label.visible = open
	_refresh_objective_toggle()

func _refresh_objective_toggle() -> void:
	if _objective_toggle != null:
		_objective_toggle.text = "Objectives %d/%d  [O] %s" % [_last_objectives_met, _objectives.size(), tr("hide") if _objectives_open else tr("show")]

func _process(delta: float) -> void:
	if _player == null:
		return
	if input_locked and not _lesson_over and _interrupt_clock_left > 0.0:
		# B4: the class does not wait while you decide; the clock runs a little.
		var dt := minf(delta, _interrupt_clock_left)
		_interrupt_clock_left -= dt
		_period_left = maxf(0.0, _period_left - dt)
		if _clock_label != null:
			_clock_label.text = "%d:%02d" % [int(_period_left) / 60, int(_period_left) % 60]
	if _lesson_over or input_locked:
		return

	# Period clock.
	_period_left -= delta
	if _clock_label != null:
		_clock_label.text = "%d:%02d" % [int(_period_left) / 60, int(_period_left) % 60]
	if _period_left <= 0.0:
		_end_lesson()
		return

	# Interrupt events the teacher must triage.
	_next_interrupt -= delta
	if _next_interrupt <= 0.0:
		_trigger_interrupt()
		return

	if not _npcs.is_empty():
		var ptile: Vector2i = _player.current_tile()
		var facing_up: bool = _player.facing == Vector2i(0, -1)   # writing at the board, back to class
		if facing_up:
			_back_secs += delta

		var total := 0.0
		var worst := 0.0
		var worst_name := ""
		for st in _npcs.keys():
			var info: Dictionary = _npcs[st]
			var ot: float = info.get("offtask", 0.0)
			var dist: int = abs(ptile.x - st.x) + abs(ptile.y - st.y)
			if dist <= PROX_TILES:
				ot -= OFFTASK_RECOVER * delta            # proximity control
			else:
				var rise := _offtask_rise
				if facing_up:
					rise *= OFFTASK_AWAY_MULT            # not withit
				else:
					ot -= WITHIT_RECOVER * delta         # scanning the class
				ot += rise * delta
			ot = clampf(ot, 0.0, 100.0)
			if ot >= 100.0:
				_disruptions += 1
				if _disrupt_label != null:
					_disrupt_label.text = str(_disruptions)
				ot = 65.0                                # brief cooldown after a flare-up
			info["offtask"] = ot
			_room_feedback(info, ot, dist <= PROX_TILES, facing_up and st.y > ptile.y and dist > PROX_TILES)
			var fill: ColorRect = info.get("fill", null)
			if fill != null:
				fill.size = Vector2(24.0 * ot / 100.0, 4)
				fill.color = Color(0.3, 0.8, 0.4).lerp(Color(0.9, 0.3, 0.25), ot / 100.0)
			total += ot
			if ot > worst:
				worst = ot
				worst_name = info.get("display_name", "")

		if _attention_fill != null:
			var attention := 100.0 - total / float(_npcs.size())
			_attention_fill.size = Vector2(HUD_ATT_W * attention / 100.0, 8)
			_attention_fill.color = Color("ec8a6e").lerp(Color("5fbf6a"), attention / 100.0)

		if _equity_label != null:
			_equity_label.text = "%d/%d" % [_engaged_count(), _npcs.size()]

		# Room cue shares the bottom line with the talk prompt (talk prompt wins when facing a student).
		# B5: at Light/Off support the HUD stops doing the noticing; read the postures.
		if worst >= 45.0 and not _room_names_shown():
			_room_cue = tr("Watch how they're sitting. That tells you who's drifting.")
		elif worst >= 70.0:
			_room_cue = "%s is drifting (%d%%). Get over there now." % [worst_name, int(worst)]
		elif worst >= 45.0:
			_room_cue = "%s is starting to drift (%d%%)." % [worst_name, int(worst)]
		else:
			_room_cue = "Room's settled. Green bar is focused, red is drifting."

		var faced: Vector2i = ptile + _player.facing
		for st2 in _npcs.keys():
			_set_student_state(_npcs[st2], st2 == faced)
		if _interact_label != null:
			var npc: Dictionary = npc_at(faced)
			if not npc.is_empty():
				_interact_label.text = "Press Z to talk to %s" % npc.get("display_name", "student")
			else:
				_interact_label.text = _room_cue

		if _objective_label != null:
			var attention_now := 100.0 - total / float(_npcs.size())
			_objective_label.text = _objectives_status(attention_now)
			var met := _objectives_met_count(attention_now)
			if met != _last_objectives_met:
				var first := _last_objectives_met < 0
				_last_objectives_met = met
				if not first and not _objectives_open:
					_set_objectives_open(true, true)
				_refresh_objective_toggle()
			if _objective_toast_left > 0.0:
				_objective_toast_left -= delta
				if _objective_toast_left <= 0.0:
					_set_objectives_open(false, false)

		if _coach_hint != null:
			if facing_up and worst > 30.0:
				_coach_hint.text = "Coach Vee: turn around. They drift when your back is to them."
			elif worst >= 60.0 and not _room_names_shown():
				_coach_hint.text = tr("Coach Vee: someone's drifting. Look around, then walk over.")
			elif worst >= 60.0:
				_coach_hint.text = "Coach Vee: %s is drifting. Go stand near them." % worst_name
			elif worst >= 35.0:
				_coach_hint.text = "Coach Vee: getting a bit restless in here. Keep moving."
			else:
				_coach_hint.text = "Coach Vee: they're with you. Keep walking the room."

# --- interrupt events + lesson debrief ---------------------------------------

func _trigger_interrupt(idx: int = -1) -> void:
	Sfx.play("interrupt")
	var ev: Dictionary = INTERRUPTS[idx if idx >= 0 and idx < INTERRUPTS.size() else randi() % INTERRUPTS.size()]
	_interrupt_clock_left = Tuning.INTERRUPT_CLOCK_SECONDS
	if bool(ev.get("ladder", false)):
		_show_ladder_card(ev)
		return
	_show_overlay(str(ev["text"]), ev["options"])

## One neutral chip colour for every step: colour must not hint which step is right; the
## outcome in the room teaches that.
const LADDER_CHIP_COLOR := Color("4a5a72")

## B4: a behaviour card on paper. The students involved are named and shown (and look
## restless in the room); options come in a shuffled order, each tagged with its ladder
## step, so the vocabulary is taught without the order giving the answer away.
func _show_ladder_card(ev: Dictionary) -> void:
	input_locked = true
	_overlay = Control.new()
	_overlay.position = -ROOM_ORIGIN
	_overlay.size = DESIGN
	_overlay.z_index = 100
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.size = DESIGN
	dim.color = Color(0, 0, 0, 0.45)
	_overlay.add_child(dim)
	var who: Array = _ladder_pair() if bool(ev.get("pair", false)) else []
	for st in who:
		_npcs[st]["offtask"] = maxf(float(_npcs[st].get("offtask", 0.0)), 72.0)
		_set_student_state(_npcs[st], false)
	_overlay.set_meta("who_names", who.map(func(t): return str(_npcs[t].get("display_name", ""))))
	var lowest := lowest_working_tier(ev["options"])
	var opts: Array = []
	for o in ev["options"]:
		var oo: Dictionary = (o as Dictionary).duplicate()
		oo["_lowest_working"] = lowest
		oo["_who"] = who
		opts.append(oo)
	opts.shuffle()
	var pw := 640.0
	var ph := 96.0 + (64.0 if not who.is_empty() else 0.0) + opts.size() * 46.0 + 16.0
	var card := UiKit.panel("paper")
	card.position = Vector2((DESIGN.x - pw) / 2.0, (DESIGN.y - ph) / 2.0)
	card.size = Vector2(pw, ph)
	_overlay.add_child(card)
	var ink := Color("14131c")
	var head := Label.new()
	head.text = str(ev["text"])
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(pw - 48, 0)   # wrap width fixed before the height resolves
	head.add_theme_font_size_override("font_size", UiText.fs(18))
	head.add_theme_color_override("font_color", ink)
	card.add_child(head)
	head.position = Vector2(24, 18)
	head.size = Vector2(pw - 48, 48)
	var y := 72.0
	if not who.is_empty():
		var x := 24.0
		for st in who:
			var info: Dictionary = _npcs[st]
			var pid := str(info.get("persona_id", ""))
			var pt := TextureRect.new()
			pt.texture = Art.tex(UiKit.portrait_path("res://assets/portraits/%s_neutral.png" % pid))
			pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card.add_child(pt)
			pt.position = Vector2(x, y)
			pt.size = Vector2(52, 52)
			var nm := Label.new()
			nm.text = str(info.get("display_name", ""))
			nm.add_theme_font_size_override("font_size", UiText.fs(14))
			nm.add_theme_color_override("font_color", ink)
			card.add_child(nm)
			nm.position = Vector2(x + 58, y + 16)
			x += 180.0
		y += 64.0
	var first: Button = null
	for opt in opts:
		var tier := int(opt.get("tier", 1))
		var b := Button.new()
		b.text = tr(str(opt.get("label", ""))).format({"a": str(_npcs[who[0]].get("display_name", "")) if not who.is_empty() else tr("you")})
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st2 in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBoxTexture = (UiKit.board_button(st2) if st2 != "focus" else UiKit.button("focus")).duplicate()
			sb.content_margin_left = 150
			b.add_theme_stylebox_override(st2, sb)
		b.add_theme_font_size_override("font_size", UiText.fs(14))
		b.pressed.connect(_on_ladder_choice.bind(opt))
		card.add_child(b)
		b.position = Vector2(24, y)
		b.size = Vector2(pw - 48, 40)
		var chip := Label.new()
		chip.text = tr(str(Tuning.LADDER_STEPS[tier - 1]))
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var csb := StyleBoxFlat.new()
		csb.bg_color = LADDER_CHIP_COLOR
		csb.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("normal", csb)
		chip.add_theme_font_size_override("font_size", UiText.fs(12))
		chip.add_theme_color_override("font_color", Color.WHITE)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip)
		chip.position = Vector2(8, 8)
		chip.size = Vector2(132, 24)
		if first == null:
			first = b
		y += 46.0
	Juice.pop_in(card)
	if first != null:
		first.grab_focus()

## Two seated students next to each other (the closest pair), for pair cards.
func _ladder_pair() -> Array:
	var keys: Array = _npcs.keys()
	if keys.size() < 2:
		return keys
	keys.shuffle()
	var a: Vector2i = keys[0]
	var best: Vector2i = keys[1]
	for k in keys.slice(1):
		if absi(k.x - a.x) + absi(k.y - a.y) < absi(best.x - a.x) + absi(best.y - a.y):
			best = k
	return [a, best]

## The choice plays out on the students involved, not only in the numbers.
func _on_ladder_choice(opt: Dictionary) -> void:
	var works := bool(opt.get("works", true))
	for st in opt.get("_who", []):
		if not _npcs.has(st):
			continue
		var info: Dictionary = _npcs[st]
		info["offtask"] = maxf(0.0, float(info.get("offtask", 0.0)) - 55.0) if works else maxf(float(info.get("offtask", 0.0)), 88.0)
		_set_student_state(info, false)
		var fill: ColorRect = info.get("fill", null)
		if fill != null:
			Juice.float_text(info["node"], tr("settled") if works else tr("still at it"), fill.position + Vector2(-8, -18),
				Color("7fe08a") if works else Color("ff8a70"), UiText.fs(12))
	_resolve_interrupt(opt)

## B4: the lowest ladder step that works for this card (0 if none is marked).
static func lowest_working_tier(options: Array) -> int:
	var best := 0
	for o in options:
		if bool(o.get("works", false)) and (best == 0 or int(o.get("tier", 9)) < best):
			best = int(o.get("tier", 9))
	return best

func _apply_noise(amount: float) -> void:
	for st in _npcs.keys():
		var info: Dictionary = _npcs[st]
		info["offtask"] = clampf(info.get("offtask", 0.0) + amount, 0.0, 100.0)

func _resolve_interrupt(opt: Dictionary) -> void:
	_interrupt_clock_left = 0.0
	var lowest := int(opt.get("_lowest_working", 0))
	var ladder_bonus := lowest > 0 and int(opt.get("tier", 0)) == lowest
	var dcomp := float(opt.get("dcomp", 0.0)) + (Tuning.LADDER_BONUS_COMPOSURE if ladder_bonus else 0.0)
	_composure = clampf(_composure + dcomp, 0.0, GameState.max_composure())
	_apply_noise(float(opt.get("dnoise", 0.0)))
	_disruptions += int(opt.get("ddis", 0))
	if _disrupt_label != null:
		_disrupt_label.text = str(_disruptions)
	if _composure_fill != null:
		_composure_fill.size = Vector2(HUD_COMP_W * _composure / GameState.max_composure(), 8)
	if _coach_hint != null:
		_coach_hint.text = "Coach Vee: " + str(opt.get("coach", ""))
	var ptile: Vector2i = _player.current_tile() if _player != null else Vector2i.ZERO
	Telemetry.log_event({
		"event": "interrupt_resolved", "scenario_id": str(Game.current_scenario_id),
		"choice": str(opt.get("label", "")), "dcomp": float(opt.get("dcomp", 0.0)),
		"dnoise": float(opt.get("dnoise", 0.0)), "ddis": int(opt.get("ddis", 0)),
		"composure": _composure, "disruptions": _disruptions,
		"player_tile": {"x": ptile.x, "y": ptile.y},
		"tier": int(opt.get("tier", 0)), "lowest_working_tier": lowest, "ladder_bonus": ladder_bonus,
		"students": (opt.get("_who", []) as Array).map(func(t): return str(_npcs[t].get("persona_id", "")) if _npcs.has(t) else ""),
		"works": bool(opt.get("works", true)),
	})
	_close_overlay()
	_next_interrupt = randf_range(INTERRUPT_MIN, INTERRUPT_MAX)
	if _composure <= 0.0:
		_end_lesson()

func _end_lesson() -> void:
	if _lesson_over:
		return
	_lesson_over = true
	var total := 0.0
	for st in _npcs.keys():
		total += _npcs[st].get("offtask", 0.0)
	var attention := 100.0 - total / float(max(1, _npcs.size()))
	var objective_tags: Array = []
	var stars := 0
	for o in _objectives:
		var ok := _objective_met(o, attention)
		if ok:
			stars += 1
		objective_tags.append("%s %s" % ["OK" if ok else "MISS", _objective_short_label(o)])
	var reward_info := {}
	var retry_info := _settle_retry_focus(attention)
	if stars == _objectives.size() and stars > 0 and _badge != "":
		var reward := GameState.award_badge(_badge)
		reward_info = reward
		Sfx.play("badge")
		var moves: Array = Game.lesson.get("moves", [])
		GameState.record_leaderboard({
			"scenario_id": str(Game.current_scenario_id),
			"title": _scenario_title,
			"mode": "Classroom",
			"badge": _badge,
			"score": stars * 80 + int(round(attention)) + int(round(_composure)) + _engaged_count() * 10 - _disruptions * 12,
			"detail": "Objectives %d/%d  Attention %d%%  Engaged %d/%d" % [stars, _objectives.size(), int(attention), _engaged_count(), _npcs.size()],
			"level_up": bool(reward.get("level_up", false)),
			"trace": Game.evidence_trace_from_moves(moves),
			"trace_steps": Game.evidence_trace_steps_from_moves(moves),
		})
	_pending_card = _card_data(attention, stars, reward_info)
	if bool(retry_info.get("met", false)):
		var rw: Dictionary = _pending_card["rewards"]
		rw["extra"] = [tr("+%d XP, retry goal met") % Tuning.RETRY_XP_BONUS]
		if bool(retry_info.get("level_up", false)):
			rw["level_up"] = true
			rw["level_after"] = int(retry_info.get("level_after", GameState.teacher_level))
	Telemetry.log_event({
		"event": "classroom_resolve", "scenario_id": str(Game.current_scenario_id),
		"title": _scenario_title, "attempt": _attempt,
		"stars": stars, "objectives": _objectives.size(), "objective_tags": objective_tags,
		"attention": attention, "composure": _composure, "disruptions": _disruptions,
		"engaged": _engaged_count(), "students": _npcs.size(),
		"won": stars == _objectives.size() and stars > 0,
	})
	Telemetry.upload_competency()
	Telemetry.flush()
	_lesson_won = stars == _objectives.size() and stars > 0
	var reflection_options := _reflection_options(attention)
	_last_moves = []
	var i := 0
	for m in Game.lesson.get("moves", []):
		i += 1
		var mm: Dictionary = (m as Dictionary).duplicate()
		mm["turn"] = i
		_last_moves.append(mm)
	Game.clear_lesson()
	# Reflection-on-action FIRST (Schon): the player names what they noticed before seeing a score.
	_show_overlay("REFLECT 1/2\n\nBefore you see the score. What's sticking with you from that period?", reflection_options)

func _on_reflect(opt: Dictionary) -> void:
	GameState.log_reflection({
		"scenario": Game.current_scenario_id,
		"prompt": "what_stays_with_you",
		"choice": str(opt.get("_reflect", "")),
	})
	Telemetry.log_event({
		"event": "reflection", "scenario_id": str(Game.current_scenario_id),
		"prompt": "what_stays_with_you", "choice": str(opt.get("_reflect", "")),
	})
	_close_overlay()
	_show_results_card()

## REVIEW: the shared results card (grade, verdict, three parts with causes, rewards,
## pivotal moments, one next target) on the same overlay layer as the reflection step.
## B8: move the objective with `metric` to the front, flagged as the retry focus.
static func apply_retry_focus(objs: Array, metric: String) -> Array:
	var out: Array = []
	var focus := {}
	for o in objs:
		if focus.is_empty() and str(o.get("metric", "")) == metric:
			focus = (o as Dictionary).duplicate()
			focus["retry"] = true
		else:
			out.append(o)
	if not focus.is_empty():
		out.push_front(focus)
	return out

## B8: pay the retry-focus bonus if it was met, then carry the next target forward (the
## first missed objective, the same one the card names under "Next time").
func _settle_retry_focus(attention: float) -> Dictionary:
	var info := {}
	for o in _objectives:
		if bool(o.get("retry", false)):
			var met := _objective_met(o, attention)
			info = {"met": met, "metric": str(o.get("metric", ""))}
			if met:
				info.merge(GameState.add_teacher_xp(Tuning.RETRY_XP_BONUS, "retry_focus:%s" % info["metric"]))
			Telemetry.log_event({"event": "retry_focus", "scenario_id": str(Game.current_scenario_id),
				"metric": info["metric"], "met": met, "xp": Tuning.RETRY_XP_BONUS if met else 0})
	Game.retry_focus = {}
	for o in _objectives:
		if not _objective_met(o, attention):
			Game.retry_focus = {"scenario_id": str(Game.current_scenario_id), "metric": str(o.get("metric", ""))}
			break
	return info

func _show_results_card() -> void:
	input_locked = true
	# Own canvas layer: the card is taller than the room and must sit over the HUD bands.
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_overlay = Control.new()
	_overlay.size = DESIGN
	cl.add_child(_overlay)
	_overlay.tree_exited.connect(cl.queue_free)
	UiText.keep_centered(_overlay)
	var data := _pending_card.duplicate()
	data["buttons"] = [
		{"label": "Pick another mission", "cb": _go_hub},
		{"label": "Replay this lesson", "cb": _restart_lesson},
		{"label": "Talk it through", "cb": _open_coach, "primary": true},
	]
	ResultsCard.build(_overlay, data)

## Teaching-language next step for each objective metric.
const NEXT_FOR := {
	"attention_min": "Keep walking. Stand near whoever's drifting, and face the room when you talk.",
	"disruptions_max": "Try the small stuff first, a look or walking closer, before you stop the class.",
	"composure_min": "Correct quietly, one on one. Public blowups wear you down.",
	"engaged_min": "Get everyone explaining, including the ones who never call out. Try Elicit or Revoice.",
	"waittime_min": "After you ask, wait three seconds before your next move.",
	"connect_min": "Find something a student cares about and tie it to the lesson. Use Connect twice.",
}

func _card_data(attention: float, stars: int, reward: Dictionary) -> Dictionary:
	var n := maxi(1, _objectives.size())
	var missed: Array = []
	for o in _objectives:
		if not _objective_met(o, attention):
			missed.append(o)
	var miss_names: Array = missed.map(func(o): return tr(_objective_short_label(o)))
	var reached := _engaged_count()
	var back := int(round(_back_secs))
	var parts := [
		{"label": "Objectives", "frac": float(stars) / n, "value": "%d/%d" % [stars, _objectives.size()],
			"cause": tr("all cleared") if missed.is_empty() else tr("missed: ") + ", ".join(miss_names)},
		{"label": "Attention", "frac": attention / 100.0, "value": "%d%%" % int(attention),
			"cause": ("%ds with your back to the room" % back) if back >= 10 else "you kept moving and kept facing them"},
		{"label": "Reach", "frac": float(reached) / maxi(1, _npcs.size()), "value": "%d/%d" % [reached, _npcs.size()],
			"cause": tr("you heard %d of %d students explain their thinking") % [reached, _npcs.size()]},
	]
	var score := stars * 80 + int(round(attention)) + int(round(_composure)) + reached * 10 - _disruptions * 12
	var best := _objectives.size() * 80 + 200 + _npcs.size() * 10
	var rank := ResultsCard.classroom_rank(float(maxi(0, score)) / maxi(1, best), stars, _objectives.size())
	var weak := ResultsCard.weakest(parts)
	var title := "%s  ·  period review" % _scenario_title
	if _attempt > 1:
		title += "  ·  replay #%d (they drift faster each time)" % _attempt
	var next := "Want more? Hear from every student and keep attention over 90%."
	if not missed.is_empty():
		next = tr(str(NEXT_FOR.get(str(missed[0].get("metric", "")), "Go again with this one in mind."))) + " " + tr("It goes first on your list next time (+%d XP).") % Tuning.RETRY_XP_BONUS
	return {
		"title": title,
		"rank": rank,
		"verdict": ResultsCard.verdict(rank, str(parts[weak]["label"])),
		"parts": parts,
		"rewards": {"badge": _badge if bool(reward.get("badge_new", false)) else "",
			"caption": "First clear" if bool(reward.get("badge_new", false)) else "Mission badge",
			"level_up": bool(reward.get("level_up", false)),
			"level_after": int(reward.get("level_after", 0)), "items": reward.get("items_awarded", {}),
			"none": (tr("You already have the %s badge.") % tr(_badge.capitalize())) if not reward.is_empty()
				else (tr("Clear every objective to earn the %s badge.") % tr(_badge.capitalize()) if _badge != "" else "This mission has no badge.")},
		"moments": _classroom_moments(back),
		"next": next,
	}

## A4 for the classroom: first move that landed, first that missed, and the room itself.
func _classroom_moments(back: int) -> Array:
	var out: Array = []
	var moves: Array = Game.lesson.get("moves", [])
	var hit := -1
	var off := -1
	for i in range(moves.size()):
		if hit < 0 and bool(moves[i].get("targets", false)):
			hit = i
		if off < 0 and not bool(moves[i].get("targets", false)):
			off = i
	if moves.is_empty():
		out.append({"kind": "wrong", "text": "No conferences  ->  you never heard anyone's thinking  ->  get at least one to explain."})
	if hit >= 0:
		out.append({"kind": "right", "text": "Move %d  %s  ->  it was what they needed  ->  they got further." % [hit + 1, tr(str(moves[hit].get("tag", "")).capitalize())]})
	if off >= 0:
		var why := "you didn't give them three seconds first" if not bool(moves[off].get("wait_ok", false)) else "it wasn't what they needed yet"
		out.append({"kind": "early" if not bool(moves[off].get("wait_ok", false)) else "wrong",
			"text": "Move %d  %s  ->  didn't land  ->  %s." % [off + 1, tr(str(moves[off].get("tag", "")).capitalize()), tr(why)]})
	if back >= 10:
		out.append({"kind": "early", "text": "%ds facing the board  ->  they drifted twice as fast  ->  look back as you write." % back})
	elif _disruptions > 0:
		out.append({"kind": "wrong", "text": (tr("%d flare-up  ->  someone who'd drifted blew up  ->  get there before the bar goes red.") if _disruptions == 1 else tr("%d flare-ups  ->  someone who'd drifted blew up  ->  get there before the bar goes red.")) % _disruptions})
	return out

func _reflection_options(attention: float) -> Array:
	var opts: Array = []
	for o in _objectives:
		if _objective_met(o, attention):
			continue
		match str(o.get("metric", "")):
			"engaged_min":
				opts.append({"label": "Whose thinking I didn't hear", "_reflect": "unreached"})
			"attention_min":
				opts.append({"label": "When the room drifted", "_reflect": "attention"})
			"waittime_min":
				opts.append({"label": "Where I didn't wait long enough", "_reflect": "wait_time"})
			"connect_min":
				opts.append({"label": "A kid's interest I could have used", "_reflect": "asset"})
			"disruptions_max":
				opts.append({"label": "A disruption I'd handle smaller", "_reflect": "disruption"})
			"composure_min":
				opts.append({"label": "A moment I'd see differently now", "_reflect": "reframe"})
	if opts.is_empty():
		opts = [
			{"label": "A move that worked", "_reflect": "worked"},
			{"label": "A kid's interest I used", "_reflect": "asset"},
			{"label": "Something to push for next time", "_reflect": "stretch"},
		]
	while opts.size() < 3:
		opts.append({"label": "A moment I'd replay", "_reflect": "replay_moment"})
	return opts.slice(0, 3)

## B6: students whose thinking was heard (see Game.note_voiced), not merely visited.
func _engaged_count() -> int:
	return Game.voiced_count()

func _waittime_count() -> int:
	var c := 0
	for m in Game.lesson.get("moves", []):
		if m.get("wait_ok", false):
			c += 1
	return c

func _connect_count() -> int:
	var c := 0
	for m in Game.lesson.get("moves", []):
		if str(m.get("tag", "")) == "connect":
			c += 1
	return c

func _objective_met(o: Dictionary, attention: float) -> bool:
	var metric := str(o.get("metric", ""))
	var target := float(o.get("target", 0))
	match metric:
		"attention_min":
			return attention >= target
		"disruptions_max":
			return _disruptions <= int(target)
		"composure_min":
			return _composure >= target
		"engaged_min":
			return _engaged_count() >= int(target)
		"waittime_min":
			return _waittime_count() >= int(target)
		"connect_min":
			return _connect_count() >= int(target)
	return false

## A2: the teaching skill behind each objective metric.
const OBJ_SKILL := {
	"attention_min": "Withitness",
	"disruptions_max": "Least-intrusive management",
	"composure_min": "Composure",
	"engaged_min": "Equity of voice",
	"waittime_min": "Wait time",
	"connect_min": "Funds of knowledge",
}

func _objectives_status(attention: float) -> String:
	if _objectives.is_empty():
		return ""
	var lines := ["Objectives  %d/%d" % [_objectives_met_count(attention), _objectives.size()]]
	for o in _objectives:
		var metric := str(o.get("metric", ""))
		var target := int(o.get("target", 0))
		var current := 0
		match metric:
			"attention_min":
				current = int(attention)
			"disruptions_max":
				current = _disruptions
			"composure_min":
				current = int(_composure)
			"engaged_min":
				current = _engaged_count()
			"waittime_min":
				current = _waittime_count()
			"connect_min":
				current = _connect_count()
		var ok := _objective_met(o, attention)
		var mark := "OK" if ok else "  "
		# A2: each objective names the teaching skill it practises, then the rule and count.
		var focus_tag := tr("RETRY FOCUS  ") if bool(o.get("retry", false)) else ""
		lines.append(focus_tag + "[%s] %s  %d/%d\n      %s" % [mark, str(OBJ_SKILL.get(metric, "Practice")), current, target, str(o.get("label", metric))])
	return "\n".join(lines)

func _objectives_met_count(attention: float) -> int:
	var n := 0
	for o in _objectives:
		if _objective_met(o, attention):
			n += 1
	return n

func _objective_short_label(o: Dictionary) -> String:
	match str(o.get("metric", "")):
		"attention_min":
			return "on-task"
		"disruptions_max":
			return "disruptions"
		"composure_min":
			return "composure"
		"engaged_min":
			return "voices heard"
		"waittime_min":
			return "wait-time"
		"connect_min":
			return "asset connect"
	return str(o.get("id", "objective"))

func _show_overlay(text: String, options: Array) -> void:
	input_locked = true
	_overlay = Control.new()
	_overlay.position = -ROOM_ORIGIN
	_overlay.size = DESIGN
	_overlay.z_index = 100
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.size = _overlay.size
	dim.color = Color(0, 0, 0, 0.6)
	_overlay.add_child(dim)

	var btns: Array = options
	if btns.is_empty():
		btns = [{"label": "Continue", "_action": "hub"}]
	# Size the panel to its text: a one-line interrupt gets a compact card, a long
	# debrief gets the full height. Buttons stay bottom-anchored below the text.
	var pw := 660.0
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiText.style(lbl, UiText.BODY, Color(0.97, 0.96, 0.9))
	lbl.size = Vector2(pw - 44, 10)
	_overlay.add_child(lbl)
	var text_h := float(lbl.get_line_count()) * float(lbl.get_line_height()) + 4.0
	var buttons_h := float(btns.size()) * 40.0
	var max_h := DESIGN.y - 40.0
	var ph := clampf(18.0 + text_h + 24.0 + buttons_h + 8.0, 180.0, max_h)
	var px := (_overlay.size.x - pw) / 2.0
	var py := (_overlay.size.y - ph) / 2.0
	var panel := Panel.new()   # themed: rounded, bordered, drop shadow
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	_overlay.add_child(panel)
	_overlay.move_child(lbl, -1)
	var by := py + ph - buttons_h - 8.0
	lbl.position = Vector2(px + 22, py + 18)
	lbl.size = Vector2(pw - 44, by - py - 30)
	lbl.clip_text = true
	Juice.pop_in(panel)

	for i in range(btns.size()):
		var opt: Dictionary = btns[i]
		var b := Button.new()
		b.text = str(opt.get("label", "OK"))
		b.position = Vector2(px + 22, by + i * 40.0)
		b.size = Vector2(pw - 44, 34)
		b.add_theme_font_size_override("font_size", UiText.fs(14))
		if opt.has("_reflect"):
			b.pressed.connect(_on_reflect.bind(opt))
		elif opt.has("_action"):
			var act := str(opt["_action"])
			if act == "hub":
				b.pressed.connect(_go_hub)
			elif act == "close":
				b.pressed.connect(_close_overlay)
			elif act == "coach":
				b.pressed.connect(_open_coach)
			else:
				b.pressed.connect(_restart_lesson)
		else:
			b.pressed.connect(_resolve_interrupt.bind(opt))
		_overlay.add_child(b)
		if i == 0:
			b.grab_focus()

func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	input_locked = false

func _open_coach() -> void:
	_close_overlay()
	CoachCard.open(self, _last_moves, str(Game.current_scenario_id), _restart_lesson, _go_hub)

func _restart_lesson() -> void:
	Game.clear_lesson()   # fresh period
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _go_hub() -> void:
	Game.clear_lesson()
	if _lesson_over:
		Narrative.go_hub_with_outro(_scenario_cfg, _lesson_won)
	else:
		SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

## Tap or click a floor tile to walk there; tap a student to walk up and talk to them.
## Uses the room's own transform, so it stays correct when the room is centred.
func _unhandled_input(event: InputEvent) -> void:
	if input_locked or _lesson_over or _player == null:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventFromWindow).position
	var tile := Vector2i(floori(local.x / TILE), floori(local.y / TILE))
	if tile.x < 0 or tile.y < 0 or tile.x >= COLS or tile.y >= ROWS:
		return
	var from: Vector2i = _player.current_tile()
	if not npc_at(tile).is_empty():
		# Walk to the nearest free side of the student, then face them and talk.
		var best: Array = []
		var face := Vector2i.ZERO
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var stand: Vector2i = tile + d
			var p := InputFeel.grid_path(from, stand, is_walkable)
			if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
				best = p
				face = -d
		if not best.is_empty():
			_player.walk_path(best, face, true)
			get_viewport().set_input_as_handled()
		return
	var path := InputFeel.grid_path(from, tile, is_walkable)
	if not path.is_empty():
		_player.walk_path(path)
		get_viewport().set_input_as_handled()

## Esc / Backspace asks before leaving: one stray key press should not end a lesson.
## While the leave prompt is open, Esc again means "stay".
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_O and not input_locked and not _lesson_over:
		_set_objectives_open(not _objectives_open, false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_BACKSPACE:
		return
	if _overlay != null and is_instance_valid(_overlay) and _overlay.has_meta("leave_prompt"):
		_close_overlay()
		get_viewport().set_input_as_handled()
		return
	if input_locked or _lesson_over:
		return
	_confirm_leave()
	get_viewport().set_input_as_handled()

func _confirm_leave() -> void:
	_show_overlay("Leave this lesson?
The period ends now and this try won't count.", [
		{"label": "Stay in the lesson", "_action": "close"},
		{"label": "Back to the mission hub", "_action": "hub"},
	])
	if _overlay != null:
		_overlay.set_meta("leave_prompt", true)

# --- queries used by Player --------------------------------------------------

func is_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= COLS or tile.y >= ROWS:
		return false
	if _walls.has(tile):
		return false
	if _npcs.has(tile):
		return false
	return true

func npc_at(tile: Vector2i) -> Dictionary:
	return _npcs.get(tile, {})

func start_encounter(npc: Dictionary) -> void:
	if npc.is_empty():
		return
	_save_lesson_state()   # so the period/composure/off-task continue after the encounter
	# Group work is monitored at the POD level (a distinct mechanic), not 1:1.
	if _format == "group_work":
		var pod := _build_pod(npc)
		SceneRouter.change_scene("res://scenes/encounter/GroupCheckIn.tscn", {
			"members": pod,
			"shared_concept": _scenario_title,
			"collective_status": _group_collective_status(pod),
			"collective_reasoning": _group_collective_reasoning(pod),
			"scenario_context": _group_scenario_context(pod),
		})
		return
	SceneRouter.change_scene("res://scenes/encounter/Encounter.tscn", {
		"persona_id": npc.get("persona_id", ""),
		"display_name": npc.get("display_name", "Student"),
	})

## The tapped student + the two nearest tablemates = the pod for a group check-in.
func _build_pod(npc: Dictionary) -> Array:
	var tapped_pid := str(npc.get("persona_id", ""))
	var entries: Array = []
	var tapped_tile := Vector2i.ZERO
	for t in _npcs.keys():
		var e: Dictionary = _npcs[t]
		entries.append({"tile": t, "pid": e.get("persona_id", ""), "name": e.get("display_name", "Student")})
		if str(e.get("persona_id", "")) == tapped_pid:
			tapped_tile = t
	entries.sort_custom(func(a, b): return tapped_tile.distance_squared_to(a["tile"]) < tapped_tile.distance_squared_to(b["tile"]))
	var pod: Array = []
	for e in entries.slice(0, 3):
		pod.append({"persona_id": e["pid"], "name": e["name"], "talkativeness": _persona_talk(str(e["pid"]))})
	return pod

func _group_collective_status(pod: Array) -> String:
	var format_label := str(_scenario_cfg.get("format", "group_work"))
	if format_label == "group_work":
		return "shared_misconception_or_uneven_participation"
	return "student_thinking_sample"

func _group_collective_reasoning(pod: Array) -> String:
	if str(_scenario_cfg.get("collective_reasoning", "")) != "":
		return str(_scenario_cfg.get("collective_reasoning", ""))
	var ov: Dictionary = _scenario_cfg.get("persona_overrides", {})
	for member in pod:
		var pid := str(member.get("persona_id", ""))
		var po = ov.get(pid, {})
		if typeof(po) == TYPE_DICTIONARY and str(po.get("opening_line", "")) != "":
			return str(po.get("opening_line", ""))
	if str(_scenario_cfg.get("title", "")) != "":
		return "This pod is working on %s. Nobody has asked how they're thinking yet." % str(_scenario_cfg.get("title", "the task"))
	return "The pod is still figuring it out."

func _group_scenario_context(pod: Array) -> Dictionary:
	var objective_labels: Array = []
	for o in _scenario_cfg.get("objectives", []):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			objective_labels.append(str(o.get("label", "")))
	var pod_targets: Array = []
	var ov: Dictionary = _scenario_cfg.get("persona_overrides", {})
	for member in pod:
		var pid := str(member.get("persona_id", ""))
		var po = ov.get(pid, {})
		if typeof(po) != TYPE_DICTIONARY:
			po = {}
		pod_targets.append({
			"persona_id": pid,
			"name": str(member.get("name", "Student")),
			"target_label": str(po.get("target_label", "")),
			"opening_line": str(po.get("opening_line", "")),
			"win_moves": po.get("win_moves", []),
		})
	return {
		"id": str(_scenario_cfg.get("id", Game.current_scenario_id)),
		"title": str(_scenario_cfg.get("title", _scenario_title)),
		"format": str(_scenario_cfg.get("format", _format)),
		"arrangement": str(_scenario_cfg.get("arrangement", "")),
		"badge": str(_scenario_cfg.get("badge", "")),
		"objectives": objective_labels,
		"collective_reasoning": str(_scenario_cfg.get("collective_reasoning", "")),
		"pod_targets": pod_targets,
	}

func _persona_talk(pid: String) -> float:
	var p := "res://data/persona_library/%s.json" % pid
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				return float(d.get("traits", {}).get("talkativeness", 0.5))
	return 0.5

func _save_lesson_state() -> void:
	if not Game.lesson.get("active", false):
		return
	Game.lesson["period_left"] = _period_left
	Game.lesson["composure"] = _composure
	Game.lesson["disruptions"] = _disruptions
	var ot: Dictionary = {}
	for st in _npcs.keys():
		ot[_npcs[st]["persona_id"]] = _npcs[st].get("offtask", 0.0)
	Game.lesson["offtask"] = ot
