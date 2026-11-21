extends Node2D
## Grid-locked, tween-stepped movement like a Pokemon overworld (GAME_CONCEPT.md 9.3).
## Arrow keys move; Z / Enter (ui_accept) interacts with the faced tile.
## Visual priority: 4-dir walk sheet (AnimatedSprite2D) > static sprite > placeholder rect.

const Art = preload("res://scripts/Art.gd")
const STEP_TIME := 0.12
## Drawn at the room's texel density (Overworld.PX_PER_TEXEL), not normalised to a height.
const DEFAULT_PX_PER_TEXEL := 1.25
const WALK_SHEET := "res://assets/sprites/teacher_ow.png"   # static fallback base name
const WALK_ANIM_SHEET := "res://assets/sprites/teacher_walk.png"

var overworld = null
var tile := 32                    # synced from overworld.TILE in _ready
var facing := Vector2i(0, 1)
var _moving := false
var _anim: AnimatedSprite2D = null
const InputFeel = preload("res://scripts/InputFeel.gd")
const TURN_HOLD := 0.08           # hold this long after a turn-in-place before walking
const BUMP_COOLDOWN_MS := 260
var _buffer := InputFeel.MoveBuffer.new()
var _walking := false             # true while a held/buffered walk is in progress
var _turn_hold := 0.0
var _last_bump_ms := -10000
var _bump_tween: Tween = null
var _path: Array = []             # tap/click-to-walk: remaining tiles to step through
var _path_face := Vector2i.ZERO   # after the path, face this way (toward a tapped student)
var _path_talk := false           # ...and talk to them

## Walk along a tile path (from InputFeel.grid_path); optionally face and talk at the end.
func walk_path(path: Array, face: Vector2i = Vector2i.ZERO, talk: bool = false) -> void:
	_path = path.duplicate()
	if not _path.is_empty() and _path[0] == current_tile():
		_path.pop_front()
	_path_face = face
	_path_talk = talk

func cancel_path() -> void:
	_path.clear()
	_path_talk = false

func _ready() -> void:
	if overworld != null:
		tile = overworld.TILE
	_build_visual()

func _build_visual() -> void:
	var sheet := Art.tex(WALK_ANIM_SHEET)
	if sheet != null and sheet.get_width() >= 48 and sheet.get_height() >= 128:
		var cw := int(sheet.get_width() / 3.0)
		var ch := int(sheet.get_height() / 4.0)
		# Scale by the DRAWN figure (stand frame), not the cell, so every character is the
		# same on-screen height regardless of how much of the cell the art fills.
		var b := Art.opaque_bounds(sheet, Rect2i(cw, 0, cw, ch))
		var sc := _px_per_texel()
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = _make_frames(sheet)
		_anim.centered = false
		_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anim.scale = Vector2(sc, sc)
		var feet := float(b.position.y + b.size.y)
		var figcx := float(b.position.x) + float(b.size.x) / 2.0
		_anim.position = Vector2(tile / 2.0 - figcx * sc, tile - feet * sc)
		add_child(_anim)
		_go_idle()
		return
	var t := Art.tex(WALK_SHEET)
	if t != null:
		var tb := Art.opaque_bounds(t, Rect2i(0, 0, t.get_width(), t.get_height()))
		var sc2 := _px_per_texel() * (64.0 / float(maxi(1, t.get_height())))
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(sc2, sc2)
		s.position = Vector2(tile / 2.0 - (float(tb.position.x) + float(tb.size.x) / 2.0) * sc2, tile - float(tb.position.y + tb.size.y) * sc2)
		add_child(s)
		return
	var spr := ColorRect.new()
	spr.size = Vector2(tile, tile)
	spr.color = Color(0.25, 0.55, 0.95)
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spr)

func _px_per_texel() -> float:
	return float(overworld.PX_PER_TEXEL) if overworld != null else DEFAULT_PX_PER_TEXEL

## Slice a 3-col x 4-row sheet into walk_down/left/right/up animations.
func _make_frames(sheet: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var cols := 3
	var rows := 4
	var cw := int(sheet.get_width() / float(cols))
	var ch := int(sheet.get_height() / float(rows))
	var names := ["walk_down", "walk_left", "walk_right", "walk_up"]
	var seq := [0, 1, 2, 1]
	for r in range(rows):
		var anim_name: String = names[r]
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 6.0)
		for col in seq:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * cw, r * ch, cw, ch)
			sf.add_frame(anim_name, at)
	return sf

func _held_dir() -> Vector2i:
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		return Vector2i(0, -1)
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		return Vector2i(0, 1)
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		return Vector2i(1, 0)
	return Vector2i.ZERO

## Taps that land while a step is still tweening are buffered, not dropped.
func _unhandled_input(event: InputEvent) -> void:
	if not _moving or not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction):
		return
	if not event.is_pressed() or event.is_echo():
		return
	var d := Vector2i.ZERO
	if event.is_action("ui_up") or (event is InputEventKey and event.keycode == KEY_W):
		d = Vector2i(0, -1)
	elif event.is_action("ui_down") or (event is InputEventKey and event.keycode == KEY_S):
		d = Vector2i(0, 1)
	elif event.is_action("ui_left") or (event is InputEventKey and event.keycode == KEY_A):
		d = Vector2i(-1, 0)
	elif event.is_action("ui_right") or (event is InputEventKey and event.keycode == KEY_D):
		d = Vector2i(1, 0)
	_buffer.press(d, Time.get_ticks_msec())

