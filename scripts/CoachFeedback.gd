extends RefCounted
## Between-round coaching (Cohen et al. 2020/2024 coached-rehearsal model): name ONE
## move that worked, ONE missed opportunity with the better alternative and a sentence
## starter, call out a repeated anti-pattern, and set ONE measurable focus for an
## immediate re-rehearsal. Input is the per-turn move history every mode already keeps:
## {turn, tag, targets, construct, reaction, meter, student?, note?}.

## Per-tag coaching content. "better" names the alternative move tag for a miss.
const MOVES := {
	# 1:1 encounter / gym
	"elicit": {"label": "Elicit", "glow": "You asked for their reasoning instead of supplying it. Now their thinking is visible, and you can teach to it.",
		"miss": "The question came before they were ready, so it didn't open anything up.", "better": "wait",
		"starter": "\"Walk me through how you got that.\""},
	"extend": {"label": "Extend", "glow": "You pushed on an idea that was already out there. That's how a partial answer turns into an argument.",
		"miss": "You pushed before there was an idea on the table to push on.", "better": "elicit",
		"starter": "\"Say more. Why does that work?\""},
	"revoice": {"label": "Revoice", "glow": "You said their idea back to them in clearer words, and they kept ownership of it.",
		"miss": "You restated an idea nobody had actually said yet.", "better": "elicit",
		"starter": "\"So you're saying... did I get that right?\""},
	"tell": {"label": "Tell", "glow": "You gave a direct explanation at a point where they needed it.",
		"miss": "You gave the answer, and their reasoning never came out. Now you don't know what they understand.", "better": "elicit",
		"starter": "\"Before I show you, what's your hunch, and why?\""},
	"praise": {"label": "Praise", "glow": "You named exactly what they did, so they know what to do again.",
		"miss": "The praise was about the person, not about what they did, so it doesn't tell them anything.", "better": "praise",
		"starter": "\"You checked your answer against the picture. That's what careful mathematicians do.\""},
	"connect": {"label": "Connect", "glow": "You tied the lesson to something they already know from their own life. That's a strength to build on.",
		"miss": "The connection felt forced because you didn't know enough about them yet.", "better": "elicit",
		"starter": "\"Where have you seen something split into equal parts before?\""},
	"redirect": {"label": "Redirect", "glow": "You redirected the behavior quietly and in proportion, and the lesson kept going.",
		"miss": "The redirect was stronger than the moment called for. Try a quieter step first.", "better": "redirect",
		"starter": "(Move closer, make eye contact, then a quiet: \"Pencil on problem two, please.\")"},
	"wait": {"label": "Wait", "glow": "You held the silence. That time is where their thinking happened.",
		"miss": "You moved on before the thinking time was over.", "better": "wait",
		"starter": "(Count three in your head. Then: \"Take your time.\")"},
	# lecture
	"present": {"label": "Present", "glow": "You kept it short, so the room could keep up.",
		"miss": "Too many Presents in a row. You were talking into confusion you couldn't see.", "better": "poll",
		"starter": "(One idea, under a minute. Then stop and check.)"},
	"ask": {"label": "Question", "glow": "You asked at the right moment, so their answer showed you what they understood.",
		"miss": "The question came while the room was still confused, so it only exposed that confusion without fixing it.", "better": "reexplain",
		"starter": "\"Who can explain why the denominator names the parts?\""},
	"reexplain": {"label": "Repair", "glow": "You noticed confusion and fixed it before moving on.",
		"miss": "You re-explained when there wasn't much confusion to fix.", "better": "ask",
		"starter": "\"Let me show it a different way, with the fraction strips.\""},
	"poll": {"label": "Check", "glow": "You checked the whole room, and now you have evidence instead of a guess.",
		"miss": "The check didn't lead to anything. Use what it shows you.", "better": "reexplain",
		"starter": "\"Thumbs up, sideways, or down: which fraction is bigger, 1/3 or 1/4?\""},
	# group check-in
	"observe": {"label": "Observe", "glow": "You watched before stepping in, so your next move fit the group.",
		"miss": "You watched for too long. The mistake was already out there.", "better": "press",
		"starter": "(Stand back, listen for 20 seconds, then step in.)"},
	"probe": {"label": "Probe", "glow": "Your probe brought the group's hidden misconception out into the open.",
		"miss": "You probed a group that had already shown its thinking.", "better": "press",
		"starter": "\"How did you all decide that?\""},
	"press": {"label": "Press", "glow": "You pressed on the shared mistake once everyone could see it.",
		"miss": "You pressed before the mistake was out in the open. Probe first.", "better": "probe",
		"starter": "\"Eight is bigger than four, but is an eighth bigger than a fourth?\""},
	"redistribute": {"label": "Redistribute", "glow": "You gave the floor to a quieter voice. That changes who gets to think out loud.",
		"miss": "Everyone was already getting a turn, so there was nothing to rebalance.", "better": "probe",
		"starter": "\"Sam, what do you think about Talia's idea?\""},
}

