extends Node2D
## Top-down classroom (US-style rows of individual desks; students seated facing the
## viewer with a desk in front). Exposes walkability + NPC lookup for the grid-moving
## Player. See GAME_CONCEPT.md sections 3.1 and 9.1.

const Art = preload("res://scripts/Art.gd")
const Seating = preload("res://scripts/Seating.gd")
# Character-to-environment ratio: TILE 40 with a 24x13 room fills the 960x540 viewport
# while keeping the whole class visible (needed for the management/withitness layer).
# Student 1.35 tiles ~= 54px (~10% of screen height); teacher 1.7 tiles ~= 68px. This is
# ~2.5x larger relative to before (was 32px tiles in a sparse 30x17 room).
const TILE := 40
const COLS := 24
const ROWS := 13
const STUDENT_TILES_TALL := 1.35
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
		"text": "The intercom crackles: \"Please send attendance to the office.\"",
		"options": [
			{"label": "Give the class a 30s task, then handle it", "dcomp": -6.0, "dnoise": 4.0, "ddis": 0,
			 "coach": "Good. A holding task keeps momentum while you deal with the interruption."},
			{"label": "Stop teaching and do it now", "dcomp": -12.0, "dnoise": 16.0, "ddis": 0,
			 "coach": "Dead time. The class drifted while you stopped everything."},
		],
	},
	{
		"text": "A knock at the door: another teacher needs a quick word.",
		"options": [
			{"label": "Set a task, step to the door, stay facing in", "dcomp": -7.0, "dnoise": 6.0, "ddis": 0,
			 "coach": "Withitness preserved. You stayed aware of the room while at the door."},
			{"label": "Step fully into the hall", "dcomp": -8.0, "dnoise": 22.0, "ddis": 1,
			 "coach": "Out of sight, out of control. Off-task spiked while your back was turned."},
		],
	},
	{
		"text": "A student walks in late, mid-lesson.",
		"options": [
			{"label": "Nonverbal nod to an open seat, keep going", "dcomp": -3.0, "dnoise": 5.0, "ddis": 0,
			 "coach": "Least-intrusive. You kept the lesson's momentum."},
			{"label": "Stop and question them in front of everyone", "dcomp": -10.0, "dnoise": 14.0, "ddis": 1,
			 "coach": "Public call-out cost momentum and rapport. Handle it privately later."},
		],
	},
	{
		"text": "Two students start a loud side-conversation.",
		"options": [
			{"label": "Move toward them (proximity), keep talking", "dcomp": -2.0, "dnoise": -10.0, "ddis": 0,
			 "coach": "Proximity control. Quietest effective move."},
			{"label": "Call them out across the room", "dcomp": -9.0, "dnoise": 12.0, "ddis": 1,
			 "coach": "Shouting across the room escalates and pulls everyone off task."},
		],
	},
]

const COLOR_BG := Color(0.10, 0.09, 0.12)
const COLOR_FLOOR := Color(0.46, 0.37, 0.28)
const COLOR_WALL := Color(0.20, 0.22, 0.30)
const COLOR_DESK := Color(0.55, 0.40, 0.22)

# Which seat (col index, row index into SEAT_COLS/SEAT_ROWS) each student occupies.
var _seats: Array = []        # seat tiles for the loaded arrangement
var _objectives: Array = []   # scenario objectives, scored at debrief
var _offtask_rise := OFFTASK_RISE
var _attempt := 1
var _scenario_title := "Lesson"
var _badge := ""

var _walls: Dictionary = {}   # Vector2i -> true
var _npcs: Dictionary = {}    # Vector2i -> { persona_id, display_name, node, offtask, fill }
var _player: Node2D = null

# HUD for the live classroom state.
var _attention_fill: ColorRect = null
var _disrupt_label: Label = null
var _equity_label: Label = null
var _coach_hint: Label = null
var _disruptions := 0

