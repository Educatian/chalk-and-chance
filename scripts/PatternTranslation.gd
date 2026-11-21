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
		for m in found:
			rx += _escape(src.substr(last, m.get_start() - last))
			rx += "%" if m.get_string() == "%%" else "(.+?)"
			last = m.get_end()
		rx += _escape(src.substr(last)) + "$"
		var re := RegEx.new()
		if re.compile(rx) == OK:
			_patterns.append([re, ko])
	return true

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _exact.has(s):
		return StringName(_exact[s])
	if s.length() < 3 or _miss.has(s) or not _has_letters(s):
		return StringName()
	for p in _patterns:
		var m: RegExMatch = (p[0] as RegEx).search(s)
		if m != null:
			return StringName(_fill(str(p[1]), m))
	# "Coach Vee: " + tip, "Next: " + target ...: translate the prefix and the rest apart.
	var cut := s.find(": ")
	if cut > 0:
		var head := s.substr(0, cut + 2)
		var lead := str(_exact.get(head, _exact.get(head.strip_edges(), "")))
		if lead != "":
			var rest := s.substr(cut + 2)
			var tail := String(_get_message(StringName(rest), _context))
			return StringName((lead if lead.ends_with(" ") else lead + " ") + (tail if tail != "" else rest))
	if _miss.size() > 4000:
		_miss.clear()
	_miss[s] = true
	return StringName()

## Put the captured values into the translated template's placeholders, in order.
func _fill(tmpl: String, m: RegExMatch) -> String:
	var ph := RegEx.new()
	ph.compile(_PH)
	var out := ""
	var last := 0
	var i := 1
	for p in ph.search_all(tmpl):
		out += tmpl.substr(last, p.get_start() - last)
		if p.get_string() == "%%":
			out += "%"
		else:
			out += m.get_string(i) if i <= m.get_group_count() else ""
			i += 1
		last = p.get_end()
	return out + tmpl.substr(last)

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
