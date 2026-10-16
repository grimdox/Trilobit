extends Node
## Procedural sound effects: short noise and tone bursts built in code, so the game ships without audio files.
## Game logic appends event names to game.sfx_queue; main.gd calls play() for each.
const RATE := 22050
var enabled: bool = true
var volume: float = 0.7
var streams: Dictionary = {}
var players: Array = []
var next_player: int = 0

func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["shot"] = _burst(0.16, 0.0, 30.0, 1.0, 0.0)
	streams["shot_big"] = _burst(0.3, 0.0, 16.0, 1.0, 0.0)
	streams["step"] = _burst(0.05, 0.0, 70.0, 0.35, 120.0)
	streams["hit"] = _burst(0.12, 0.0, 28.0, 0.8, 90.0)
	streams["hurt"] = _burst(0.2, 0.0, 14.0, 0.9, 70.0)
	streams["boom"] = _burst(0.6, 0.0, 6.0, 1.0, 45.0)
	streams["pick"] = _tone(0.09, 880.0, 1320.0, 0.4)
	streams["blip"] = _tone(0.05, 660.0, 660.0, 0.3)
	streams["select"] = _tone(0.08, 520.0, 780.0, 0.35)
	streams["fall"] = _tone(0.4, 500.0, 90.0, 0.5)
	streams["engine"] = _burst(0.12, 0.0, 12.0, 0.5, 60.0)

## noise burst with an exponential decay; `tone_hz` mixes in a low thump
func _burst(secs: float, _unused: float, decay: float, amp: float, tone_hz: float) -> AudioStreamWAV:
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(secs * 1000.0 + decay)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		var s := rng.randf_range(-1.0, 1.0) * 0.8
		if tone_hz > 0.0:
			s = s * 0.4 + sin(TAU * tone_hz * t) * 0.8
		data.encode_s16(i * 2, int(clampf(s * env * amp, -1.0, 1.0) * 30000.0))
	return _wav(data)

func _tone(secs: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		ph += TAU * lerpf(f0, f1, u) / RATE
		var env := (1.0 - u) * minf(1.0, u * 20.0)
		data.encode_s16(i * 2, int(sin(ph) * env * amp * 30000.0))
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func play(name: String) -> void:
	if not enabled or volume <= 0.0 or not streams.has(name) or players.is_empty():
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = linear_to_db(volume)
	p.play()