# Lesson ecology state.
var input_locked := false        # Player checks this to freeze movement during overlays
var _composure := 100.0
var _composure_fill: ColorRect = null
var _clock_label: Label = null
var _period_left := PERIOD_SECONDS
var _next_interrupt := 9.0
var _lesson_over := false
var _overlay: Control = null

func _ready() -> void:
	var cfg := _load_scenario(Game.current_scenario_id)
	_scenario_title = str(cfg.get("title", "Lesson"))
	_offtask_rise = float(cfg.get("offtask_rise", OFFTASK_RISE))
	# Resume the in-progress period (returning from an encounter) or start a fresh one.
	if Game.lesson_active(Game.current_scenario_id):
		_period_left = float(Game.lesson.get("period_left", cfg.get("period_seconds", PERIOD_SECONDS)))
		_composure = float(Game.lesson.get("composure", 100.0))
		_disruptions = int(Game.lesson.get("disruptions", 0))
	else:
		Game.start_lesson(Game.current_scenario_id, float(cfg.get("period_seconds", PERIOD_SECONDS)))
		_period_left = float(cfg.get("period_seconds", PERIOD_SECONDS))
		GameState.note_attempt(Game.current_scenario_id)
	_objectives = cfg.get("objectives", [])
	_badge = str(cfg.get("badge", ""))
	_seats = Seating.seats_for(str(cfg.get("arrangement", "ushape")))
	# Deliberate-practice fade: each replay makes the room drift faster.
	_attempt = GameState.attempt_count(Game.current_scenario_id)
	_offtask_rise *= 1.0 + 0.12 * float(min(_attempt - 1, 4))

	_build_room()
	var occupied: Dictionary = {}
	for entry in cfg.get("roster", []):
		var idx: int = int(entry.get("seat", 0))
		if idx >= 0 and idx < _seats.size():
			var tile: Vector2i = _seats[idx]
			occupied[tile] = true
			_spawn_npc(tile, str(entry.get("id", "")), str(entry.get("name", "Student")))
	# Restore each student's off-task level if resuming the period.
	var ot_saved: Dictionary = Game.lesson.get("offtask", {})
	for st in _npcs.keys():
		_npcs[st]["offtask"] = float(ot_saved.get(_npcs[st]["persona_id"], 0.0))
	_build_seating(occupied)
	_spawn_player(Vector2i(11, 2))
	_add_banner()
	_add_badge_strip()
	_build_hud()

func setup(_data: Dictionary) -> void:
	pass

func _load_scenario(id: String) -> Dictionary:
	var path := Game.scenario_path(id)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
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
	_add_rect(Vector2(0, 0), Vector2(COLS * TILE, ROWS * TILE), COLOR_BG, -20)

	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			_put_tile(Vector2i(x, y), "res://assets/tiles/floor.png", COLOR_FLOOR, -19, false)

	for x in range(COLS):
		_add_wall(Vector2i(x, 0))
		_add_wall(Vector2i(x, ROWS - 1))
	for y in range(ROWS):
		_add_wall(Vector2i(0, y))
		_add_wall(Vector2i(COLS - 1, y))

	# Front wall: chalkboard across the middle, windows either side, door at the corner.
	for x in range(9, 15):
		_decor(Vector2i(x, 0), "res://assets/tiles/board.png")
	_decor(Vector2i(6, 0), "res://assets/tiles/window.png")
	_decor(Vector2i(17, 0), "res://assets/tiles/window.png")
	_decor(Vector2i(1, 0), "res://assets/tiles/door.png")

	# Teacher's desk at the front-left.
	_put_tile(Vector2i(2, 2), "res://assets/tiles/desk.png", COLOR_DESK, -8, true)
	_put_tile(Vector2i(3, 2), "res://assets/tiles/desk.png", COLOR_DESK, -8, true)

## Seats holding a student get their desk drawn over the student in _spawn_npc; the
## remaining seats show a standalone (empty) desk here.
func _build_seating(occupied: Dictionary) -> void:
	for s in _seats:
		if not occupied.has(s):
			_add_desk(s)

