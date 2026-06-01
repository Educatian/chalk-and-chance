extends Node
## Tiny generated sound cues. Keeps the prototype responsive without adding audio assets.

@export var enabled := true

const CUES := {
	"click": {"freq": 520.0, "dur": 0.045, "amp": 0.08},
	"good": {"freq": 740.0, "dur": 0.09, "amp": 0.10},
	"bad": {"freq": 190.0, "dur": 0.11, "amp": 0.09},
	"badge": {"freq": 960.0, "dur": 0.18, "amp": 0.11},
	"interrupt": {"freq": 330.0, "dur": 0.14, "amp": 0.10},
}

func play(cue: String) -> void:
	if not enabled:
		return
	# Web exports already use browser-managed TTS/audio. Godot's generated tone stream
	# can emit WebGL/audio sampling warnings in Chromium, so keep SFX silent on web.
	if OS.has_feature("web"):
		return
	if not bool(GameState.get_setting("audio_enabled", true)):
		return
	var cfg: Dictionary = CUES.get(cue, CUES["click"])
	_play_tone(float(cfg["freq"]), float(cfg["dur"]), float(cfg["amp"]))

func _play_tone(freq: float, dur: float, amp: float) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = maxf(0.08, dur + 0.04)
	player.stream = stream
	player.volume_db = -10.0
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var frames := int(stream.mix_rate * dur)
	for i in range(frames):
		var t := float(i) / stream.mix_rate
		var fade := 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(TAU * freq * t) * amp * fade
		playback.push_frame(Vector2(sample, sample))
	_free_player_later(player, dur + 0.08)

func _free_player_later(player: AudioStreamPlayer, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(player):
		player.queue_free()
