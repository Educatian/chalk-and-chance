extends Node
const BrandLogo = preload("res://scripts/BrandLogo.gd")
## Swaps the active gameplay scene inside a container node owned by Main.
## See GAME_CONCEPT.md section 9.2.

var _stack: Node = null
var _current: Node = null
var _current_path := ""

func set_stack(stack: Node) -> void:
	_stack = stack

func change_scene(path: String, data: Dictionary = {}) -> void:
	if _stack == null:
		push_error("SceneRouter: no stack set; call set_stack() from Main first")
		return
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
		_current = null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("SceneRouter: could not load scene %s" % path)
		return
	var inst: Node = packed.instantiate()
	var from_path := _current_path
	_stack.add_child(inst)
	_current = inst
	_current_path = path
	var track := Music.track_for_scene(path)
	if track != "":
		Music.play(track)
	# Context-aware transition: stepping up to a student (or back to the room) is a quick
	# "lean in" fade inside the same lesson; leaving or entering a mission keeps the wipe.
	if _is_close_up(path) or (_is_close_up(from_path) and path.contains("/overworld/")):
		_play_lean_in(inst, _is_close_up(path))
	else:
		_play_wipe()
	# Defer setup so the instance has finished _ready before receiving data.
	if inst.has_method("setup"):
		inst.call_deferred("setup", data)

func active_scene_name() -> String:
	if _current != null and is_instance_valid(_current):
		if _current_path != "":
			return _current_path
		return _current.name
	return ""

func _play_wipe() -> void:
	if _stack == null or bool(GameState.get_setting("reduced_motion", false)):
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	var wipe := ColorRect.new()
	wipe.color = Color("24304f")   # brand navy
	wipe.size = _stack.get_viewport().get_visible_rect().size
	wipe.position = Vector2.ZERO
	layer.add_child(wipe)
	var logo := BrandLogo.new(1)   # brand lockup, bottom right
	layer.add_child(logo)
	logo.position = Vector2(wipe.size.x - logo.size.x - 34, wipe.size.y - 82)
	var prompt := Label.new()
	prompt.text = "LOADING REHEARSAL"
	prompt.position = Vector2(34, wipe.size.y - 42)
	prompt.size = Vector2(wipe.size.x - 68, 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color("b9b7a8"))
	layer.add_child(prompt)
	_stack.add_child(layer)
	var tw := create_tween()
	tw.tween_property(wipe, "position:x", wipe.size.x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)

func _is_close_up(p: String) -> bool:
	return p.ends_with("/Encounter.tscn") or p.ends_with("/GroupCheckIn.tscn")

## Short fade from dark; entering a close-up also eases the new screen in from 103%.
func _play_lean_in(inst: Node, entering: bool) -> void:
	if _stack == null or bool(GameState.get_setting("reduced_motion", false)):
		return
	Sfx.play("whoosh", -12.0 if entering else -16.0)
	var layer := CanvasLayer.new()
	layer.layer = 90
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.045, 1.0)
	shade.size = _stack.get_viewport().get_visible_rect().size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	_stack.add_child(layer)
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	if entering and inst is Control:
		var c := inst as Control
		c.pivot_offset = c.get_viewport_rect().size * 0.5
		c.scale = Vector2(1.03, 1.03)
		create_tween().tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
