extends Node
## Learner transcript contract test.
## Verifies readable turn capture, privacy filtering, Markdown output, and desktop save.

var _failures: Array[String] = []

func _ready() -> void:
	TTSClient.enabled = false
	Telemetry._conversation_events.clear()

	Telemetry.log_turn({
		"scenario_id": "cat531_reasoning_rehearsal",
		"persona_id": "sim_student_1",
		"turn": 1,
		"move": {"tag": "elicit", "input_mode": "free_text", "text": "What makes you think that?", "wait_ms": 3000},
		"judge": {"targets": true, "wait_ok": true},
		"student_text": "I compared the two examples.",
		"coach_tip": "Keep the learner's reasoning visible.",
	})
	Telemetry.log_event({
		"event": "group_turn",
		"scenario_id": "cat531_group_rehearsal",
		"move": "redistribute",
		"targets": true,
		"speaker": "Simulated group",
		"student_text": "We invited a quieter member to explain.",
		"private_debug_payload": "must-not-appear",
	})
	Telemetry.log_event({
		"event": "lecture_turn",
		"scenario_id": "cat531_lecture_rehearsal",
		"move": {"menu_tag": "poll", "input_mode": "menu", "text": ""},
		"reaction": {"speaker": "Class", "text": "Most students show option B."},
		"coach_tip": "Use the distribution as formative evidence.",
	})

	_expect_eq(Telemetry.conversation_count(), 3, "conversation entry count")
	var markdown := Telemetry.conversation_markdown()
	_expect_contains(markdown, "# Chalk & Chance Conversation Transcript", "title")
	_expect_contains(markdown, "What makes you think that?", "free-text teacher move")
	_expect_contains(markdown, "I compared the two examples.", "simulated learner response")
	_expect_contains(markdown, "Redistribute participation", "group menu move label")
	_expect_contains(markdown, "Most students show option B.", "lecture response")
	_expect_contains(markdown, "Decision signal", "decision evidence")
	_expect_not_contains(markdown, "must-not-appear", "raw telemetry field")
	_expect_not_contains(markdown, "anon_id", "anonymous account metadata")
	_expect_not_contains(markdown, "class_code", "class account metadata")

	var filename := Telemetry.conversation_filename()
	if not filename.begins_with("chalk-and-chance-transcript-") or not filename.ends_with(".md"):
		_fail("Unexpected transcript filename: %s" % filename)

	var saved := Telemetry.download_conversation()
	if not bool(saved.get("ok", false)):
		_fail("Desktop transcript save failed: %s" % str(saved.get("error", "unknown")))
	else:
		var path := str(saved.get("path", ""))
		if path == "" or not FileAccess.file_exists(path):
			_fail("Saved transcript path was not created: %s" % path)
		else:
			var file := FileAccess.open(path, FileAccess.READ)
			var saved_text := file.get_as_text() if file != null else ""
			if file != null:
				file.close()
			_expect_contains(saved_text, "What makes you think that?", "saved transcript content")
			DirAccess.remove_absolute(path)

	if _failures.is_empty():
		print("CONVERSATION EXPORT TEST: PASS")
	else:
		print("CONVERSATION EXPORT TEST: FAIL")
		for message in _failures:
			print(" - %s" % message)
	get_tree().quit()

func _expect_eq(actual, expected, label: String) -> void:
	if actual != expected:
		_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _expect_contains(text: String, needle: String, label: String) -> void:
	if text.find(needle) == -1:
		_fail("Missing %s: %s" % [label, needle])

func _expect_not_contains(text: String, needle: String, label: String) -> void:
	if text.find(needle) != -1:
		_fail("Unexpected %s: %s" % [label, needle])

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
