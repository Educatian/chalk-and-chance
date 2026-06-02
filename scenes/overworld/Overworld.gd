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
var _format: String = ""      # scenario format (discussion/group_work/...) -> idle animation
var _objectives: Array = []   # scenario objectives, scored at debrief
var _offtask_rise := OFFTASK_RISE
var _attempt := 1
var _scenario_title := "Lesson"
var _badge := ""
var _scenario_cfg: Dictionary = {}

var _walls: Dictionary = {}   # Vector2i -> true
var _npcs: Dictionary = {}    # Vector2i -> { persona_id, display_name, node, offtask, fill }
var _player: Node2D = null

# HUD for the live classroom state.
var _attention_fill: ColorRect = null
var _disrupt_label: Label = null
var _equity_label: Label = null
var _risk_label: Label = null
var _objective_label: Label = null
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
var _lesson_over := false
var _overlay: Control = null
var _pending_debrief := ""   # scored summary, shown after the reflection step

func _ready() -> void:
	var cfg := _load_scenario(Game.current_scenario_id)
	_scenario_cfg = cfg
	_scenario_title = str(cfg.get("title", "Lesson"))
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

## Build a looping idle AnimatedSprite2D from a 6-frame strip (<persona>_idle.png, 192x64:
## neutral/breathe/look-left/look-right/hand-raise/lean-work). Returns null if the strip is
## absent, so the caller falls back to the static stand frame. Animation + tempo + start
## frame are picked by scenario format and randomized so the class is not in lockstep.
func _build_idle_anim(persona_id: String, feety: float) -> AnimatedSprite2D:
	var sheet := Art.tex("res://assets/sprites/%s_idle.png" % persona_id)
	if sheet == null:
		return null
	var fw := int(sheet.get_width() / 6.0)
	var fh := int(sheet.get_height())
	if fw < 8 or fh < 16:
		return null
	var b0 := Art.opaque_bounds(sheet, Rect2i(0, 0, fw, fh))
	if b0.size.y <= 0:
		return null
	var sc := (STUDENT_TILES_TALL * TILE) / float(b0.size.y)
	var frames := SpriteFrames.new()
	var sets := {
		"idle": [0, 1, 0, 2, 0, 3],
		"discuss": [0, 1, 4, 0, 2, 1],
		"work": [0, 5, 0, 1, 5, 0],
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
	asp.sprite_frames = frames
	asp.centered = false
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	asp.scale = Vector2(sc, sc)
	asp.position = Vector2(TILE / 2.0 - (float(b0.position.x) + float(b0.size.x) / 2.0) * sc, feety - float(b0.position.y + b0.size.y) * sc)
	var anim := "idle"
	if _format == "group_work":
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
	var idle_anim := _build_idle_anim(persona_id, feety)
	if idle_anim != null:
		node.add_child(idle_anim)
		char_spr = idle_anim
		head_y = feety - STUDENT_TILES_TALL * TILE
	elif sheet != null and sheet.get_width() >= 48 and sheet.get_height() >= 128:
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
		char_spr = s
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

	_risk_label = Label.new()
	_risk_label.text = "Room cue: settled"
	_risk_label.position = Vector2(TILE + 4, 118)
	_risk_label.size = Vector2(430, 20)
	_risk_label.add_theme_font_size_override("font_size", 12)
	_risk_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	_risk_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_risk_label.add_theme_constant_override("outline_size", 5)
	_risk_label.z_index = 60
	add_child(_risk_label)

	_objective_label = Label.new()
	_objective_label.text = ""
	_objective_label.position = Vector2(COLS * TILE - 300, 58)
	_objective_label.size = Vector2(260, 90)
	_objective_label.add_theme_font_size_override("font_size", 11)
	_objective_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.78))
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_objective_label.add_theme_constant_override("outline_size", 5)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.z_index = 60
	add_child(_objective_label)

	_interact_label = Label.new()
	_interact_label.text = ""
	_interact_label.position = Vector2(TILE + 4, ROWS * TILE - 54)
	_interact_label.size = Vector2(COLS * TILE - 2 * TILE, 20)
	_interact_label.add_theme_font_size_override("font_size", 14)
	_interact_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.50))
	_interact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_interact_label.add_theme_constant_override("outline_size", 5)
	_interact_label.z_index = 60
	add_child(_interact_label)

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

	if _risk_label != null:
		if worst >= 70.0:
			_risk_label.text = "Hot spot: %s is at %d%% drift. Move close now." % [worst_name, int(worst)]
			_risk_label.add_theme_color_override("font_color", Color(0.98, 0.58, 0.46))
		elif worst >= 45.0:
			_risk_label.text = "Room cue: %s is starting to drift (%d%%)." % [worst_name, int(worst)]
			_risk_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
		else:
			_risk_label.text = "Room cue: settled. Keep scanning and circulate."
			_risk_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))

	var faced: Vector2i = ptile + _player.facing
	if _interact_label != null:
		var npc: Dictionary = npc_at(faced)
		if not npc.is_empty():
			_interact_label.text = "Press Z to talk to %s" % npc.get("display_name", "student")
		else:
			_interact_label.text = "Green bars = focused; red bars = drifting. Move closer to lower them."

	if _objective_label != null:
		var attention_now := 100.0 - total / float(_npcs.size())
		_objective_label.text = _objectives_status(attention_now)

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
	Sfx.play("interrupt")
	var ev: Dictionary = INTERRUPTS[randi() % INTERRUPTS.size()]
	_show_overlay(str(ev["text"]), ev["options"])

