extends Node
## Human-perspective integration test: boots the real game (Main -> Hub), clicks buttons
## via their pressed signal, injects keyboard input for movement/interaction, and checks the
## real routing/input/encounter flow end to end. Prints a transcript + PASS/FAIL.

var results: Array = []

func _ready() -> void:
	await _run()

func _p(s: String) -> void:
	print("PLAYTEST | ", s)

func _check(label: String, cond: bool) -> void:
	results.append(cond)
	print("PLAYTEST | [%s] %s" % ["OK " if cond else "XX", label])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _wait(sec: float) -> void:
	# Real wall-clock wait so SceneTreeTimer-based scene transitions actually fire.
	await get_tree().create_timer(sec).timeout
	await _frames(2)

func _find_button(root: Node, txt: String) -> Button:
	for c in root.get_children():
		if c is Button and c.text.findn(txt) != -1:
			return c
		var r := _find_button(c, txt)
		if r != null:
			return r
	return null

func _cur() -> Node:
	return SceneRouter._current

func _press_move(enc: Node, tag: String) -> void:
	# Press a teaching-move button like a user; honor wait-time for the Wait move.
	if enc._busy or enc._resolved:
		await _frames(2)
		return
	if tag == "wait":
		await _wait(3.2)   # hold the wait-time ring as a real player must
	var b := _find_button(enc, tag.capitalize())
	if b != null:
		b.pressed.emit()
	await _frames(6)   # deferred stub reply lands on the next idle frame

func _run() -> void:
	# Keep this integration test deterministic and offline. Login routing is still
	# exercised below, but dialogue/judge turns use the in-engine rubric.
	LLMClient.use_stub = true
	TTSClient.enabled = false

	GameState.badges = []
	GameState.attempts = {}
	Game.clear_lesson()

	# Boot the real game.
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var c := _cur()
	if c != null and c.name == "Login":
		var skip := _find_button(c, "Skip")
		_check("boots into Login with skip available", skip != null and not skip.disabled)
		if skip != null:
			skip.pressed.emit()
		await _frames(5)
		c = _cur()
	_check("boots into Hub", c != null and c.name == "Hub")

	# Click the first unlocked mission (Lecture) like a user.
	var lecbtn := _find_button(c, "Intro to Fractions")
	_check("lecture mission button present + enabled", lecbtn != null and not lecbtn.disabled)
	if lecbtn != null:
		lecbtn.pressed.emit()
	await _frames(5)
	c = _cur()
	_check("clicking mission opens Lecture mode", c != null and c.name == "LectureScene")

	# Play the lecture by clicking action buttons.
	if c != null and c.name == "LectureScene":
		var guard := 0
		while not c._over and guard < 70:
			guard += 1
			var b: Button = null
			if c.comprehension < 55.0 and guard % 5 == 0:
				b = _find_button(c, "Class Check")
			elif guard % 2 == 0:
				c._select(guard % c.students.size())
				b = _find_button(c, "Question")
			else:
				b = _find_button(c, "Present")
			if b != null:
				b.pressed.emit()
			await _frames(2)
		_check("lecture completes by clicking buttons", c._over)
		_check("lecture awards badge on win", "routine" in GameState.badges)
		await _wait(4.0)   # _finish waits ~3.4s (real time) then routes to Hub
		c = _cur()
		_check("returns to Hub after lecture", c != null and c.name == "Hub")

	# Now a discussion overworld: keyboard movement + walking up to a student to interact.
	Game.clear_lesson()
	if c != null and c.has_method("_choose"):
		c._choose("discussion_fractions")
	await _frames(6)
	c = _cur()
	_check("opens Overworld", c != null and c.name == "Overworld")
	if c != null and c.name == "Overworld":
		var player = c._player
		var t0: Vector2i = player.current_tile()
		Input.action_press("ui_down")
		await _wait(0.5)
		Input.action_release("ui_down")
		await _wait(0.5)   # let the move tween finish so _moving clears
		var t1: Vector2i = player.current_tile()
		_check("arrow-key input moves the player", t0 != t1)

		# Stand next to a real seated student and press Z (ui_accept) to interact.
		var stu_tile: Vector2i = c._npcs.keys()[0]
		var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
		for d in dirs:
			var adj: Vector2i = stu_tile - d
			if c.is_walkable(adj):
				player.position = Vector2(adj.x * 40, adj.y * 40)
				player.facing = d
				break
		player._moving = false
		await _wait(0.2)
		Input.action_press("ui_accept")
		await _frames(4)
		Input.action_release("ui_accept")
		await _wait(0.3)
		c = _cur()
		_check("pressing Z by a student opens an Encounter", c != null and c.name == "Encounter")

		# Click this student's actual winning move; understanding should rise and resolve.
		if c != null and c.name == "Encounter":
			var wins: Array = c.win_moves
			# Prefer a non-wait move for the quick first check.
			var primary := "elicit"
			for w in wins:
				if str(w) != "wait":
					primary = str(w)
					break
			if wins.size() > 0 and primary == "elicit" and not ("elicit" in wins):
				primary = str(wins[0])   # only-wait persona: fall back to wait
			var u0: float = c.understanding
			await _press_move(c, primary)
			_check("clicking %s's winning move raises understanding" % c.display_name, c.understanding > u0)
			var g := 0
			while not c._resolved and g < 16:
				g += 1
				await _press_move(c, str(wins[g % wins.size()]) if wins.size() > 0 else "elicit")
			_check("encounter resolves via correct moves", c._resolved)

	var passed := 0
	for r in results:
		if r:
			passed += 1
	print("PLAYTEST | RESULT: %d / %d checks passed" % [passed, results.size()])
	print("PLAYTEST | %s" % ("ALL PASS" if passed == results.size() else "SOME FAILED"))
	get_tree().quit()
