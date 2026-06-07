extends RefCounted

const WIDTH := 392.0
const HEIGHT := 34.0

static func show_group_cue(parent: Node, previous: Control, pos: Vector2, understanding: float, participation: float, revealed: bool) -> Control:
	var created := previous == null or not is_instance_valid(previous)
	var cue := _new_cue(parent) if created else previous
	cue.name = "ReactionCue"
	cue.position = pos
	cue.set_meta("qa_container_rect", Rect2(pos, cue.size))
	var cue_text := _group_text(understanding, participation, revealed)
	var changed := created
	var swatch := cue.get_node_or_null("ReactionCueSwatch") as ColorRect
	if swatch != null:
		swatch.color = _group_color(understanding, participation, revealed)
	var label := cue.get_node_or_null("ReactionCueText") as Label
	if label != null:
		changed = changed or label.text != cue_text
		label.text = cue_text
		label.add_theme_font_size_override("font_size", 12 + GameState.ui_font_delta())

	if changed and not bool(GameState.get_setting("reduced_motion")):
		cue.modulate.a = 0.0
		cue.scale = Vector2(0.98, 0.98)
		var tween := cue.create_tween()
		tween.tween_property(cue, "modulate:a", 1.0, 0.16)
		tween.parallel().tween_property(cue, "scale", Vector2.ONE, 0.16)
	return cue

static func _new_cue(parent: Node) -> Control:
	var cue := Panel.new()
	cue.name = "ReactionCue"
	cue.size = Vector2(WIDTH, HEIGHT)
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cue)

	var swatch := ColorRect.new()
	swatch.name = "ReactionCueSwatch"
	swatch.position = Vector2(10, 9)
	swatch.size = Vector2(16, 16)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.add_child(swatch)

	var label := Label.new()
	label.name = "ReactionCueText"
	label.position = Vector2(34, 6)
	label.size = Vector2(WIDTH - 46.0, 22)
	label.clip_text = true
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 0.93))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.add_child(label)
	return cue

static func _group_text(understanding: float, participation: float, revealed: bool) -> String:
	if not revealed:
		return "Read the table: hidden group state"
	if participation < 0.55:
		return "Airtime imbalance: invite a quieter voice"
	if understanding < 0.55:
		return "Shared misconception: press for reasoning"
	return "Group momentum: ready to consolidate"

static func _group_color(understanding: float, participation: float, revealed: bool) -> Color:
	if not revealed:
		return Color(0.92, 0.70, 0.36)
	if participation < 0.55:
		return Color(0.52, 0.74, 0.96)
	if understanding < 0.55:
		return Color(0.95, 0.56, 0.45)
	return Color(0.46, 0.86, 0.55)