## Standalone (empty) desk filling a seat tile; blocks the tile. Same full-tile look as the
## desks drawn under seated students, so the grid is consistent.
func _add_desk(tile: Vector2i) -> void:
	_put_tile(tile, "res://assets/tiles/desk.png", COLOR_DESK, 0, true)

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

func _add_banner() -> void:
	var label := Label.new()
	label.text = "%s\nWalk the room; Z = talk.  Esc = mission hub." % _scenario_title
	label.position = Vector2(TILE + 4, 4)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 50
	add_child(label)

## Shows earned badges as icons in the top-right (GAME_CONCEPT.md gym-badge progression).
func _add_badge_strip() -> void:
	var order := ["routine", "echo", "balance", "mirror", "insight"]
	var x := COLS * TILE - 12
	for id in order:
		if not GameState.has_badge(id):
			continue
		var t := Art.tex("res://assets/ui/badge_%s.png" % id)
		x -= 34
		if t != null:
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x, 8)
			s.scale = Vector2(28.0 / float(t.get_width()), 28.0 / float(t.get_height()))
			s.z_index = 50
			add_child(s)
		else:
			var dot := ColorRect.new()
			dot.position = Vector2(x, 8)
			dot.size = Vector2(26, 26)
			dot.color = Color(0.95, 0.82, 0.30)
			dot.z_index = 50
			add_child(dot)

# --- actors ------------------------------------------------------------------

func _spawn_npc(tile: Vector2i, persona_id: String, display_name: String) -> void:
	var node := Node2D.new()
	node.position = Vector2(tile.x * TILE, tile.y * TILE)
	var head_y := 0.0
	var sheet := Art.tex("res://assets/sprites/%s_walk.png" % persona_id)
	var t := Art.tex("res://assets/sprites/%s_ow.png" % persona_id)
	# Desk at the seat tile, drawn FIRST so the student stands fully visible behind/above it
	# (no part of the character is hidden or clipped by the desk).
	var deskt := Art.tex("res://assets/tiles/desk.png")
	if deskt != null:
		var dk := Sprite2D.new()
		dk.texture = deskt
		dk.centered = false
		dk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dk.scale = Vector2(TILE / float(deskt.get_width()), TILE / float(deskt.get_height()))
		node.add_child(dk)
	# Feet rest just inside the top of the desk tile; the whole figure shows above it.
	var feety := TILE * 0.28
	if sheet != null and sheet.get_width() >= 48 and sheet.get_height() >= 128:
		# Normalize by the DRAWN figure (stand frame), not the cell, so all students match.
		var cw := int(sheet.get_width() / 3.0)
		var ch := int(sheet.get_height() / 4.0)
		var b := Art.opaque_bounds(sheet, Rect2i(cw, 0, cw, ch))
		var sc := (STUDENT_TILES_TALL * TILE) / float(b.size.y)
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
		head_y = feety - STUDENT_TILES_TALL * TILE
	elif t != null:
		var tb := Art.opaque_bounds(t, Rect2i(0, 0, t.get_width(), t.get_height()))
		var sc2 := (STUDENT_TILES_TALL * TILE) / float(tb.size.y)
		var s2 := Sprite2D.new()
		s2.texture = t
		s2.centered = false
		s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s2.scale = Vector2(sc2, sc2)
		s2.position = Vector2(TILE / 2.0 - (float(tb.position.x) + float(tb.size.x) / 2.0) * sc2, feety - float(tb.position.y + tb.size.y) * sc2)
		node.add_child(s2)
		head_y = feety - STUDENT_TILES_TALL * TILE
	else:
		var body := ColorRect.new()
		body.size = Vector2(TILE * 0.7, TILE * STUDENT_TILES_TALL)
		body.position = Vector2(TILE * 0.15, feety - TILE * STUDENT_TILES_TALL)
		body.color = _persona_color(persona_id)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(body)
		head_y = feety - STUDENT_TILES_TALL * TILE

	_add_talk_emote(node, head_y)

	var tag := Label.new()
	tag.text = display_name
	tag.position = Vector2(-6, TILE + 2)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 5)
	node.add_child(tag)

	# Off-task bar above the head (green = attentive, red = drifting).
	var barbg := ColorRect.new()
	barbg.size = Vector2(30, 5)
	barbg.position = Vector2(1, head_y - 11)
	barbg.color = Color(0, 0, 0, 0.55)
	barbg.z_index = 6
	node.add_child(barbg)
	var barfill := ColorRect.new()
	barfill.size = Vector2(0, 5)
	barfill.position = Vector2(1, head_y - 11)
	barfill.color = Color(0.3, 0.8, 0.4)
	barfill.z_index = 7
	node.add_child(barfill)

	node.z_index = 1
	add_child(node)
	_npcs[tile] = {
		"persona_id": persona_id, "display_name": display_name, "node": node,
		"offtask": 0.0, "fill": barfill,
	}

