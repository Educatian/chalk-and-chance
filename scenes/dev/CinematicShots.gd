extends Node
## Dev: plays a mission cinematic and saves frames to tools/cine/.

func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	var id := "lecture_fractions"
	var mode := "intro"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		id = args[0]
	if args.size() > 1:
		mode = args[1]
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % id))
	var stack := Node.new()
	add_child(stack)
	SceneRouter.set_stack(stack)
	SceneRouter.change_scene("res://scenes/cinematic/MissionCinematic.tscn", {"scenario": cfg, "mode": mode, "won": true, "next_path": "res://scenes/ui/Hub.tscn"})
	for t in [1.2, 2.6, 3.4]:
		await get_tree().create_timer(t - (0.0 if t == 1.2 else 0.0)).timeout
		_shot("%s_%s_card_%s" % [id, mode, str(t)])
	for i in range(8):
		await get_tree().create_timer(1.2).timeout
		_shot("%s_%s_beat_%d" % [id, mode, i])
		_press()
		await get_tree().create_timer(0.1).timeout
		_press()
	get_tree().quit()

func _press() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/cine/%s.png" % name)
	print("saved ", name)
