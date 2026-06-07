extends Node
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
	_stack.add_child(inst)
	_current = inst
	_current_path = path
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
	wipe.color = Color(0.02, 0.025, 0.045, 0.94)
	wipe.size = _stack.get_viewport().get_visible_rect().size
	wipe.position = Vector2.ZERO
	layer.add_child(wipe)
	var title := Label.new()
	title.text = "CHALK & CHANCE"
	title.position = Vector2(34, wipe.size.y - 74)
	title.size = Vector2(wipe.size.x - 68, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86, 0.92))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.045, 1.0))
	title.add_theme_constant_override("outline_size", 5)
	layer.add_child(title)
	var prompt := Label.new()
	prompt.text = "LOADING REHEARSAL"
	prompt.position = Vector2(34, wipe.size.y - 42)
	prompt.size = Vector2(wipe.size.x - 68, 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0.62, 0.88, 0.95, 0.82))
	layer.add_child(prompt)
	var scan_count := 6
	for i in range(scan_count):
		var scan := ColorRect.new()
		scan.color = Color(0.55, 0.86, 0.95, 0.18)
		scan.position = Vector2(-24, 12 + i * 56)
		scan.size = Vector2(wipe.size.x + 48, 2)
		layer.add_child(scan)
	var colors := [
		Color(0.98, 0.80, 0.28, 0.90),
		Color(0.30, 0.92, 0.86, 0.88),
		Color(0.94, 0.34, 0.55, 0.86),
	]
	for i in range(12):
		var block := ColorRect.new()
		block.color = colors[i % colors.size()]
		block.size = Vector2(18 + (i % 4) * 8, 10 + (i % 3) * 6)
		block.position = Vector2(-72 - i * 12, 24 + (i * 31) % int(maxf(48.0, wipe.size.y - 72.0)))
		layer.add_child(block)
		var block_tw := create_tween()
		block_tw.tween_property(block, "position:x", wipe.size.x + 80 + i * 9, 0.28 + float(i % 4) * 0.014).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stack.add_child(layer)
	var tw := create_tween()
	tw.tween_property(wipe, "position:x", wipe.size.x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
