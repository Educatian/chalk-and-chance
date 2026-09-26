extends RefCounted
## Multi-path, context-sensitive move judging for one student.
##
## Each persona lists 2-3 defensible "paths" (data/persona_library/*.json -> "paths"):
##   {"id": "diagnose", "label": "Diagnose, then press",
##    "steps": [["elicit"], ["extend", "revoice"]], "why": "..."}
## A move ADVANCES a path when it is in that path's current step; it is EARLY when it
## belongs to a later step (right idea, wrong moment); otherwise it MISSES. Repeating
## the same move back-to-back earns half credit, so button-mashing one "key" stops
## working (Kavanagh et al., 2020: rehearsal should build responsiveness, not scripts).
## Personas without "paths" fall back to one path built from win_moves (legacy rules).

const CREDIT := 0.12
const EARLY_CREDIT := 0.03

var paths: Array = []
var progress: Dictionary = {}   # path id -> step index reached
var _last_tag := ""
var _streak := 0

static func for_persona(persona: Dictionary, win_moves_fallback: Array = []) -> RefCounted:
	var pj = load("res://scripts/PathJudge.gd").new()
	var raw = persona.get("paths", [])
	if typeof(raw) == TYPE_ARRAY and not raw.is_empty():
		for p in raw:
			if typeof(p) == TYPE_DICTIONARY and not (p.get("steps", []) as Array).is_empty():
				pj.paths.append(p)
	if pj.paths.is_empty():
		var wm: Array = win_moves_fallback if not win_moves_fallback.is_empty() else persona.get("win_moves", [])
		pj.paths.append({"id": "core", "label": "Core move", "steps": [wm, wm]})
	for p in pj.paths:
		pj.progress[str(p["id"])] = 0
	return pj

## Every move that can advance some path (kept for payloads, hints and competency).
func all_moves() -> Array:
	var out: Array = []
	for p in paths:
		for step in p["steps"]:
			for t in step:
				if not out.has(t):
					out.append(t)
	return out

## -> {fit: advance|early|miss, credit, path_id, path_label, done, note}
func evaluate(tag: String, wait_ok: bool = true) -> Dictionary:
	if tag == _last_tag:
		_streak += 1
	else:
		_streak = 0
	_last_tag = tag
	var res := {"fit": "miss", "credit": 0.0, "path_id": "", "path_label": "", "done": false, "note": ""}
	if tag == "" or tag == "tell" or (tag == "wait" and not wait_ok):
		if tag == "wait":
			res["note"] = "the pause was under three seconds"
		return res
	# The student's stage is the furthest step reached on ANY path: once their thinking
	# is surfaced, every path's moves up to that stage fit. Moves that only belong to
	# later steps are "early" (right idea, wrong moment).
	var stage := 0
	for p in paths:
		stage = maxi(stage, int(progress[str(p["id"])]))
	var best := -1
	var best_step := -1
	for i in range(paths.size()):
		var steps: Array = paths[i]["steps"]
		var top := mini(stage, steps.size() - 1)
		for k in range(top, -1, -1):
			if tag in steps[k]:
				if k > best_step:
					best = i
					best_step = k
				break
	if best >= 0:
		var p: Dictionary = paths[best]
		var pid := str(p["id"])
		var n_steps := (p["steps"] as Array).size()
		progress[pid] = mini(maxi(int(progress[pid]), best_step + 1), n_steps)
		res["fit"] = "advance"
		res["credit"] = CREDIT * (0.5 if _streak >= 1 else 1.0)
		res["path_id"] = pid
		res["path_label"] = str(p.get("label", pid))
		res["done"] = int(progress[pid]) >= n_steps
		if _streak >= 1:
			res["note"] = "same move twice in a row, so it landed softer"
		return res
	for p in paths:
		var steps: Array = p["steps"]
		for later in range(mini(stage, steps.size() - 1) + 1, steps.size()):
			if tag in steps[later]:
				res["fit"] = "early"
				res["credit"] = EARLY_CREDIT
				res["path_id"] = str(p["id"])
				res["path_label"] = str(p.get("label", ""))
				res["note"] = "right idea, too early: first %s" % _step_hint(_openers())
				return res
	return res

## Moves that open at least one path (what to do before a "later" move).
func _openers() -> Array:
	var out: Array = []
	for p in paths:
		for t in (p["steps"] as Array)[0]:
			if not out.has(t):
				out.append(t)
	return out

## The path with the most progress, and the other paths the player could have taken.
func summary() -> Dictionary:
	var taken := {}
	var best := 0
	for p in paths:
		var n := int(progress[str(p["id"])])
		if n > best:
			best = n
			taken = p
	var others: Array = []
	for p in paths:
		if p != taken:
			others.append(str(p.get("label", "")))
	return {"taken": str(taken.get("label", "")), "taken_why": str(taken.get("why", "")), "others": others}

func _step_hint(step: Array) -> String:
	var names: Array = []
	for t in step:
		names.append(str(t).capitalize())
	return " or ".join(names)
