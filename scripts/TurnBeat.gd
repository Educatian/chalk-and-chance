extends RefCounted
## The turn-resolution beat: a short, ordered sequence of presentation steps that plays
## after a teaching move is judged (reaction -> outcome cue + meters -> coach line ->
## hand control back). Pure timing state so it can be checked headless; the Juice
## autoload advances it every frame. finish() runs every remaining step at once
## (any player press skips the beat). Presentation only: the judgment, scoring and
## telemetry already happened before the beat starts.

## Outcome kinds. "early" (right idea, too early) is deliberately distinct from "wrong".
const RIGHT := "right"
const EARLY := "early"
const WRONG := "wrong"
const NEUTRAL := "neutral"

const CUES := {RIGHT: "turn_right", EARLY: "turn_early", WRONG: "turn_wrong", NEUTRAL: "turn_neutral"}
const LABELS := {RIGHT: "LANDED", EARLY: "TOO EARLY", WRONG: "NOT YET", NEUTRAL: "NOTED"}
## Wrong is a muted coral, not alarm red: informative, not punitive.
const COLORS := {
	RIGHT: Color(0.45, 0.88, 0.55),
	EARLY: Color(0.55, 0.78, 1.0),
	WRONG: Color(0.95, 0.62, 0.52),
	NEUTRAL: Color(0.80, 0.84, 0.92),
}

## Map the judge's existing verdict to a presentation kind. Does not judge anything.
static func outcome(targets: bool, fit_kind: String = "") -> String:
	if targets:
		return RIGHT
	if fit_kind == "early":
		return EARLY
	return WRONG

static func cue(kind: String) -> String:
	return str(CUES.get(kind, CUES[NEUTRAL]))

static func label(kind: String) -> String:
	return str(LABELS.get(kind, LABELS[NEUTRAL]))

static func color(kind: String) -> Color:
	return COLORS.get(kind, COLORS[NEUTRAL])

var elapsed := 0.0
var _steps: Array = []   # [{at: float, fn: Callable, ran: bool}] sorted by at

## Schedule fn at `at_sec` after the beat starts. Returns self for chaining.
func at(at_sec: float, fn: Callable) -> RefCounted:
	_steps.append({"at": at_sec, "fn": fn, "ran": false})
	_steps.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
	return self

## Advance time; runs every step whose time has come, in order.
func advance(dt: float) -> void:
	elapsed += dt
	for s in _steps:
		if not s["ran"] and float(s["at"]) <= elapsed:
			s["ran"] = true
			(s["fn"] as Callable).call()

## Skip to the end: run all remaining steps now, in order.
func finish() -> void:
	for s in _steps:
		if not s["ran"]:
			s["ran"] = true
			(s["fn"] as Callable).call()

func is_done() -> bool:
	for s in _steps:
		if not s["ran"]:
			return false
	return true

func duration() -> float:
	return 0.0 if _steps.is_empty() else float(_steps[-1]["at"])