## -> {glow, grow, pattern, focus, summary}. Empty dict when there is nothing to coach.
static func analyze(moves: Array) -> Dictionary:
	var clean: Array = []
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("tag", "")) != "":
			clean.append(m)
	if clean.is_empty():
		return {}
	var glow := {}
	var grow := {}
	var misses_by_tag := {}
	for m in clean:
		var tag := str(m["tag"])
		var ok := bool(m.get("targets", false))
		if ok and glow.is_empty():
			glow = _line(m, true)
		if not ok:
			misses_by_tag[tag] = int(misses_by_tag.get(tag, 0)) + 1
			if grow.is_empty():
				grow = _line(m, false)
	# Prefer the LAST productive move as the glow (most recent success is most memorable).
	for i in range(clean.size() - 1, -1, -1):
		if bool(clean[i].get("targets", false)):
			glow = _line(clean[i], true)
			break
	var pattern := ""
	var worst_tag := ""
	var worst_n := 0
	for tag in misses_by_tag:
		if int(misses_by_tag[tag]) > worst_n:
			worst_n = int(misses_by_tag[tag])
			worst_tag = str(tag)
	if worst_n >= 3:
		var alt := str(MOVES.get(worst_tag, {}).get("better", ""))
		if alt == worst_tag:
			pattern = "You used %s %d times and it didn't land. It's not the move, it's how you're using it. See the example below." % [_label(worst_tag), worst_n]
		else:
			pattern = "You fell back on %s %d times and it didn't land. Next time, try %s instead." % [
				_label(worst_tag), worst_n, _label(alt)]
	var focus := _focus_for(grow, worst_tag, worst_n)
	var hits := 0
	for m in clean:
		if bool(m.get("targets", false)):
			hits += 1
	return {
		"glow": glow, "grow": grow, "pattern": pattern, "focus": focus,
		"ways": _ways_lines(clean),
		"summary": "%d of %d moves landed" % [hits, clean.size()],
	}

## "Other ways in": for each student reached, name the path the player took and the
## other defensible paths (qualitative consensus: rarely one right move).
static func _ways_lines(moves: Array) -> Array:
	var taken := {}   # student -> path label
	var order: Array = []
	for m in moves:
		var who := str(m.get("student", ""))
		if who == "" or not bool(m.get("targets", false)) or str(m.get("path", "")) in ["", "Core move"]:
			continue
		if not taken.has(who):
			order.append(who)
		taken[who] = str(m["path"])
	var lines: Array = []
	for who in order.slice(0, 2):
		var others: Array = []
		for p in _persona_paths(who):
			var label := str(p.get("label", ""))
			if label != taken[who]:
				others.append(label)
		var line := "%s: you took \"%s\"." % [who, taken[who]]
		if not others.is_empty():
			line += "  Also works: " + "  ·  ".join(others)
		lines.append(line)
	return lines

static func _persona_paths(student_name: String) -> Array:
	var key := student_name.to_lower().split(" ")[0].replace("-", "")
	var dir := DirAccess.open("res://data/persona_library")
	if dir == null:
		return []
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/persona_library/" + f))
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var disp := str(d.get("display_name", "")).to_lower().split(" ")[0].replace("-", "")
		if disp == key or f.begins_with(key):
			return d.get("paths", [])
	return []

## Did the player meet a previously set focus in this round's moves?
static func focus_met(focus: Dictionary, moves: Array) -> Dictionary:
	if focus.is_empty():
		return {}
	var tag := str(focus.get("tag", ""))
	var need := int(focus.get("count", 1))
	var got := 0
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("tag", "")) == tag and bool(m.get("targets", false)):
			got += 1
	return {"met": got >= need, "got": got, "need": need, "text": str(focus.get("text", ""))}

static func _line(m: Dictionary, ok: bool) -> Dictionary:
	var tag := str(m.get("tag", ""))
	var info: Dictionary = MOVES.get(tag, {})
	var who := str(m.get("student", ""))
	var when := "Turn %d" % int(m.get("turn", 0))
	if who != "":
		when += ", with %s" % who
	var d := {
		"turn": int(m.get("turn", 0)), "tag": tag, "label": _label(tag), "when": when,
		"text": str(info.get("glow" if ok else "miss", "")),
		"note": str(m.get("note", "")),
	}
	if not ok and str(m.get("fit", "")) == "early":
		var nxt := str(m.get("note", "")).get_slice("first ", 1).get_slice(" ", 0).to_lower()
		d["text"] = "That move works for %s, just not yet. Set it up first." % (who if who != "" else "this student")
		d["note"] = ""
		d["better"] = nxt
		d["better_label"] = _label(nxt) + " first"
		d["starter"] = str(MOVES.get(nxt, {}).get("starter", info.get("starter", "")))
	elif not ok:
		var better := str(info.get("better", ""))
		d["better"] = better
		d["better_label"] = _label(better)
		d["starter"] = str(MOVES.get(better, {}).get("starter", info.get("starter", "")))
	return d

static func _focus_for(grow: Dictionary, worst_tag: String, worst_n: int) -> Dictionary:
	var tag := ""
	if worst_n >= 2:
		tag = str(MOVES.get(worst_tag, {}).get("better", ""))
	elif not grow.is_empty():
		tag = str(grow.get("better", ""))
	if tag == "":
		return {}
	var count := 2
	return {"tag": tag, "count": count,
		"text": "Make %d %s moves land this time." % [count, _label(tag)]}

static func _label(tag: String) -> String:
	return str(MOVES.get(tag, {}).get("label", tag.capitalize()))
