extends RefCounted
## Skill-contingent scaffolding (van de Pol, Volman & Beishuizen, 2010; Chernikova et al.,
## 2020: novices need worked support, more knowledgeable learners need it withdrawn).
## Support is set from the learner's MEASURED competency on the skills this encounter
## exercises, not from chapter progress:
##
##   FULL    Need line, move explanations on hover, guide line, sentence starter, wait bar + timer
##   PARTIAL Need line, move explanations on hover, wait bar + timer
##   LIGHT   Student cue only ("read the student"), wait bar without timer text
##   OFF     No need line, no hover help, no wait bar: you count the pause yourself
##
## Contingency: three misses in a row temporarily restores support ("Coach Vee steps in"),
## and one fitting move hands control back.

const OFF := 0
const LIGHT := 1
const PARTIAL := 2
const FULL := 3
const NAMES := ["Off", "Light", "Partial", "Full"]
const MIN_EVIDENCE := 4
const OFF_EVIDENCE := 8
const STEP_IN_AFTER := 3

## -> {level, name, prob, evidence, reason}
static func level_for(skills: Array) -> Dictionary:
	var total_w := 0.0
	var wp := 0.0
	var ev := 0
	for s in skills:
		var sid := str(s)
		var n := int(Competency.n.get(sid, 0))
		if n <= 0:
			continue
		var w := float(mini(n, 12))
		total_w += w
		wp += Competency.prob(sid) * w
		ev += n
	var prob := wp / total_w if total_w > 0.0 else 0.5
	var level := FULL
	var reason := ""
	if ev < MIN_EVIDENCE:
		reason = "Not enough evidence yet, so full support is on"
	elif prob < 0.50:
		reason = "Estimate %d%%, so full support is on" % int(round(prob * 100.0))
	elif prob < 0.62:
		level = PARTIAL
		reason = "Estimate %d%%, so some supports are gone" % int(round(prob * 100.0))
	elif prob < 0.75 or ev < OFF_EVIDENCE:
		level = LIGHT
		reason = "Estimate %d%%, so you read the student yourself" % int(round(prob * 100.0))
	else:
		level = OFF
		reason = "Estimate %d%% across %d events, so all supports are off" % [int(round(prob * 100.0)), ev]
	return {"level": level, "name": NAMES[level], "prob": prob, "evidence": ev, "reason": reason}

## Skills an encounter exercises, from the move tags that can work for this student.
static func skills_for_moves(moves: Array) -> Array:
	var out: Array = []
	for m in moves:
		var sid := str(Competency.TAG_SKILL.get(str(m), Competency.GROUP_TAG_SKILL.get(str(m), "")))
		if sid != "" and not out.has(sid):
			out.append(sid)
	return out

static func badge_text(level: int, stepped_in: bool) -> String:
	if stepped_in:
		return "Support: Coach Vee stepped in"
	return "Support: %s" % NAMES[clampi(level, 0, 3)]

static func badge_color(level: int, stepped_in: bool) -> Color:
	if stepped_in:
		return Color(0.98, 0.70, 0.45)
	return [Color(0.60, 1.0, 0.70), Color(0.62, 0.88, 0.95), Color(0.85, 0.85, 0.95), Color(0.98, 0.86, 0.50)][clampi(level, 0, 3)]
