extends Node
## Synthesized sound library. Every cue is rendered once at startup into an
## AudioStreamWAV (so it also plays on web, unlike AudioStreamGenerator), then
## played through a small voice pool on the "SFX" bus. Buttons anywhere in the
## tree get hover/press sounds automatically.

@export var enabled := true

const MIX_RATE := 22050
const POOL_SIZE := 10
const BUS := "SFX"

# Note helpers (Hz)
const C5 := 523.25
const D5 := 587.33
const E5 := 659.25
const G5 := 783.99
const A5 := 880.0
const C6 := 1046.5
const E6 := 1318.5
const G4 := 392.0
const C4 := 261.63

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}

func _ready() -> void:
	_ensure_bus()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_pool.append(p)
	_build_library()
	get_tree().node_added.connect(_on_node_added)

func play(cue: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not bool(GameState.get_setting("audio_enabled", true)):
		return
	var stream: AudioStreamWAV = _streams.get(cue, null)
	if stream == null:
		stream = _streams["click"]
	# Throttle identical cues fired in the same few ms (e.g. hover sweeps).
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -1000)) < 35:
		return
	_last_played[cue] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Short randomized pitch blip, for typewriter text and count-up ticks.
func blip(cue: String = "type") -> void:
	play(cue, -4.0, randf_range(0.94, 1.08))

# --- auto-wire buttons ---------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sfx_silent"):
		var b := node as BaseButton
		b.mouse_entered.connect(func():
			if not b.disabled:
				play("hover", -8.0))
		b.focus_entered.connect(func():
			if not b.disabled and b.get_viewport() != null and b.get_viewport().gui_get_focus_owner() == b and not b.is_hovered():
				play("hover", -10.0))
		b.pressed.connect(func(): play("click"))

# --- synthesis -------------------------------------------------------------------

func _build_library() -> void:
	_streams["hover"] = _render([_tone(1760.0, 0.018, 0.10, "square", 0.0)])
	_streams["click"] = _render([_tone(C6, 0.035, 0.22, "square"), _tone(G5, 0.05, 0.18, "square", 0.028)])
	_streams["open"] = _render([_tone(E5, 0.05, 0.16, "triangle"), _tone(A5, 0.07, 0.16, "triangle", 0.045), _noise(0.09, 0.05, 0.0, 3000.0)])
	_streams["close"] = _render([_tone(A5, 0.04, 0.14, "triangle"), _tone(E5, 0.06, 0.14, "triangle", 0.035)])
	_streams["good"] = _render([_tone(E5, 0.07, 0.22, "square"), _tone(G5, 0.07, 0.22, "square", 0.06), _tone(C6, 0.14, 0.22, "square", 0.12)])
	_streams["bad"] = _render([_sweep(330.0, 150.0, 0.22, 0.24, "square")])
	_streams["badge"] = _render([
		_tone(C5, 0.09, 0.22, "square"), _tone(E5, 0.09, 0.22, "square", 0.09),
		_tone(G5, 0.09, 0.22, "square", 0.18), _tone(C6, 0.34, 0.24, "square", 0.27),
		_tone(E6, 0.30, 0.10, "triangle", 0.27),
	])
	_streams["interrupt"] = _render([_tone(A5, 0.08, 0.2, "square"), _tone(A5, 0.08, 0.2, "square", 0.14)])
	_streams["stamp"] = _render([_sweep(180.0, 50.0, 0.18, 0.55, "sine"), _noise(0.12, 0.35, 0.0, 1400.0)])
	_streams["tick"] = _render([_tone(1567.98, 0.02, 0.12, "square")])
	_streams["type"] = _render([_tone(740.0, 0.022, 0.08, "square")])
	_streams["whoosh"] = _render([_noise(0.28, 0.16, 0.0, 5000.0, true)])
	_streams["levelup"] = _render([
		_tone(G4, 0.08, 0.2, "square"), _tone(C5, 0.08, 0.2, "square", 0.08),
		_tone(E5, 0.08, 0.2, "square", 0.16), _tone(G5, 0.08, 0.2, "square", 0.24),
		_tone(C6, 0.4, 0.22, "square", 0.32), _tone(C4, 0.5, 0.18, "triangle", 0.32),
	])

## A layer: {"start": s, "samples": PackedFloat32Array}
func _tone(freq: float, dur: float, amp: float, wave: String = "square", start: float = 0.0) -> Dictionary:
	return _sweep(freq, freq, dur, amp, wave, start)

func _sweep(f0: float, f1: float, dur: float, amp: float, wave: String = "square", start: float = 0.0) -> Dictionary:
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var attack := mini(int(0.004 * MIX_RATE), n)
	for i in range(n):
		var k := float(i) / float(maxi(1, n))
		var f := lerpf(f0, f1, k)
		phase = fmod(phase + f / MIX_RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
				s *= 0.6
			"triangle":
				s = 4.0 * absf(phase - 0.5) - 1.0
			_:
				s = sin(TAU * phase)
		var env := (1.0 - k) * (1.0 - k)
		if i < attack:
			env *= float(i) / float(maxi(1, attack))
		out[i] = s * amp * env
	return {"start": start, "samples": out}

func _noise(dur: float, amp: float, start: float, cutoff: float, swell: bool = false) -> Dictionary:
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := clampf(TAU * cutoff / MIX_RATE, 0.0, 1.0)
	var y := 0.0
	for i in range(n):
		var k := float(i) / float(maxi(1, n))
		y += a * (randf_range(-1.0, 1.0) - y)
		var env := sin(PI * k) if swell else (1.0 - k) * (1.0 - k)
		out[i] = y * amp * env * 2.0
	return {"start": start, "samples": out}

func _render(layers: Array) -> AudioStreamWAV:
	var total := 0
	for layer in layers:
		total = maxi(total, int(float(layer["start"]) * MIX_RATE) + (layer["samples"] as PackedFloat32Array).size())
	var mix := PackedFloat32Array()
	mix.resize(total)
	for layer in layers:
		var off := int(float(layer["start"]) * MIX_RATE)
		var s: PackedFloat32Array = layer["samples"]
		for i in range(s.size()):
			mix[off + i] += s[i]
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in range(total):
		bytes.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, -6.0)