## A bobbing "!" bubble just above an NPC's head to invite interaction.
func _add_talk_emote(node: Node2D, head_y: float) -> void:
	var t := Art.tex("res://assets/ui/emote_exclaim.png")
	if t == null:
		return
	var e := Sprite2D.new()
	e.texture = t
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := 20.0 / float(t.get_width())
	e.scale = Vector2(sc, sc)
	e.position = Vector2(TILE / 2.0 - 10.0, head_y - 32.0)
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
	p.z_index = 2
	p.overworld = self          # set before add_child so _ready() can read TILE
	add_child(p)
	_player = p

# --- live classroom management (proximity + withitness) ----------------------

func _build_hud() -> void:
	var lbl := Label.new()
	lbl.text = "CLASS ATTENTION"
	lbl.position = Vector2(TILE + 4, 58)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.z_index = 60
	add_child(lbl)

	var bg := ColorRect.new()
	bg.position = Vector2(TILE + 4, 78)
	bg.size = Vector2(220, 16)
	bg.color = Color(0, 0, 0, 0.55)
	bg.z_index = 60
	add_child(bg)
	_attention_fill = ColorRect.new()
	_attention_fill.position = Vector2(TILE + 6, 80)
	_attention_fill.size = Vector2(216, 12)
	_attention_fill.color = Color(0.30, 0.80, 0.40)
	_attention_fill.z_index = 61
	add_child(_attention_fill)

	_disrupt_label = Label.new()
	_disrupt_label.text = "Disruptions: 0"
	_disrupt_label.position = Vector2(TILE + 4, 98)
	_disrupt_label.add_theme_font_size_override("font_size", 12)
	_disrupt_label.add_theme_color_override("font_color", Color(0.97, 0.85, 0.6))
	_disrupt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_disrupt_label.add_theme_constant_override("outline_size", 5)
	_disrupt_label.z_index = 60
	add_child(_disrupt_label)

	_equity_label = Label.new()
	_equity_label.text = "Engaged: 0/0"
	_equity_label.position = Vector2(TILE + 250, 112)
	_equity_label.add_theme_font_size_override("font_size", 12)
	_equity_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.95))
	_equity_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_equity_label.add_theme_constant_override("outline_size", 5)
	_equity_label.z_index = 60
	add_child(_equity_label)

	_coach_hint = Label.new()
	_coach_hint.position = Vector2(TILE + 4, ROWS * TILE - 30)
	_coach_hint.size = Vector2(COLS * TILE - 2 * TILE, 22)
	_coach_hint.add_theme_font_size_override("font_size", 14)
	_coach_hint.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	_coach_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_coach_hint.add_theme_constant_override("outline_size", 5)
	_coach_hint.z_index = 60
	add_child(_coach_hint)

	# Period clock (top-right) and Composure bar (under attention).
	_clock_label = Label.new()
	_clock_label.text = "Period: 2:30"
	_clock_label.position = Vector2(TILE + 250, 58)
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	_clock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock_label.add_theme_constant_override("outline_size", 5)
	_clock_label.z_index = 60
	add_child(_clock_label)

	var clbl := Label.new()
	clbl.text = "COMPOSURE"
	clbl.position = Vector2(TILE + 250, 78)
	clbl.add_theme_font_size_override("font_size", 11)
	clbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.85))
	clbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	clbl.add_theme_constant_override("outline_size", 5)
	clbl.z_index = 60
	add_child(clbl)
	var cbg := ColorRect.new()
	cbg.position = Vector2(TILE + 250, 94)
	cbg.size = Vector2(160, 14)
	cbg.color = Color(0, 0, 0, 0.55)
	cbg.z_index = 60
	add_child(cbg)
	_composure_fill = ColorRect.new()
	_composure_fill.position = Vector2(TILE + 252, 96)
	_composure_fill.size = Vector2(156, 10)
	_composure_fill.color = Color(0.90, 0.45, 0.55)
	_composure_fill.z_index = 61
	add_child(_composure_fill)

