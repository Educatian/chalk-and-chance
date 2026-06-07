extends RefCounted

const Art = preload("res://scripts/Art.gd")
const ReactionCue = preload("res://scenes/encounter/ReactionCue.gd")

const MOVES := [
	["Observe", "observe"], ["Probe", "probe"], ["Press", "press"],
	["Redistribute", "redistribute"], ["Move on", "move_on"],
]

static func build(host: Node, shared_concept: String, members: Array, understanding: float, participation: float, revealed: bool, on_move: Callable) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)

	var layer := Control.new()
	host.add_child(layer)
	var title := label(layer, "Group check-in  -  %s" % shared_concept, Vector2(20, 14), 18, Color(0.96, 0.86, 0.55))
	title.size = Vector2(900, 22)

	var member_box := HBoxContainer.new()
	member_box.position = Vector2(20, 48)
	member_box.add_theme_constant_override("separation", 16)
	layer.add_child(member_box)
	populate_members(member_box, members)

	var status_lbl := label(layer, "Status: hidden (observe or probe to surface it)", Vector2(20, 188), 13, Color(0.8, 0.84, 0.9))
	status_lbl.size = Vector2(920, 16)
	var reaction_cue := ReactionCue.show_group_cue(layer, null, Vector2(536, 212), understanding, participation, revealed)
	label(layer, "Group understanding", Vector2(20, 214), 12, Color(0.86, 0.9, 0.96)).size = Vector2(210, 14)
	var u_bar := bar(layer, Vector2(250, 216), Color(0.35, 0.78, 0.42))
	label(layer, "Participation balance", Vector2(20, 238), 12, Color(0.86, 0.9, 0.96)).size = Vector2(210, 14)
	var p_bar := bar(layer, Vector2(250, 240), Color(0.55, 0.72, 0.95))

	var dialogue_box := Rect2(Vector2(16, 264), Vector2(928, 76))
	var dialogue_text := Rect2(Vector2(28, 276), Vector2(904, 48))
	var dbg := ColorRect.new()
	dbg.name = "DialogueBubble"
	dbg.position = dialogue_box.position
	dbg.size = dialogue_box.size
	dbg.color = Color(0.10, 0.13, 0.23, 0.88)
	dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dbg)

	var dialogue := label(layer, "", dialogue_text.position, 15, Color(0.97, 0.97, 0.93))
	dialogue.name = "DialogueText"
	dialogue.size = dialogue_text.size
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.set_meta("qa_container_rect", dialogue_box)
	dialogue.set_meta("qa_text_rect", dialogue_text)
	dialogue.set_meta("qa_min_padding", 8.0)
	var coach := label(layer, "", Vector2(20, 346), 12, Color(0.62, 0.86, 0.62))
	coach.size = Vector2(920, 44)
	coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var buttons := []
	var x := 20.0
	for mv in MOVES:
		var button := Button.new()
		button.text = mv[0]
		button.position = Vector2(x, 402)
		button.size = Vector2(170, 42)
		button.pressed.connect(on_move.bind(mv[1]))
		layer.add_child(button)
		buttons.append(button)
		x += 178
	return {
		"layer": layer, "member_box": member_box, "status_lbl": status_lbl,
		"reaction_cue": reaction_cue, "u_bar": u_bar, "p_bar": p_bar,
		"dialogue": dialogue, "coach": coach, "buttons": buttons,
	}

static func populate_members(member_box: HBoxContainer, members: Array) -> void:
	for child in member_box.get_children():
		child.queue_free()
	for member in members:
		var col := VBoxContainer.new()
		var tex := Art.tex("res://assets/portraits/%s_neutral.png" % member.get("persona_id", ""))
		if tex != null:
			var portrait := TextureRect.new()
			portrait.texture = tex
			portrait.custom_minimum_size = Vector2(72, 72)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			col.add_child(portrait)
		var name_label := Label.new()
		name_label.text = str(member.get("name", "?"))
		name_label.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(name_label)
		member_box.add_child(col)

static func label(parent: Node, txt: String, pos: Vector2, fs: int, col: Color) -> Label:
	var out := Label.new()
	out.text = txt
	out.position = pos
	out.add_theme_font_size_override("font_size", fs)
	out.add_theme_color_override("font_color", col)
	parent.add_child(out)
	return out

static func bar(parent: Node, pos: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = pos
	bg.size = Vector2(220, 12)
	bg.color = Color(0, 0, 0, 0.5)
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.position = pos
	fill.size = Vector2(0, 12)
	fill.color = col
	parent.add_child(fill)
	return fill
