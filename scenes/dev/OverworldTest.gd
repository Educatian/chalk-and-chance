extends Node
## Headless build check for the overworld: instantiates it, runs two frames so all
## _ready paths execute (tiles, player AnimatedSprite2D, NPC walk frame, emotes, badge
## strip), then reports child count and quits. Catches parse/runtime errors.

func _ready() -> void:
	var ow: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(ow)
	await get_tree().process_frame
	await get_tree().process_frame
	print("OVERWORLD OK children=%d" % ow.get_child_count())
	var p = ow._player
	if p != null:
		var ct: Vector2i = p.current_tile()
		var up_ok: bool = ow.is_walkable(ct + Vector2i(0, -1))
		print("PLAYER tile=%d current_tile=%s walkable_up=%s" % [p.tile, str(ct), str(up_ok)])
	# Exercise the interrupt trigger + resolve path (can't click it in a screenshot).
	ow._trigger_interrupt()
	await get_tree().process_frame
	print("INTERRUPT locked=%s overlay=%s" % [str(ow.input_locked), str(ow._overlay != null)])
	ow._resolve_interrupt({"dcomp": -7.0, "dnoise": 6.0, "ddis": 1, "coach": "test"})
	await get_tree().process_frame
	print("RESOLVED locked=%s composure=%d disruptions=%d" % [str(ow.input_locked), int(ow._composure), ow._disruptions])
	# Persistence: save lesson state, load a fresh overworld, confirm it resumes.
	ow._period_left = 88.0
	ow._composure = 71.0
	ow._save_lesson_state()
	ow.queue_free()
	await get_tree().process_frame
	var ow3: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child(ow3)
	await get_tree().process_frame
	print("RESUME period=%.0f composure=%.0f (expect 88/71)" % [ow3._period_left, ow3._composure])
	get_tree().quit()