func _apply_noise(amount: float) -> void:
	for st in _npcs.keys():
		var info: Dictionary = _npcs[st]
		info["offtask"] = clampf(info.get("offtask", 0.0) + amount, 0.0, 100.0)

func _resolve_interrupt(opt: Dictionary) -> void:
	_composure = clampf(_composure + float(opt.get("dcomp", 0.0)), 0.0, GameState.max_composure())
	_apply_noise(float(opt.get("dnoise", 0.0)))
	_disruptions += int(opt.get("ddis", 0))
	if _disrupt_label != null:
		_disrupt_label.text = "Disruptions: %d" % _disruptions
	if _composure_fill != null:
		_composure_fill.size = Vector2(156.0 * _composure / GameState.max_composure(), 10)
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
	var reward_lines := ""
	var objective_tags: Array = []
	var miss_tips: Array = []
	var stars := 0
	for o in _objectives:
		var ok := _objective_met(o, attention)
		if ok:
			stars += 1
		objective_tags.append("%s %s" % ["OK" if ok else "MISS", _objective_short_label(o)])
		if not ok:
			miss_tips.append(_objective_tip(o, attention))
	if stars == _objectives.size() and stars > 0 and _badge != "":
		var reward := GameState.award_badge(_badge)
		Sfx.play("badge")
		reward_lines += "Reward: Badge %s" % _badge.to_upper()
		if bool(reward.get("level_up", false)):
			reward_lines += " | Level %d | +upgrade" % int(reward.get("level_after", GameState.teacher_level))
		if _items_awarded_text(reward.get("items_awarded", {})) != "":
			reward_lines += " | +items"
		reward_lines += "\n"
		GameState.record_leaderboard({
			"scenario_id": str(Game.current_scenario_id),
			"title": _scenario_title,
			"mode": "Classroom",
			"badge": _badge,
			"score": stars * 80 + int(round(attention)) + int(round(_composure)) + _engaged_count() * 10 - _disruptions * 12,
			"detail": "Objectives %d/%d  Attention %d%%  Engaged %d/%d" % [stars, _objectives.size(), int(attention), _engaged_count(), _npcs.size()],
			"level_up": bool(reward.get("level_up", false)),
		})
	var next_line := _debrief_note(attention)
	if not miss_tips.is_empty():
		next_line = "Next: %s." % str(miss_tips[0]).capitalize()
	var summary := "%s\nDEBRIEF   Attention %d%%   Composure %d%%   Disruptions %d\nEngaged %d/%d   Objectives %d/%d\n%sObjectives: %s\n%s\n%s\n%s\n%s" % [
		_scenario_title, int(attention), int(_composure), _disruptions,
		_engaged_count(), _npcs.size(), stars, _objectives.size(),
		reward_lines, " | ".join(objective_tags), next_line,
		Game.evidence_practice_target(false), Game.scenario_edge_label(_scenario_cfg), _compact_evidence_fingerprint(attention)]
	if _attempt > 1:
		summary += "\nReplay #%d: the room drifts faster each attempt." % _attempt
	_pending_debrief = summary
	var reflection_options := _reflection_options(attention)
	Game.clear_lesson()
	# Reflection-on-action FIRST (Schon): the player names what they noticed before seeing a score.
	_show_overlay("REFLECT\n\nBefore the score: what stays with you from this period? Naming it is where the practice sticks.", reflection_options)

func _on_reflect(opt: Dictionary) -> void:
	GameState.log_reflection({
		"scenario": Game.current_scenario_id,
		"prompt": "what_stays_with_you",
		"choice": str(opt.get("_reflect", "")),
	})
	_close_overlay()
	_show_overlay(_pending_debrief, [
		{"label": "Replay this lesson", "_action": "replay"},
		{"label": "Choose another mission", "_action": "hub"},
	])

