extends Translation
## UI catalogue for one language, keyed by the English text. Exact keys are looked up
## directly; text built in code with % formatting ("Lv %d", "%d of %d moves landed") is
## matched against the catalogue's templates and the values are carried into the
## translated template, so Labels and Buttons translate without wrapping every call.
## Catalogue: res://i18n/ui_<locale>.json ({english: translated}).

var _exact: Dictionary = {}
var _patterns: Array = []      # [RegEx, translated template, placeholder list]
var _miss: Dictionary = {}     # recent misses (HUD numbers update every frame)
const _PH := "%(?:[-0-9.]*)[sdfx%]"

func load_catalogue(path: String, loc: String) -> bool:
	locale = loc
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var ph := RegEx.new()
	ph.compile(_PH)
	for en in d.keys():
		var ko := str(d[en])
		_exact[str(en)] = ko
		var found := ph.search_all(str(en))
		var real := found.filter(func(m): return m.get_string() != "%%")
		if real.is_empty():
			continue
		# Template -> regex: escape the literal text, each placeholder captures a value.
		var src := str(en)
		var rx := "^"
		var last := 0
		var literal := src.length()
		for m in found:
			rx += _escape(src.substr(last, m.get_start() - last))
			var ph_s := m.get_string()
			literal -= ph_s.length()
			if ph_s == "%%":
				rx += "%"
			elif ph_s.ends_with("d"):
				rx += "(-?[0-9]+)"          # %d only ever holds a whole number
			elif ph_s.ends_with("f"):
				rx += "(-?[0-9.]+)"
			else:
				rx += "(.+?)"
			last = m.get_end()
		rx += _escape(src.substr(last)) + "$"
		var re := RegEx.new()
		if re.compile(rx) == OK:
			_patterns.append([re, ko, literal])
	# Most specific first: a short template like "Turn %d" must not swallow a longer line.
	_patterns.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	return true

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _exact.has(s):
		return StringName(_exact[s])
	if s.length() < 3 or _miss.has(s) or not _has_letters(s):
		return StringName()
	# Candidates: every matching template, plus "Prefix: rest". Each scores the number of
	# inserted values left in untranslated English; the lowest score wins (ties: the more
	# specific template, which comes first).
	var best := ""
	var best_pen := 1 << 30
	for p in _patterns:
		var m: RegExMatch = (p[0] as RegEx).search(s)
		if m == null:
			continue
		var r: Array = _fill(str(p[1]), m)
		if int(r[1]) < best_pen:
			best = str(r[0])
			best_pen = int(r[1])
			if best_pen == 0:
				break
	var cut := s.find(": ")
	if best_pen > 0 and cut > 0:
		var head := s.substr(0, cut + 2)
		var lead := str(_exact.get(head, _exact.get(head.strip_edges(), "")))
		if lead != "":
			var rest := s.substr(cut + 2).strip_edges(true, false)
			var tail := String(_get_message(StringName(rest), _context))
			var pen := 1 if (tail == "" and _has_letters(rest)) else 0
			if pen < best_pen:
				best = (lead if lead.ends_with(" ") else lead + " ") + (tail if tail != "" else rest)
				best_pen = pen
	if best != "":
		return StringName(best)
	if _miss.size() > 4000:
		_miss.clear()
	_miss[s] = true
	return StringName()

## Fill the translated template with the captured values, in order. %s values are
## translated too when they can be. -> [text, count of %s values left in English]
func _fill(tmpl: String, m: RegExMatch) -> Array:
	var ph := RegEx.new()
	ph.compile(_PH)
	var out := ""
	var last := 0
	var i := 1
	var pen := 0
	for p in ph.search_all(tmpl):
		out += tmpl.substr(last, p.get_start() - last)
		if p.get_string() == "%%":
			out += "%"
		else:
			var v := m.get_string(i) if i <= m.get_group_count() else ""
			if p.get_string().ends_with("s") and v.strip_edges() != "":
				var core := v.strip_edges(true, false)
				var tv := String(_get_message(StringName(core), &""))
				if tv != "":
					v = v.substr(0, v.length() - core.length()) + tv
				elif _has_letters(core):
					pen += 1
			out += v
			i += 1
		last = p.get_end()
	return [out + tmpl.substr(last), pen]

static func _escape(t: String) -> String:
	var out := ""
	for c in t:
		out += ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c
	return out

static func _has_letters(s: String) -> bool:
	for c in s:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			return true
	return false
