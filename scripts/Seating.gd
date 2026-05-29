extends RefCounted
## Seat-tile presets for the 30x17 classroom grid (board at the top, y=0). Each preset
## returns an Array of Vector2i seat tiles; a desk is drawn one tile south of each seat, so
## seat rows are spaced to leave that overhang clear. Arrangement is chosen per scenario
## from the seating literature (SEATING_ARRANGEMENTS.md): rows for independent/lecture,
## ushape for discussion, clusters for group work.

static func seats_for(arrangement: String) -> Array:
	match arrangement:
		"ushape":
			return _ushape()
		"rows":
			return _rows()
		"clusters":
			return _clusters()
		"pairs":
			return _pairs()
	return _rows()

# Layouts fit a 24x13 grid (board at y=0; interior x 1..22, y 1..11). A desk is drawn one
# tile south of each seat, so seat rows stay <= y 10.

static func _ushape() -> Array:
	return [
		Vector2i(4, 3), Vector2i(4, 5), Vector2i(4, 7),         # left arm
		Vector2i(8, 9), Vector2i(11, 9), Vector2i(14, 9),       # back row
		Vector2i(18, 3), Vector2i(18, 5), Vector2i(18, 7),      # right arm
	]

static func _rows() -> Array:
	var out: Array = []
	for ry in [3, 6, 9]:
		for cx in [4, 8, 12, 16, 20]:
			out.append(Vector2i(cx, ry))
	return out

static func _pairs() -> Array:
	var out: Array = []
	for ry in [3, 7]:
		for cx in [4, 5, 10, 11, 16, 17]:
			out.append(Vector2i(cx, ry))
	return out

static func _clusters() -> Array:
	var out: Array = []
	for base in [Vector2i(4, 3), Vector2i(15, 3), Vector2i(4, 8), Vector2i(15, 8)]:
		out.append(base)
		out.append(base + Vector2i(2, 0))
		out.append(base + Vector2i(0, 2))
		out.append(base + Vector2i(2, 2))
	return out
