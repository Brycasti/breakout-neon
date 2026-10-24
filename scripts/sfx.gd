extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 14

@warning_ignore_start("integer_division")

const WAVE_SINE: int = 0
const WAVE_SQUARE: int = 1
const WAVE_TRIANGLE: int = 2

var enabled: bool = true

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_index: int = 0


func _ready() -> void:
	_build_library()
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


# Reproduce un efecto sonoro disponible en el banco
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var player: AudioStreamPlayer = _next_player()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch * randf_range(0.97, 1.03), 0.4, 2.5)
	player.play()


func play_ui() -> void:
	play("click", -4.0)


# Asigna el siguiente reproductor disponible en el pool
func _next_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	_next_index = (_next_index + 1) % _players.size()
	return _players[_next_index]


# Generación procedural del banco de sonidos
func _build_library() -> void:
	_streams["brick"] = _sweep(880.0, 1080.0, 0.05, WAVE_SQUARE, 0.20, 2.2)
	_streams["crack"] = _sweep(620.0, 760.0, 0.07, WAVE_TRIANGLE, 0.18, 2.0)
	_streams["brick_break"] = _mix(
		_noise(0.15, 0.30, 2.4, 0.30),
		_sweep(320.0, 120.0, 0.15, WAVE_TRIANGLE, 0.16, 1.8)
	)
	_streams["steel"] = _sweep(240.0, 170.0, 0.11, WAVE_SQUARE, 0.18, 2.2)
	_streams["paddle"] = _sweep(340.0, 220.0, 0.09, WAVE_SINE, 0.32, 2.6)
	_streams["paddle_hit"] = _sweep(360.0, 225.0, 0.08, WAVE_SINE, 0.30, 2.6)
	_streams["laser"] = _sweep(1600.0, 320.0, 0.14, WAVE_SQUARE, 0.16, 1.8)
	_streams["wall"] = _sweep(560.0, 480.0, 0.045, WAVE_SINE, 0.16, 3.0)
	_streams["launch"] = _sweep(300.0, 760.0, 0.13, WAVE_TRIANGLE, 0.24, 1.2)
	_streams["power"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.065, WAVE_SQUARE, 0.20)
	_streams["extra_life"] = _arpeggio([659.25, 783.99, 1046.5, 1318.5], 0.09, WAVE_TRIANGLE, 0.24)
	_streams["explosion"] = _mix(
		_noise(0.40, 0.42, 1.5, 0.10),
		_sweep(170.0, 45.0, 0.40, WAVE_SINE, 0.34, 1.4)
	)
	_streams["lightning"] = _mix(
		_noise(0.12, 0.28, 3.0, 0.75),
		_sweep(1800.0, 420.0, 0.12, WAVE_SQUARE, 0.13, 2.0)
	)
	_streams["lose"] = _sweep(430.0, 110.0, 0.55, WAVE_TRIANGLE, 0.28, 1.3)
	_streams["level_clear"] = _arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.11, WAVE_SQUARE, 0.20)
	_streams["game_over"] = _arpeggio([440.0, 349.23, 261.63, 196.0], 0.20, WAVE_TRIANGLE, 0.26)
	_streams["shield"] = _sweep(180.0, 900.0, 0.32, WAVE_TRIANGLE, 0.20, 0.9)
	_streams["click"] = _sweep(900.0, 1250.0, 0.035, WAVE_SQUARE, 0.16, 3.0)


# Síntesis de barrido de frecuencia
func _sweep(f_start: float, f_end: float, duration: float, wave: int,
		amp: float, decay: float) -> AudioStreamWAV:
	var count: int = maxi(1, int(duration * MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(MIX_RATE)
		var value: float = _wave_value(wave, phase, t)
		samples[i] = value * amp * pow(1.0 - t, decay)
	return _to_stream(samples)


func _wave_value(wave: int, phase: float, _t: float) -> float:
	match wave:
		WAVE_SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		WAVE_TRIANGLE:
			var cycles: float = phase / TAU
			return 4.0 * absf(cycles - floor(cycles + 0.5)) - 1.0
		_:
			return sin(phase)


# Síntesis de ruido blanco con filtrado
func _noise(duration: float, amp: float, decay: float, smoothing: float) -> AudioStreamWAV:
	var count: int = maxi(1, int(duration * MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var filtered: float = 0.0
	var k: float = clampf(smoothing, 0.0, 1.0)
	for i: int in range(count):
		var t: float = float(i) / float(count)
		var white: float = randf_range(-1.0, 1.0)
		filtered += (white - filtered) * k
		samples[i] = filtered * amp * pow(1.0 - t, decay)
	return _to_stream(samples)


# Generación de arpegios tonales
func _arpeggio(notes: Array, note_duration: float, wave: int, amp: float) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for note: float in notes:
		var part: AudioStreamWAV = _sweep(note, note, note_duration, wave, amp, 1.1)
		var raw: PackedByteArray = part.data
		for i: int in range(raw.size() / 2):
			samples.append(float(raw.decode_s16(i * 2)) / 32767.0)
	return _to_stream(samples)


# Mezcla de dos pistas de audio
func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var samples_a: PackedFloat32Array = _to_samples(a)
	var samples_b: PackedFloat32Array = _to_samples(b)
	var count: int = maxi(samples_a.size(), samples_b.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for i: int in range(count):
		var va: float = samples_a[i] if i < samples_a.size() else 0.0
		var vb: float = samples_b[i] if i < samples_b.size() else 0.0
		out[i] = va + vb
	return _to_stream(out)


func _to_samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var raw: PackedByteArray = stream.data
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(raw.size() / 2)
	for i: int in range(samples.size()):
		samples[i] = float(raw.decode_s16(i * 2)) / 32767.0
	return samples


# Conversión de búfer de flotantes a AudioStreamWAV PCM 16-bit
func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	if peak > 0.98:
		var scale: float = 0.98 / peak
		for i: int in range(samples.size()):
			samples[i] *= scale
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