func _reflection_options(attention: float) -> Array:
	var opts: Array = []
	for o in _objectives:
		if _objective_met(o, attention):
			continue
		match str(o.get("metric", "")):
			"engaged_min":
				opts.append({"label": "Who I did not reach", "_reflect": "unreached"})
			"attention_min":
				opts.append({"label": "When the room drifted", "_reflect": "attention"})
			"waittime_min":
				opts.append({"label": "Where I rushed wait time", "_reflect": "wait_time"})
			"connect_min":
				opts.append({"label": "An asset I could connect to", "_reflect": "asset"})
			"disruptions_max":
				opts.append({"label": "A disruption I would handle smaller", "_reflect": "disruption"})
			"composure_min":
				opts.append({"label": "A moment I would reframe", "_reflect": "reframe"})
	if opts.is_empty():
		opts = [
			{"label": "A move that worked", "_reflect": "worked"},
			{"label": "An asset I connected to", "_reflect": "asset"},
			{"label": "One stretch goal next time", "_reflect": "stretch"},
		]
	while opts.size() < 3:
		opts.append({"label": "One moment to replay", "_reflect": "replay_moment"})
	return opts.slice(0, 3)

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
		var desc := str(o.get("label", metric))
		if desc.length() > 32:
			desc = desc.substr(0, 29) + "..."
		lines.append("[%s] %s (%d/%d)" % [mark, desc, current, target])
	return "\n".join(lines)

func _objectives_met_count(attention: float) -> int:
	var n := 0
	for o in _objectives:
		if _objective_met(o, attention):
			n += 1
	return n

func _debrief_note(attention: float) -> String:
	if _composure <= 0.0:
		return "You ran out of composure. Triage interruptions with the least-intrusive option and keep circulating."
	if attention >= 75.0 and _disruptions <= 1:
		return "Strong withitness and proximity. The room stayed with you."
	if attention >= 55.0:
		return "Decent control. Circulate more and turn your back to the class less."
	return "The room drifted. Move among the desks and scan often; handle interruptions briefly."

func _objective_tip(o: Dictionary, attention: float) -> String:
	match str(o.get("metric", "")):
		"attention_min":
			return "circulate and face the room more"
		"disruptions_max":
			return "choose least-intrusive interruption responses"
		"composure_min":
			return "avoid dead time and public escalations"
		"engaged_min":
			return "talk to every student: %d/%d reached" % [_engaged_count(), int(o.get("target", 0))]
		"waittime_min":
			return "use Wait after asking: %d/%d" % [_waittime_count(), int(o.get("target", 0))]
		"connect_min":
			return "use Connect twice: notice, then bridge"
	return "try again with this goal in mind"

func _objective_short_label(o: Dictionary) -> String:
	match str(o.get("metric", "")):
		"attention_min":
			return "on-task"
		"disruptions_max":
			return "disruptions"
		"composure_min":
			return "composure"
		"engaged_min":
			return "conferences"
		"waittime_min":
			return "wait-time"
		"connect_min":
			return "asset connect"
	return str(o.get("id", "objective"))

func _evidence_fingerprint(attention: float) -> String:
	var moves: Array = Game.lesson.get("moves", [])
	var targeted := 0
	var waits := 0
	var connects := 0
	var tells := 0
	var redirects := 0
	for m in moves:
		if bool(m.get("targets", false)):
			targeted += 1
		if bool(m.get("wait_ok", false)):
			waits += 1
		match str(m.get("tag", "")):
			"connect":
				connects += 1
			"tell":
				tells += 1
			"redirect":
				redirects += 1
	var equity := "%d/%d learners reached" % [_engaged_count(), _npcs.size()]
	var trace := "Evidence fingerprint: attention %d%%, %s, target-fit moves %d/%d, wait-time evidence %d" % [
		int(attention), equity, targeted, moves.size(), waits]
	if connects > 0:
		trace += ", asset connects %d" % connects
	if redirects > 0:
		trace += ", least-intrusive redirects %d" % redirects
	if tells > 0:
		trace += ", tell/takeover attempts %d" % tells
	trace += "."
	return trace

func _compact_evidence_fingerprint(attention: float) -> String:
	var moves: Array = Game.lesson.get("moves", [])
	var targeted := 0
	var waits := 0
	for m in moves:
		if m.get("targets", false):
			targeted += 1
		if m.get("wait_ok", false):
			waits += 1
	return "Evidence: attention %d%%, reached %d/%d, target-fit %d/%d, wait-time %d." % [
		int(attention), _engaged_count(), _npcs.size(), targeted, moves.size(), waits]

func _items_awarded_text(items) -> String:
	if typeof(items) != TYPE_DICTIONARY:
		return ""
	var parts: Array = []
	for id in items.keys():
		var amt := int(items[id])
		if amt > 0:
			parts.append("%s x%d" % [Items.short_name_for(str(id)), amt])
	return ", ".join(parts)

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
	lbl.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
	lbl.add_theme_color_override("font_color", Color(0.97, 0.96, 0.9))
	_overlay.add_child(lbl)

	for i in range(btns.size()):
		var opt: Dictionary = btns[i]
		var b := Button.new()
		b.text = str(opt.get("label", "OK"))
		b.position = Vector2(px + 22, by + i * 44.0)
		b.size = Vector2(pw - 44, 38)
		b.add_theme_font_size_override("font_size", 14 + GameState.ui_font_delta())
		if opt.has("_reflect"):
			b.pressed.connect(_on_reflect.bind(opt))
		elif opt.has("_action"):
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
		return "The pod is working on %s, but their reasoning has not been surfaced yet." % str(_scenario_cfg.get("title", "the task"))
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
