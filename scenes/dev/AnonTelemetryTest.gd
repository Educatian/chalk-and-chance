extends Node
## Live end-to-end test of the ANONYMOUS / demo telemetry path: exercises the real
## Telemetry.flush() routing -> Auth.post_anon() -> deployed Worker -> telemetry_anon_events.
## Run with --headless; it force-enables networking (headless normally suppresses it) and
## uploads under a unique ci_anon_* id so the rows can be found and cleaned up afterward.

func _ready() -> void:
	TTSClient.enabled = false
	if not Auth.configured():
		print("ANON TELEMETRY TEST: SKIP (api_base not provisioned)")
		get_tree().quit()
		return

	Telemetry._net = true   # headless suppresses uploads by default; turn it on for this test
	Telemetry.anon_id = "ci_anon_%d" % (Time.get_ticks_usec() % 1000000)

	# Behavioral logs across the three asks: dialogue, play, movement, + engagement pulse.
	Telemetry.log_event({"event": "session_start", "engine": "anon_test",
		"client": {"url": "test://anon", "lang": "en-US", "referrer": "test"}})
	Telemetry.log_player_movement("step_end", {"tile": {"x": 5, "y": 3}, "from": {"x": 4, "y": 3}})
	Telemetry.log_turn({
		"scenario_id": "sc_test", "persona_id": "p1", "turn": 1,
		"move": {"tag": "elicit", "input_mode": "free_text", "text": "What makes you think that?", "wait_ms": 1200},
		"judge": {"tags": ["elicit"], "targets": true, "wait_time_ok": true},
		"deltas": {"understanding": 0.1}, "meters": {"understanding": 0.5},
		"emotion_shown": "thinking",
		"student_text": "Because the numbers kept getting bigger.",
	})
	Telemetry.log_event({"event": "heartbeat", "elapsed_s": 31, "scene": "Overworld"})

	Telemetry.flush()

	var waited := 0.0
	while Telemetry._flush_in_flight and waited < 20.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	var ok := Telemetry._buffer.is_empty() and not Telemetry._flush_in_flight
	print("ANON TELEMETRY anon_id=%s buffer_left=%d in_flight=%s waited=%.1fs"
		% [Telemetry.anon_id, Telemetry._buffer.size(), str(Telemetry._flush_in_flight), waited])
	print("ANON TELEMETRY TEST: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit()
