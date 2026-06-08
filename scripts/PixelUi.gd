extends RefCounted
## Converts a low-resolution authored UI tree to full-resolution coordinates without
## scaling the CanvasItem tree. Text stays crisp because font sizes are rendered at the
## final size instead of being enlarged after rasterization.

static func scale_tree(root: Node, factor: float) -> void:
	if root == null or factor <= 1.0:
		return
	_scale_node(root, factor)

static func _scale_node(node: Node, factor: float) -> void:
	if node is Control:
		var c := node as Control
		c.position = _snap(c.position * factor)
		c.size = _snap(c.size * factor)
		c.custom_minimum_size = _snap(c.custom_minimum_size * factor)
		if c.has_theme_font_size_override("font_size"):
			c.add_theme_font_size_override("font_size", maxi(1, roundi(float(c.get_theme_font_size("font_size")) * factor)))
		if c is NinePatchRect:
			var np := c as NinePatchRect
			np.patch_margin_left = roundi(float(np.patch_margin_left) * factor)
			np.patch_margin_right = roundi(float(np.patch_margin_right) * factor)
			np.patch_margin_top = roundi(float(np.patch_margin_top) * factor)
			np.patch_margin_bottom = roundi(float(np.patch_margin_bottom) * factor)
	elif node is Node2D:
		var n2 := node as Node2D
		n2.position = _snap(n2.position * factor)
		n2.scale *= factor
	for child in node.get_children():
		_scale_node(child, factor)

static func _snap(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x), roundf(v.y))

static func add_centered_icon(parent: Control, tex: Texture2D, inset: float = 3.0) -> TextureRect:
	if parent == null or tex == null:
		return null
	var icon := TextureRect.new()
	icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(inset, inset)
	icon.size = Vector2(maxf(1.0, parent.size.x - inset * 2.0), maxf(1.0, parent.size.y - inset * 2.0))
	parent.add_child(icon)
	return icon
