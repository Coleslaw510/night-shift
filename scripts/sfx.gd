class_name Sfx
## All audio is synthesized in code (no external audio files).

const RATE := 22050
static var _cache := {}

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

static func get_stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStreamWAV
	match name:
		"beep": s = _tone([1800.0], 0.09, 0.35, 0.0)
		"error": s = _tone([180.0, 190.0], 0.25, 0.35, 0.0)
		"chaching": s = _chime([1318.0, 1760.0, 2093.0], 0.08, 0.3)
		"chime": s = _chime([659.0, 523.0], 0.22, 0.25)
		"click": s = _tone([900.0], 0.03, 0.25, 0.0)
		"thud": s = _tone([90.0, 60.0], 0.25, 0.6, 12.0)
		"place": s = _tone([300.0], 0.06, 0.3, 30.0)
		"hum": s = _hum()
		"gunshot": s = _gunshot()
		"reload": s = _tone([520.0, 180.0], 0.12, 0.3, 18.0)
		_: s = _tone([440.0], 0.1, 0.3, 0.0)
	_cache[name] = s
	return s

static func _tone(freqs: Array, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		var env := exp(-decay * t) if decay > 0.0 else 1.0
		env *= minf(1.0, (n - i) / 200.0) * minf(1.0, i / 50.0)
		out[i] = v / freqs.size() * vol * env
	return _wav(out)

static func _chime(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var n := int((step * freqs.size() + 0.4) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := int(k * step * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += sin(TAU * freqs[k] * t) * exp(-7.0 * t) * vol
	return _wav(out)

static func _gunshot() -> AudioStreamWAV:
	var n := int(0.32 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / RATE
		var env := exp(-14.0 * t)
		out[i] = (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 90.0 * t) * 0.5) * env
	return _wav(out)

static func _hum() -> AudioStreamWAV:
	# 2 s loop of fluorescent/fridge hum: 120 Hz + harmonics + faint hiss.
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / RATE
		out[i] = 0.25 * sin(TAU * 120.0 * t) + 0.08 * sin(TAU * 240.0 * t) + 0.04 * sin(TAU * 360.0 * t) + rng.randf_range(-0.03, 0.03)
	return _wav(out, true)
