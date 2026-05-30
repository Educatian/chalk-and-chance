extends Node
## In-engine ECD measurement model: a live multivariate-Elo estimate of the PLAYER's
## teaching competencies (the GDScript twin of tools/fit_competencies.py, which uses the
## P1 ogd-p1-elo engine for offline analysis). Each move is one observation; theta is the
## per-competency ability, persisted across encounters within a session.
##
## Single-skill-per-move items make the multivariate update reduce to a per-skill Elo with
## an item difficulty beta[tag::persona]. Difficulty is CALIBRATED at first sight from the
## task model: a move that is a win_move for THIS student starts easier than an off-target one.

const SKILLS := ["elicit_reasoning", "extend_thinking", "revoicing", "wait_time",
	"behavior_mgmt", "restraint", "behavior_specific_praise", "funds_of_knowledge",
	"group_monitoring", "formative_check", "status_treatment"]
const LABELS := {
	"elicit_reasoning": "Eliciting", "extend_thinking": "Extending", "revoicing": "Revoicing",
	"wait_time": "Wait time", "behavior_mgmt": "Mgmt (least-intrusive)", "restraint": "Restraint",
	"behavior_specific_praise": "Specific praise", "funds_of_knowledge": "Asset connect",
	"group_monitoring": "Group monitoring", "formative_check": "Formative check", "status_treatment": "Status treatment",
}
# group check-in monitoring move -> the competency it evidences
const GROUP_TAG_SKILL := {
	"observe": "group_monitoring", "probe": "formative_check",
	"press": "group_monitoring", "redistribute": "status_treatment",
}
const TAG_SKILL := {
	"elicit": "elicit_reasoning", "extend": "extend_thinking", "revoice": "revoicing",
	"wait": "wait_time", "redirect": "behavior_mgmt", "tell": "restraint",
	"praise": "behavior_specific_praise", "connect": "funds_of_knowledge",
}
const A := 1.0
const B := 0.05

var theta: Dictionary = {}   # skill -> ability (logit)
var n: Dictionary = {}       # skill -> observation count (drives uncertainty)
var beta: Dictionary = {}    # "tag::persona" -> item difficulty
var nb: Dictionary = {}

func _ready() -> void:
	for s in SKILLS:
		theta[s] = 0.0
		n[s] = 0.0

## Derive the success signal y in {0,1} from the turn (same evidence rules as the model).
func score_y(tag: String, judge: Dictionary, deltas: Dictionary) -> int:
	match tag:
		"elicit", "extend": return 1 if bool(judge.get("targets_misconception", judge.get("targets", false))) else 0
		"wait": return 1 if bool(judge.get("wait_time_ok", judge.get("wait_ok", false))) else 0
		"redirect": return 1 if float(deltas.get("order", 0.0)) > 0.0 else 0
		"revoice", "praise": return 1 if float(deltas.get("trust", 0.0)) > 0.0 else 0
		"connect": return 1
		"tell": return 0
		_: return 0

## One Elo update from a completed turn.
func observe(tag: String, persona_id: String, win_moves: Array, judge: Dictionary, deltas: Dictionary) -> void:
	var skill: String = TAG_SKILL.get(tag, "")
	if skill == "":
		return
	var item := "%s::%s" % [tag, persona_id]
	if not beta.has(item):
		beta[item] = -0.3 if (tag in win_moves) else 0.3   # task-model difficulty calibration
		nb[item] = 0.0
	var y := float(score_y(tag, judge, deltas))
	var logit: float = theta[skill] - beta[item]
	var p := 1.0 / (1.0 + exp(-clampf(logit, -32.0, 32.0)))
	var err := y - p
	var at := A / (1.0 + B * float(n[skill]))
	var ab := A / (1.0 + B * float(nb[item]))
	theta[skill] += at * err
	beta[item] -= ab * err
	n[skill] += 1.0
	nb[item] += 1.0

## Group check-in monitoring move -> Elo update on its group competency. item = the move
## itself (no per-persona difficulty here); y = 1 if it was a productive monitoring move.
func observe_group(tag: String, productive: bool) -> void:
	var skill: String = GROUP_TAG_SKILL.get(tag, "")
	if skill == "":
		return
	var item := "group::%s" % tag
	if not beta.has(item):
		beta[item] = 0.0
		nb[item] = 0.0
	var y := 1.0 if productive else 0.0
	var logit: float = theta[skill] - beta[item]
	var p := 1.0 / (1.0 + exp(-clampf(logit, -32.0, 32.0)))
	var err := y - p
	var at := A / (1.0 + B * float(n[skill]))
	var ab := A / (1.0 + B * float(nb[item]))
	theta[skill] += at * err
	beta[item] -= ab * err
	n[skill] += 1.0
	nb[item] += 1.0

func prob(skill: String) -> float:
	return 1.0 / (1.0 + exp(-clampf(theta.get(skill, 0.0), -32.0, 32.0)))

func uncertainty(skill: String) -> float:
	return A / (1.0 + B * float(n.get(skill, 0.0)))

## Ordered summary for display: [{skill,label,prob,n,unc}], most-evidenced first.
func summary() -> Array:
	var out: Array = []
	for s in SKILLS:
		out.append({"skill": s, "label": LABELS.get(s, s), "prob": prob(s),
			"n": int(n.get(s, 0)), "unc": uncertainty(s)})
	out.sort_custom(func(a, b): return a["n"] > b["n"])
	return out
