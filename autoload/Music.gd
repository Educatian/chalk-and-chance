extends Node
## Background music with crossfades on its own "Music" bus. Tracks live in
## assets/audio/music/ (rendered by tools/compose_bgm.py). SceneRouter picks a track
## per scene; scenes may override with Music.play("tension") etc.

const BUS := "Music"
const DIR := "res://assets/audio/music/%s.ogg"
const FADE := 1.2
const BASE_DB := -9.0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	_a = _make_player()
	_b = _make_player()
	apply_settings()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	p.volume_db = -80.0
	add_child(p)
	return p

func apply_settings() -> void:
	var on := bool(GameState.get_setting("music_enabled", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), not on)

func play(track: String) -> void:
	if track == _current:
		return
	var path := DIR % track
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_current = track
	var incoming := _b if _a.playing and _a.volume_db > -60.0 else _a
	var outgoing := _a if incoming == _b else _b
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(incoming, "volume_db", BASE_DB, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if outgoing.playing:
		t.tween_property(outgoing, "volume_db", -60.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(outgoing.stop)

func stop(fade: float = FADE) -> void:
	_current = ""
	for p in [_a, _b]:
		if p.playing:
			var t := create_tween()
			t.tween_property(p, "volume_db", -60.0, fade)
			t.tween_callback(p.stop)

## Default track per scene file.
func track_for_scene(path: String) -> String:
	if path.contains("GymEncounter"):
		return "tension"
	if path.contains("MissionCinematic"):
		return "cinematic"
	if path.contains("/encounter/") or path.contains("/overworld/"):
		return "classroom"
	if path.contains("/dev/"):
		return ""
	return "hub"
