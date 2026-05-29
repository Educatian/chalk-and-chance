extends Node
## Swaps the active gameplay scene inside a container node owned by Main.
## See GAME_CONCEPT.md section 9.2. Transition choreography (fade/wipe) is deferred past M1.

var _stack: Node = null
var _current: Node = null

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
	# Defer setup so the instance has finished _ready before receiving data.
	if inst.has_method("setup"):
		inst.call_deferred("setup", data)
