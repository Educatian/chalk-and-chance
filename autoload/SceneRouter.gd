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
	wipe.color = Color(0.03, 0.04, 0.07, 0.9)
	wipe.size = _stack.get_viewport().get_visible_rect().size
	wipe.position = Vector2.ZERO
	layer.add_child(wipe)
	_stack.add_child(layer)
	var tw := create_tween()
	tw.tween_property(wipe, "position:x", wipe.size.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