func _process(delta: float) -> void:
	if _player == null or _npcs.is_empty():
		return
	if _lesson_over or input_locked:
		return

	# Period clock.
	_period_left -= delta
	if _clock_label != null:
		_clock_label.text = "Period: %d:%02d" % [int(_period_left) / 60, int(_period_left) % 60]
	if _period_left <= 0.0:
		_end_lesson()
		return

	# Interrupt events the teacher must triage.
	_next_interrupt -= delta
	if _next_interrupt <= 0.0:
		_trigger_interrupt()
		return

	var ptile: Vector2i = _player.current_tile()
	var facing_up: bool = _player.facing == Vector2i(0, -1)   # writing at the board, back to class

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
				_disrupt_label.text = "Disruptions: %d" % _disruptions
			ot = 65.0                                # brief cooldown after a flare-up
		info["offtask"] = ot
		var fill: ColorRect = info.get("fill", null)
		if fill != null:
			fill.size = Vector2(30.0 * ot / 100.0, 5)
			fill.color = Color(0.3, 0.8, 0.4).lerp(Color(0.9, 0.3, 0.25), ot / 100.0)
		total += ot
		if ot > worst:
			worst = ot
			worst_name = info.get("display_name", "")

	if _attention_fill != null:
		var attention := 100.0 - total / float(_npcs.size())
		_attention_fill.size = Vector2(216.0 * attention / 100.0, 12)
		_attention_fill.color = Color(0.9, 0.3, 0.25).lerp(Color(0.30, 0.80, 0.40), attention / 100.0)

	if _equity_label != null:
		_equity_label.text = "Engaged: %d/%d" % [_engaged_count(), _npcs.size()]

	if _coach_hint != null:
		if facing_up and worst > 30.0:
			_coach_hint.text = "Coach Vee: eyes on the room. Turning your back lets them drift."
		elif worst >= 60.0:
			_coach_hint.text = "Coach Vee: %s is drifting. Move closer (proximity) or scan the room." % worst_name
		elif worst >= 35.0:
			_coach_hint.text = "Coach Vee: a little restlessness building. Keep circulating."
		else:
			_coach_hint.text = "Coach Vee: room is settled. Circulate and scan as you teach."

# --- interrupt events + lesson debrief ---------------------------------------

func _trigger_interrupt() -> void:
	var ev: Dictionary = INTERRUPTS[randi() % INTERRUPTS.size()]
	_show_overlay(str(ev["text"]), ev["options"])

func _apply_noise(amount: float) -> void:
	for st in _npcs.keys():
		var info: Dictionary = _npcs[st]
		info["offtask"] = clampf(info.get("offtask", 0.0) + amount, 0.0, 100.0)

