extends RefCounted
## Asset loader with graceful fallback. Used via `const Art = preload(...)` in consumers
## (preload avoids relying on the global class-name cache, which is only built by an
## editor scan and is missing on a fresh headless launch). Returns a Texture2D if the file exists and is
## imported, else null so callers can fall back to placeholder ColorRects. This lets
## imagegen2 PNGs drop into assets/ and light up the game with no code change.
## See ASSET_PROMPTS.md for the expected files and the Pokemon-style art spec.

static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)   # Variant; do not use :=
		if res is Texture2D:
			return res
	return null

static func scenario_backdrop_path(cfg: Dictionary, scenario_id: String = "", thumb: bool = false) -> String:
	var key := "backdrop_thumb" if thumb else "backdrop"
	var p := str(cfg.get(key, ""))
	if p != "":
		return p
	var id := str(cfg.get("id", scenario_id))
	if id != "":
		var candidate := "res://assets/backdrops/%s%s.png" % [id, "_thumb" if thumb else ""]
		if ResourceLoader.exists(candidate):
			return candidate
	var fmt := str(cfg.get("format", "discussion"))
	match fmt:
		"lecture": return "res://assets/backdrops/lecture_fractions%s.png" % ("_thumb" if thumb else "")
		"group_work": return "res://assets/backdrops/group_work_fractions%s.png" % ("_thumb" if thumb else "")
		"independent": return "res://assets/backdrops/independent_fractions%s.png" % ("_thumb" if thumb else "")
		_: return "res://assets/backdrops/discussion_fractions%s.png" % ("_thumb" if thumb else "")

## Bounding box (region-local) of the non-transparent pixels inside `region` of a texture.
## Used to normalize character size by the DRAWN figure, not the cell (figures fill cells
## unevenly, which made on-screen heights inconsistent).
static func opaque_bounds(t: Texture2D, region: Rect2i) -> Rect2i:
	if t == null:
		return region
	var img := t.get_image()
	if img == null:
		return Rect2i(0, 0, region.size.x, region.size.y)
	if img.is_compressed():
		img.decompress()
	var minx := region.size.x
	var miny := region.size.y
	var maxx := -1
	var maxy := -1
	for y in range(region.size.y):
		for x in range(region.size.x):
			if img.get_pixel(region.position.x + x, region.position.y + y).a > 0.12:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, region.size.x, region.size.y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