func _process(delta: float) -> void:
	if _moving:
		return
	if overworld != null and overworld.input_locked:
		_buffer.clear()
		_go_idle()
		return
	var dir := _held_dir()
	if dir != Vector2i.ZERO:
		cancel_path()   # keys always win over a tap path
	elif not _path.is_empty():
		var nxt: Vector2i = _path.pop_front()
		var step := nxt - current_tile()
		if absi(step.x) + absi(step.y) == 1 and overworld != null and overworld.is_walkable(nxt):
			facing = step
			_walking = true
			_start_walk()
			_try_move(step)
		else:
			cancel_path()   # the room changed under the path; stop cleanly
		return
	elif _path_face != Vector2i.ZERO:
		facing = _path_face
		_path_face = Vector2i.ZERO
		_go_idle()
		if _path_talk:
			_path_talk = false
			_try_interact()
		return
	var buffered := _buffer.take(Time.get_ticks_msec())
	if dir == Vector2i.ZERO and buffered != Vector2i.ZERO:
		dir = buffered
		_walking = true   # a buffered tap continues the walk; no turn pause

	if dir != Vector2i.ZERO:
		# From a standstill, a new direction first turns in place; holding it walks.
		if not _walking and dir != facing:
			facing = dir
			_turn_hold = TURN_HOLD
			_go_idle()
			return
		if _turn_hold > 0.0:
			_turn_hold -= delta
			return
		facing = dir
		_walking = true
		_start_walk()
		_try_move(dir)
	elif Input.is_action_just_pressed("ui_accept"):
		# ui_accept already covers Enter and Space; a raw is_key_pressed check here
		# would re-trigger the interaction every frame while the key is held.
		_walking = false
		_turn_hold = 0.0
		_try_interact()
	else:
		_walking = false
		_turn_hold = 0.0
		_go_idle()

func _dir_name() -> String:
	if facing == Vector2i(0, -1):
		return "up"
	if facing == Vector2i(-1, 0):
		return "left"
	if facing == Vector2i(1, 0):
		return "right"
	return "down"

func _start_walk() -> void:
	if _anim == null:
		return
	var a := "walk_" + _dir_name()
	if _anim.animation != a or not _anim.is_playing():
		_anim.play(a)

func _go_idle() -> void:
	if _anim == null:
		return
	var a := "walk_" + _dir_name()
	if _anim.animation != a:
		_anim.animation = a
	_anim.pause()
	_anim.frame = 1   # the standing column

func current_tile() -> Vector2i:
	return Vector2i(roundi(position.x / float(tile)), roundi(position.y / float(tile)))

func _try_move(dir: Vector2i) -> void:
	var from_tile := current_tile()
	var target := from_tile + dir
	if overworld != null and not overworld.is_walkable(target):
		Telemetry.log_player_movement("blocked", {
			"from": _tile_dict(from_tile),
			"to": _tile_dict(target),
			"dir": _tile_dict(dir),
			"position": {"x": position.x, "y": position.y},
		})
		_go_idle()
		_bump(dir)
		return
	Telemetry.log_player_movement("step_start", {
		"from": _tile_dict(from_tile),
		"to": _tile_dict(target),
		"dir": _tile_dict(dir),
		"position": {"x": position.x, "y": position.y},
	})
	if bool(GameState.get_setting("reduced_motion", false)):
		# Snap instead of tween, but keep the same per-tile cadence; without the
		# cooldown the player crosses one tile per frame (~60 tiles/sec).
		_moving = true
		position = Vector2(target.x * tile, target.y * tile)
		Telemetry.log_player_movement("step_end", {
			"from": _tile_dict(from_tile),
			"to": _tile_dict(target),
			"dir": _tile_dict(dir),
			"position": {"x": position.x, "y": position.y},
		})
		await get_tree().create_timer(STEP_TIME).timeout
		_moving = false
		return
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(target.x * tile, target.y * tile), STEP_TIME)
	await tw.finished
	_moving = false
	Telemetry.log_player_movement("step_end", {
		"from": _tile_dict(from_tile),
		"to": _tile_dict(target),
		"dir": _tile_dict(dir),
		"position": {"x": position.x, "y": position.y},
	})

## Walking into a desk, wall or student: a soft thud and a 3px nudge, rate-limited so
## holding the key against a wall does not machine-gun the sound.
func _bump(dir: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_bump_ms < BUMP_COOLDOWN_MS:
		return
	_last_bump_ms = now
	Sfx.play("bump", -6.0)
	var visual: Node2D = _anim
	if visual == null or bool(GameState.get_setting("reduced_motion", false)):
		return
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	var base := visual.position
	visual.set_meta("rest_pos", visual.get_meta("rest_pos", base))
	base = visual.get_meta("rest_pos")
	_bump_tween = create_tween()
	_bump_tween.tween_property(visual, "position", base + Vector2(dir) * 3.0, 0.05).set_ease(Tween.EASE_OUT)
	_bump_tween.tween_property(visual, "position", base, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _try_interact() -> void:
	if overworld == null:
		return
	var target := current_tile() + facing
	var npc: Dictionary = overworld.npc_at(target)
	Telemetry.log_player_movement("interact", {
		"from": _tile_dict(current_tile()),
		"to": _tile_dict(target),
		"dir": _tile_dict(facing),
		"hit_npc": not npc.is_empty(),
		"persona_id": str(npc.get("persona_id", "")),
	})
	if not npc.is_empty():
		overworld.start_encounter(npc)

func _tile_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}
