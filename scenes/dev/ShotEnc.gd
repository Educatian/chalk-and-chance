extends Node
## One-off capture of the Encounter in both input modes (menu + type) to verify the
## free-text UI layout. Run WINDOWED: godot --path . res://scenes/dev/ShotEnc.tscn

const OUT_DIR := "res://tmp/"

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)   # real-play window so canvas_items text crispness shows
	LLMClient.use_stub = true
	TTSClient.enabled = false
	Game.start_lesson("test", 120.0)
	var enc: Control = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(enc)
	await get_tree().process_frame
	enc.setup({"persona_id": "noah_g5_fractions", "display_name": "Noah"})
	await get_tree().create_timer(0.3).timeout
	await _save("shot_enc_menu.png")
	# switch to type mode
	enc._toggle_input_mode()
	enc._text_input.text = "Can you walk me through how you got that?"
	await get_tree().create_timer(0.3).timeout
	await _save("shot_enc_type.png")
	# drive to resolution to capture the competency panel
	enc._toggle_input_mode()
	var mix := ["elicit", "extend", "elicit", "wait", "extend", "elicit", "revoice", "elicit", "extend"]
	for m in mix:
		if enc._resolved:
			break
		enc._on_move(m)
		await get_tree().process_frame
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _save("shot_enc_competency.png")
	get_tree().quit()

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + name)
	print("saved ", name, " ", img.get_size())
