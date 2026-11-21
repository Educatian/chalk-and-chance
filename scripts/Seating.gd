extends RefCounted
## Seat-tile presets for the 24x13 classroom grid (board at the top, y=0). Each preset
## returns an Array of Vector2i seat tiles; a desk is drawn on the seat tile itself (no
## overhang). Arrangement is chosen per scenario
## from the seating literature (SEATING_ARRANGEMENTS.md): rows for independent/lecture,
## ushape for discussion, clusters for group work.

static func seats_for(arrangement: String) -> Array:
	match arrangement:
		"ushape":
			return _ushape()
		"ushape6":
			return _ushape6()
		"clusters8":
			return _clusters8()
		"rows8":
			return _rows8()
		"rows":
			return _rows()
		"clusters":
			return _clusters()
		"pairs":
			return _pairs()
	return _rows()

# Layouts fit a 24x13 grid (board at y=0; interior x 1..22, y 1..11). A desk is drawn on
# the seat tile itself, so seats stay within y 1..11.

static func _ushape() -> Array:
	return [
		Vector2i(4, 3), Vector2i(4, 5), Vector2i(4, 7),         # left arm
		Vector2i(8, 9), Vector2i(11, 9), Vector2i(14, 9),       # back row
		Vector2i(18, 3), Vector2i(18, 5), Vector2i(18, 7),      # right arm
	]

## Tight 6-seat U for 6-learner discussions (owner-approved 2026-11-21): every desk is
## occupied and the U fills the room's middle while keeping aisles to walk.
static func _ushape6() -> Array:
	return [
		Vector2i(7, 4), Vector2i(7, 6),      # left arm
		Vector2i(10, 8), Vector2i(13, 8),    # back row
		Vector2i(16, 4), Vector2i(16, 6),    # right arm
	]

## Two full pods of 4 for 8-learner group work (owner-approved 2026-11-21).
static func _clusters8() -> Array:
	return [
		Vector2i(7, 5), Vector2i(9, 5), Vector2i(7, 7), Vector2i(9, 7),       # left pod
		Vector2i(14, 5), Vector2i(16, 5), Vector2i(14, 7), Vector2i(16, 7),   # right pod
	]

## Two rows of 4 with a centre aisle for 8-learner independent work (owner-approved).
static func _rows8() -> Array:
	return [
		Vector2i(6, 5), Vector2i(8, 5), Vector2i(15, 5), Vector2i(17, 5),
		Vector2i(6, 8), Vector2i(8, 8), Vector2i(15, 8), Vector2i(17, 8),
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
