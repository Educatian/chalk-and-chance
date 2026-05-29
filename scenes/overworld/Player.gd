extends Node2D
## Grid-locked, tween-stepped movement like a Pokemon overworld (GAME_CONCEPT.md 9.3).
## Arrow keys move; Z / Enter (ui_accept) interacts with the faced tile.
## Visual priority: 4-dir walk sheet (AnimatedSprite2D) > static sprite > placeholder rect.

const Art = preload("res://scripts/Art.gd")
const STEP_TIME := 0.12
const TEACHER_TILES_TALL := 1.7   # adult: taller than the ~1.35-tall students
const WALK_SHEET := "res://assets/sprites/teacher_ow.png"   # static fallback base name
const WALK_ANIM_SHEET := "res://assets/sprites/teacher_walk.png"

var overworld = null
var tile := 32                    # synced from overworld.TILE in _ready
var facing := Vector2i(0, 1)
var _moving := false
var _anim: AnimatedSprite2D = null

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
		var sc := (TEACHER_TILES_TALL * tile) / float(b.size.y)
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
		var sc2 := (TEACHER_TILES_TALL * tile) / float(tb.size.y)
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

func _process(_delta: float) -> void:
	if _moving:
		return
	if overworld != null and overworld.input_locked:
		_go_idle()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)
	elif Input.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)

	if dir != Vector2i.ZERO:
		facing = dir
		_start_walk()
		_try_move(dir)
	elif Input.is_action_just_pressed("ui_accept"):
		_try_interact()
	else:
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
	var target := current_tile() + dir
	if overworld != null and not overworld.is_walkable(target):
		_go_idle()
		return
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(target.x * tile, target.y * tile), STEP_TIME)
	await tw.finished
	_moving = false

func _try_interact() -> void:
	if overworld == null:
		return
	var target := current_tile() + facing
	var npc: Dictionary = overworld.npc_at(target)
	if not npc.is_empty():
		overworld.start_encounter(npc)
