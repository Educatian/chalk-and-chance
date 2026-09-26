extends Node
## Dev: renders the Coach Vee coaching card for sample runs into tools/cine/.
const CoachCard = preload("res://scenes/ui/CoachCard.gd")

func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	GameState.settings["reduced_motion"] = true
	var lecture := [
		{"turn": 1, "tag": "present", "targets": true},
		{"turn": 2, "tag": "present", "targets": true},
		{"turn": 3, "tag": "present", "targets": false, "note": "that was Present #3 in a row"},
		{"turn": 4, "tag": "present", "targets": false, "note": "that was Present #4 in a row"},
		{"turn": 5, "tag": "ask", "targets": false, "student": "Talia", "note": "comprehension was only 38%"},
		{"turn": 6, "tag": "present", "targets": false},
		{"turn": 7, "tag": "poll", "targets": true},
	]
	GameState.coach_focus["lecture_fractions"] = {"tag": "poll", "count": 2, "text": "Make 2 Check moves land this time."}
	CoachCard.open(self, lecture, "lecture_fractions", func(): pass, func(): pass)
	await get_tree().create_timer(0.6).timeout
	_shot("coach_lecture")
	for c in get_children():
		c.queue_free()
	var gym := [
		{"turn": 1, "tag": "extend", "targets": false, "student": "Noah", "fit": "early", "note": "right idea, too early: first Elicit or Wait or Revoice"},
		{"turn": 2, "tag": "elicit", "targets": true, "student": "Noah", "fit": "advance", "path": "Diagnose, then press"},
		{"turn": 3, "tag": "praise", "targets": false, "student": "Priya", "fit": "miss"},
		{"turn": 4, "tag": "redirect", "targets": true, "student": "Deshawn", "fit": "advance", "path": "Least-to-most"},
		{"turn": 5, "tag": "extend", "targets": true, "student": "Noah", "fit": "advance", "path": "Diagnose, then press"},
	]
	CoachCard.open(self, gym, "gym_capstone", func(): pass, func(): pass)
	await get_tree().create_timer(0.6).timeout
	_shot("coach_gym")
	GameState.coach_focus["gym_capstone"] = {"tag": "elicit", "count": 2, "text": "Make 2 Elicit moves land this time."}
	CoachCard.show_focus_banner(self, "gym_capstone")
	await get_tree().create_timer(1.6).timeout
	_shot("coach_banner")
	get_tree().quit()

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://tools/cine/%s.png" % name)
	print("saved ", name)
