class_name Fanfare
## Erzeugt einen kurzen Sieges-Fanfaren-Sound komplett prozedural
## (AudioStreamGenerator) – ganz ohne Audio-Assets.

const SAMPLE_RATE := 22050

func play_victory() -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 3.0
	player.stream = stream
	add_child(player)
	player.play()
	var playback := player.get_stream_playback()
	if playback == null:
		return
	var samples := _render_fanfare()
	var i := 0
	while i < samples.size():
		var left := samples[i]
		var right := samples[i + 1] if i + 1 < samples.size() else samples[i]
		playback.push_frame(Vector2(left, right))
		i += 2
	player.finished.connect(func(): player.queue_free())

func _render_fanfare() -> PackedFloat32Array:
	var duration := 2.8
	var total := int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(total * 2)
	buf.fill(0.0)
	# Noten: (Frequenz, Startzeit, Dauer, Lautstärke)
	var notes := [
		[220.00, 0.00, 0.45, 0.5],
		[277.18, 0.14, 0.45, 0.5],
		[329.63, 0.28, 0.45, 0.5],
		[440.00, 0.42, 0.9, 0.55],
		[554.37, 0.90, 0.5, 0.45],
		[659.25, 1.05, 1.2, 0.5],
		[440.00, 1.35, 1.2, 0.4],
		[880.00, 1.35, 1.2, 0.35],
	]
	for n in notes:
		_add_tone(buf, n[0], n[1], n[2], n[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t in [0.0, 0.42, 0.84, 1.35]:
		_add_drum(buf, t, 0.18, 0.35, rng)
	# weich normalisieren
	var peak := 0.0
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	if peak > 0.0:
		var gain := 0.85 / peak
		for i in buf.size():
			buf[i] *= gain
	return buf

func _add_tone(buf: PackedFloat32Array, freq: float, start: float, dur: float, vol: float) -> void:
	var from := int(start * SAMPLE_RATE)
	var to := int((start + dur) * SAMPLE_RATE)
	to = mini(to, buf.size() / 2)
	for i in range(from, to):
		var t := float(i) / SAMPLE_RATE
		var local := float(i - from) / SAMPLE_RATE
		var env := 1.0 - local / dur
		env *= minf(local * 40.0, 1.0)
		var s := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.3
		buf[i * 2] += s * vol * env
		buf[i * 2 + 1] += s * vol * env

func _add_drum(buf: PackedFloat32Array, start: float, dur: float, vol: float, rng: RandomNumberGenerator) -> void:
	var from := int(start * SAMPLE_RATE)
	var to := int((start + dur) * SAMPLE_RATE)
	to = mini(to, buf.size() / 2)
	for i in range(from, to):
		var local := float(i - from) / SAMPLE_RATE
		var env := exp(-local * 18.0)
		var s := rng.randf_range(-1.0, 1.0) * vol * env
		buf[i * 2] += s
		buf[i * 2 + 1] += s
