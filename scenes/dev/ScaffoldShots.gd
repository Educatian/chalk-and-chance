extends Node
## Dev: the same encounter at Full vs Light support -> tools/cine/scaffold_*.png

func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	LLMClient.use_stub = true
	TTSClient.enabled = false
	GameState.settings["reduced_motion"] = true
	GameState.settings["text_reveal"] = "instant"
	for lvl in ["full", "light"]:
		Competency.reset_estimates()
		if lvl == "light":
			for sk in ["revoicing", "extend_thinking", "elicit_reasoning", "funds_of_knowledge"]:
				Competency.n[sk] = 6
				Competency.theta[sk] = 0.9
		Game.start_lesson("culturally_responsive_intro", 120.0)
		Game.current_scenario_id = "culturally_responsive_intro"
		var enc: Node = load("res://scenes/encounter/Encounter.tscn").instantiate()
		add_child(enc)
		await get_tree().process_frame
		enc.setup({"persona_id": "jordan_skeptic", "display_name": "Jordan"})
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("res://tools/cine/scaffold_%s.png" % lvl)
		print("saved ", lvl)
		enc.queue_free()
		await get_tree().process_frame
	get_tree().quit()
