extends Node
## Verifies the qualitative-alignment features (QUALITATIVE_RESEARCH_AUDIT.md):
##  - Connect (notice -> bridge) resolves a connect_resolves student (2nd valid path)
##  - Connect does NOT resolve a non-connect_resolves student, but builds the bond
##  - Relationship (bond) persists across periods and gives a head-start
##  - Reflection-on-action logging
##  - Culturally-responsive scenario loads with a connect_min objective

var results: Array = []

func _ready() -> void:
	await _run()

func _check(label: String, cond: bool) -> void:
	results.append(cond)
	print("QUAL | [%s] %s" % ["OK " if cond else "XX", label])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _new_encounter(pid: String, name: String) -> Node:
	var enc: Node = load("res://scenes/encounter/Encounter.tscn").instantiate()
	add_child(enc)
	await _frames(2)
	enc.setup({"persona_id": pid, "display_name": name})
	await _frames(2)
	return enc

func _run() -> void:
	GameState.badges = []
	GameState.relationships = {}
	GameState.reflections = []
	Game.current_scenario_id = "discussion_fractions"

	# 1) Connect resolves a connect_resolves student (Noah): notice, then bridge.
	var noah := await _new_encounter("noah_g5_fractions", "Noah")
	_check("Noah loads connect_resolves=true + has assets", noah.connect_resolves and noah.assets.size() > 0)
	noah._on_move("connect")          # NOTICE the asset
	await _frames(2)
	_check("first Connect notices the asset (not resolved yet)", noah._asset_learned and not noah._resolved)
	noah._on_move("connect")          # BRIDGE content to the asset
	await _frames(2)
	_check("second Connect resolves Noah via the asset path", noah._resolved)
	_check("Connect built a real bond (>0)", GameState.bond("noah_g5_fractions") > 0.0)
	var noah_bond: float = GameState.bond("noah_g5_fractions")
	noah.queue_free()
	await _frames(2)

	# 2) Bond persists across periods + gives a head-start on the next encounter.
	var noah2 := await _new_encounter("noah_g5_fractions", "Noah")
	_check("bond persisted across periods", GameState.bond("noah_g5_fractions") == noah_bond)
	_check("relationship head-start raises starting understanding", noah2.understanding > 0.15)
	noah2.queue_free()
	await _frames(2)

	# 3) Connect on a non-connect_resolves student builds the bond but does NOT resolve.
	var talia := await _new_encounter("talia_dominator", "Talia")
	_check("Talia loads connect_resolves=false", not talia.connect_resolves)
	talia._on_move("connect")
	await _frames(2)
	talia._on_move("connect")
	await _frames(2)
	_check("Connect does not resolve a non-asset-path student", not talia._resolved)
	_check("but Connect still built Talia's bond", GameState.bond("talia_dominator") > 0.0)
	talia.queue_free()
	await _frames(2)

	# 4) Reflection-on-action logging.
	var r0: int = GameState.reflections.size()
	GameState.log_reflection({"scenario": "discussion_fractions", "prompt": "what_stays_with_you", "choice": "asset"})
	_check("reflection is logged + persisted", GameState.reflections.size() == r0 + 1)

	# 5) Culturally-responsive scenario loads with a connect_min objective.
	var f := FileAccess.open("res://data/scenarios/culturally_responsive_intro.json", FileAccess.READ)
	var cr = JSON.parse_string(f.get_as_text())
	f.close()
	var has_connect_obj := false
	for o in cr.get("objectives", []):
		if str(o.get("metric", "")) == "connect_min":
			has_connect_obj = true
	_check("CR scenario parses + rosters 6 + has connect_min objective",
		typeof(cr) == TYPE_DICTIONARY and cr.get("roster", []).size() == 6 and has_connect_obj)
	_check("CR scenario registered in Game.SCENARIOS", "culturally_responsive_intro" in Game.SCENARIOS)

	var passed := 0
	for r in results:
		if r:
			passed += 1
	print("QUAL | RESULT: %d / %d checks passed" % [passed, results.size()])
	print("QUAL | %s" % ("ALL PASS" if passed == results.size() else "SOME FAILED"))
	get_tree().quit()
