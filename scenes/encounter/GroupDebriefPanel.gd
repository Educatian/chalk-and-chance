extends RefCounted

const CompletionFx = preload("res://scenes/encounter/CompletionFx.gd")

static func show(parent: Node, run_record: Dictionary, reward: Dictionary, context: Dictionary, on_continue: Callable) -> Control:
	var overlay := Control.new()
	overlay.name = "GroupComplete"
	parent.add_child(overlay)

	var panel := Panel.new()
	panel.position = Vector2(66, 156)
	panel.size = Vector2(874, 368)
	overlay.add_child(panel)
	CompletionFx.add_completion_burst(overlay, Rect2(panel.position, panel.size), true)

	var understanding := float(context.get("understanding", 0.0))
	var participation := float(context.get("participation", 0.0))
	_label(overlay, "GROUP DEBRIEF", Vector2(96, 194), 18, Color(0.97, 0.95, 0.86), Vector2(760, 26))
	_label(overlay, "CLEARED   |   Score %03d   |   Rank %s" % [
		int(run_record.get("score", context.get("score", 0))),
		str(run_record.get("rank", "-")),
	], Vector2(96, 242), 13, Color(0.96, 0.86, 0.50), Vector2(760, 22))
	_label(overlay, _reward_line(reward, context), Vector2(96, 288), 13, Color(0.72, 0.82, 0.96), Vector2(760, 22))
	_label(overlay, "Drivers: monitor %d | press %d | balance %d" % [
		int(round(understanding * 80.0)),
		int(round(understanding * 60.0)),
		int(round(participation * 120.0)),
	], Vector2(96, 326), 13, Color(0.72, 0.82, 0.96), Vector2(760, 22))
	var trace_line := str(run_record.get("evidence_trace", ""))
	_label(overlay, "Trace: " + (trace_line if trace_line != "" else "no scored move trace"), Vector2(96, 374), 13, Color(0.72, 0.78, 0.88), Vector2(760, 24))
	_label(overlay, "Focus: sample reasoning, press the shared error, rebalance airtime.", Vector2(96, 398), 13, Color(0.72, 0.78, 0.88), Vector2(760, 24))
	_label(overlay, Game.evidence_practice_target(false), Vector2(96, 422), 13, Color(0.72, 0.92, 0.78), Vector2(600, 22))

	var cont := Button.new()
	cont.text = "Return to room"
	cont.position = Vector2(720, 448)
	cont.size = Vector2(184, 64)
	cont.add_theme_font_size_override("font_size", 16)
	cont.pressed.connect(on_continue)
	overlay.add_child(cont)
	cont.grab_focus()
	return overlay

static func _reward_line(reward: Dictionary, context: Dictionary) -> String:
	var line := "Understanding %d%% | Participation %d%% | Revealed" % [
		int(round(float(context.get("understanding", 0.0)) * 100.0)),
		int(round(float(context.get("participation", 0.0)) * 100.0)),
	]
	var badge := str(context.get("target_badge", ""))
	if badge != "":
		line += " | Badge %s" % badge.to_upper()
	if bool(reward.get("level_up", false)):
		line += " | Level %d | +upgrade" % int(reward.get("level_after", GameState.teacher_level))
	if _items_awarded_text(reward.get("items_awarded", {})) != "":
		line += " | +items"
	return line

static func _items_awarded_text(items) -> String:
	if typeof(items) != TYPE_DICTIONARY:
		return ""
	var parts: Array = []
	for id in items.keys():
		var amt := int(items[id])
		if amt > 0:
			parts.append("%s x%d" % [Items.short_name_for(str(id)), amt])
	return ", ".join(parts)

static func _label(parent: Node, text: String, pos: Vector2, fs: int, color: Color, size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", fs + GameState.ui_font_delta())
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