func _resolve_interrupt(opt: Dictionary) -> void:
	_composure = clampf(_composure + float(opt.get("dcomp", 0.0)), 0.0, 100.0)
	_apply_noise(float(opt.get("dnoise", 0.0)))
	_disruptions += int(opt.get("ddis", 0))
	if _disrupt_label != null:
		_disrupt_label.text = "Disruptions: %d" % _disruptions
	if _composure_fill != null:
		_composure_fill.size = Vector2(156.0 * _composure / 100.0, 10)
	if _coach_hint != null:
		_coach_hint.text = "Coach Vee: " + str(opt.get("coach", ""))
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
	var lines := ""
	var stars := 0
	for o in _objectives:
		var ok := _objective_met(o, attention)
		if ok:
			stars += 1
		lines += "%s  %s\n" % ["[PASS]" if ok else "[ -- ]", str(o.get("label", ""))]
	if stars == _objectives.size() and stars > 0 and _badge != "":
		GameState.award_badge(_badge)
	var summary := "%s\nDEBRIEF   Attention %d%%   Composure %d%%   Disruptions %d   Engaged %d/%d\n\n%sObjectives met: %d / %d\n%s" % [
		_scenario_title, int(attention), int(_composure), _disruptions, _engaged_count(), _npcs.size(),
		lines, stars, _objectives.size(), _debrief_note(attention)]
	if _attempt > 1:
		summary += "\n\n(Replay #%d - the room drifts faster each attempt.)" % _attempt
	Game.clear_lesson()
	_show_overlay(summary, [
		{"label": "Replay this lesson", "_action": "replay"},
		{"label": "Choose another mission", "_action": "hub"},
	])

func _engaged_count() -> int:
	var n := 0
	var v: Dictionary = Game.lesson.get("visited", {})
	for k in v.keys():
		if int(v[k]) > 0:
			n += 1
	return n

func _waittime_count() -> int:
	var c := 0
	for m in Game.lesson.get("moves", []):
		if m.get("wait_ok", false):
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
	return false

func _debrief_note(attention: float) -> String:
	if _composure <= 0.0:
		return "You ran out of composure. Triage interruptions with the least-intrusive option and keep circulating."
	if attention >= 75.0 and _disruptions <= 1:
		return "Strong withitness and proximity. The room stayed with you."
	if attention >= 55.0:
		return "Decent control. Circulate more and turn your back to the class less."
	return "The room drifted. Move among the desks and scan often; handle interruptions briefly."

func _show_overlay(text: String, options: Array) -> void:
	input_locked = true
	_overlay = Control.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(COLS * TILE, ROWS * TILE)
	_overlay.z_index = 100
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.size = _overlay.size
	dim.color = Color(0, 0, 0, 0.6)
	_overlay.add_child(dim)

	var pw := 660.0
	var ph := 360.0
	var px := (_overlay.size.x - pw) / 2.0
	var py := (_overlay.size.y - ph) / 2.0
	var panel := Panel.new()   # themed: rounded, bordered, drop shadow
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	_overlay.add_child(panel)

	var btns: Array = options
	if btns.is_empty():
		btns = [{"label": "Continue", "_action": "hub"}]
	# Buttons are bottom-anchored; the text fills the space above them (no overlap).
	var by := py + ph - float(btns.size()) * 44.0 - 16.0

	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(px + 22, py + 18)
	lbl.size = Vector2(pw - 44, by - py - 28)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.97, 0.96, 0.9))
	_overlay.add_child(lbl)

	for i in range(btns.size()):
		var opt: Dictionary = btns[i]
		var b := Button.new()
		b.text = str(opt.get("label", "OK"))
		b.position = Vector2(px + 22, by + i * 44.0)
		b.size = Vector2(pw - 44, 38)
		b.add_theme_font_size_override("font_size", 14)
		if opt.has("_action"):
			var act := str(opt["_action"])
			if act == "hub":
				b.pressed.connect(_go_hub)
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

func _restart_lesson() -> void:
	Game.clear_lesson()   # fresh period
	SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _go_hub() -> void:
	Game.clear_lesson()
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

## Press Esc / Backspace during a lesson to return to the mission hub.
func _unhandled_key_input(event: InputEvent) -> void:
	if input_locked or _lesson_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			_go_hub()

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
	SceneRouter.change_scene("res://scenes/encounter/Encounter.tscn", {
		"persona_id": npc.get("persona_id", ""),
		"display_name": npc.get("display_name", "Student"),
	})

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
