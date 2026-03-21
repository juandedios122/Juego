extends Node
## AudioMgr — Gold build. Final polish.
## NUEVO: impact_boom, detection_sting, absorb_hum_loop, reverb_tail,
##        guard_radio_click, jump, land, heartbeat, absorb_stop.

const SR   := 44100
const SR_D := 22050

var _drone_cache       : Array[AudioStreamWAV] = []
var _drone_cache_ready : bool  = false
var _ambient_player    : AudioStreamPlayer = null
var _ambient_level     : int   = -1
var _absorb_player     : AudioStreamPlayer = null  # loop durante absorción
var _heartbeat_player  : AudioStreamPlayer = null
var _heartbeat_active  : bool  = false

func _ready() -> void:
	call_deferred("_prebuild_all")

func _prebuild_all() -> void:
	_drone_cache.resize(4)
	for i in 4: _drone_cache[i] = _make_ambient_drone(i)
	_drone_cache_ready = true
	_absorb_player = AudioStreamPlayer.new()
	_absorb_player.stream    = _make_absorb_hum()
	_absorb_player.volume_db = -40.0
	add_child(_absorb_player)
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.stream    = _make_heartbeat()
	_heartbeat_player.volume_db = -40.0
	add_child(_heartbeat_player)

# ── API pública ───────────────────────────────────────────

## Absorción
func play_absorb_start() -> void:
	_play(_make_sweep(50.0, 130.0, Constants.ABSORB_TIME, 0.26))
	if _absorb_player:
		_absorb_player.play()
		var tw := create_tween()
		tw.tween_property(_absorb_player, "volume_db", -7.0, 0.45)

func play_absorb_stop() -> void:
	if _absorb_player and _absorb_player.playing:
		var tw := create_tween()
		tw.tween_property(_absorb_player, "volume_db", -40.0, 0.22)
		await tw.finished
		_absorb_player.stop()

func play_absorb_complete() -> void:
	play_absorb_stop()
	_play(_make_sweep(100.0, 1400.0, 0.48, 0.90))
	_play_delayed(_make_impact_boom(), 0.10)
	_play_delayed(_make_reverb_tail(800.0, 0.55, 0.38), 0.18)

func play_absorb_pulse() -> void:
	_play(_make_tone(90.0 + randf() * 55.0, 0.08, 0.22))

## Progresión
func play_level_up() -> void: _play_arpeggio()
func play_ability_gained() -> void: _play(_make_sweep(280.0, 620.0, 0.26, 0.55))

## Habilidades
func play_skill_dash() -> void: _play(_make_sweep(900.0, 110.0, 0.13, 0.68))
func play_skill_pulso() -> void:
	_play(_make_sweep(55.0, 3200.0, 0.06, 1.0))
	_play_delayed(_make_sweep(3200.0, 38.0, 0.65, 0.78), 0.07)
func play_skill_camuflaje() -> void: _play(_make_sweep(420.0, 4500.0, 0.32, 0.44))

## Jugador
func play_damage() -> void:
	_play(_make_noise(0.11, 0.80))
	_play_delayed(_make_tone(55.0, 0.18, 0.38), 0.04)
func play_footstep() -> void: _play(_make_footstep())
func play_jump()    -> void: _play(_make_sweep(130.0, 300.0, 0.07, 0.22))
func play_land()    -> void:
	_play(_make_noise(0.055, 0.50))
	_play_delayed(_make_tone(68.0, 0.14, 0.32), 0.02)

## Guards
func play_guard_spotted() -> void:
	## Sting de detección — el sonido más importante del juego de sigilo
	_play(_make_detection_sting())
func play_guard_chase() -> void:
	var chord: Array = [110.0, 138.0, 185.0, 220.0]
	_play(_make_chord(chord, 0.28, 0.80))
func play_guard_attack() -> void: _play(_make_noise(0.075, 0.65))
func play_guard_radio() -> void:
	## Clic de radio al coordinar con otros guards
	_play(_make_sweep(1800.0, 2400.0, 0.04, 0.28))
	_play_delayed(_make_sweep(2400.0, 1800.0, 0.04, 0.22), 0.06)

## Workers
func play_worker_flee() -> void:
	_play(_make_sweep(380.0, 1100.0, 0.08, 0.35))
	_play_delayed(_make_sweep(1100.0, 650.0, 0.11, 0.24), 0.09)
func play_worker_hide() -> void: _play(_make_sweep(420.0, 140.0, 0.20, 0.22))

## Nivel
func play_door_unlock() -> void:
	_play(_make_sweep(190.0, 950.0, 0.22, 0.65))
	_play_delayed(_make_sweep(950.0, 420.0, 0.32, 0.50), 0.24)
func play_xp_orb() -> void:
	_play(_make_sweep(720.0, 1480.0, 0.14, 0.55))
	_play_delayed(_make_tone(1480.0, 0.20, 0.40), 0.18)
func play_hazard_tick() -> void: _play(_make_tone(45.0 + randf() * 22.0, 0.055, 0.22))
func play_cinematic_intro() -> void: _play(_make_sweep(32.0, 145.0, 3.0, 0.24))

## Alarma
func play_alarm_change(new_level: int) -> void:
	match new_level:
		0: _play(_make_sweep(460.0, 120.0, 0.70, 0.40))
		1:
			_play(_make_sweep(460.0, 940.0, 0.09, 0.62))
			_play_delayed(_make_detection_sting(), 0.06)
		2:
			var chord: Array = [220.0, 277.0, 370.0]
			_play(_make_chord(chord, 0.40, 0.88))
			_play_delayed(_make_noise(0.07, 0.52), 0.05)
		3: _play(_make_siren(168.0, 340.0, 0.90, 0.95))

## Ambiente adaptativo
func play_ambient_start(alarm_level: int) -> void:
	if _ambient_level == alarm_level: return
	_ambient_level = alarm_level
	if _ambient_player:
		_ambient_player.stop(); _ambient_player.queue_free(); _ambient_player = null
	if not _drone_cache_ready: return
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream    = _drone_cache[clampi(alarm_level, 0, 3)]
	_ambient_player.volume_db = -15.0 - float(3 - alarm_level) * 4.0
	add_child(_ambient_player); _ambient_player.play()
	_ambient_player.finished.connect(func():
		if _ambient_player and is_instance_valid(_ambient_player): _ambient_player.play()
	)

func play_ambient_stop() -> void:
	if _ambient_player:
		_ambient_player.stop(); _ambient_player.queue_free(); _ambient_player = null
	_ambient_level = -1

## Heartbeat con salud baja
func set_heartbeat(hp_fraction: float) -> void:
	if hp_fraction < 0.35:
		if not _heartbeat_active:
			_heartbeat_active = true
			_heartbeat_player.volume_db = -13.0
			_loop_heartbeat(hp_fraction)
	else:
		_heartbeat_active = false
		var tw := create_tween()
		tw.tween_property(_heartbeat_player, "volume_db", -40.0, 1.8)

func _loop_heartbeat(hp_fraction: float) -> void:
	if not _heartbeat_active: return
	_heartbeat_player.play()
	var bpm      := lerp(148.0, 72.0, clampf(hp_fraction * 3.0, 0.0, 1.0))
	var interval := 60.0 / bpm
	await get_tree().create_timer(interval).timeout
	_loop_heartbeat(hp_fraction)

# ── GENERADORES ───────────────────────────────────────────

func _make_impact_boom() -> AudioStreamWAV:
	## Sub-bass: lo que se siente en el pecho al absorber un enemigo
	var n := int(SR * 0.65); var data := PackedByteArray(); data.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var phase := 0.0
	for i in n:
		var p    := float(i) / float(n)
		var env  := exp(-p * 8.0) * (1.0 - exp(-p * 120.0))
		var freq := 60.0 * exp(-p * 5.0) + 28.0
		phase    += TAU * freq / float(SR)
		_write16(data, i, (sin(phase)*0.65 + rng.randf_range(-1.0,1.0)*exp(-p*18.0)*0.35) * env * 0.92)
	return _finalize(data, SR)

func _make_detection_sting() -> AudioStreamWAV:
	## El sonido "!" cuando un guard te detecta — agudo + bajo inconfundibles
	var n := int(SR * 0.22); var data := PackedByteArray(); data.resize(n * 2)
	var p1 := 0.0; var p2 := 0.0
	for i in n:
		var p := float(i)/float(n)
		p1 += TAU * 1200.0 / float(SR); p2 += TAU * 80.0 / float(SR)
		var v := sin(p1) * _env(p,0.01,0.35) * exp(-p*6.0) * 0.55
		v     += sin(p2) * _env(p,0.04,0.25) * exp(-p*4.0) * 0.45
		_write16(data, i, v * 0.88)
	return _finalize(data, SR)

func _make_reverb_tail(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	## Simula reverb: tres ecos decrecientes a 82ms, 164ms, 246ms
	var n := int(SR * duration); var data := PackedByteArray(); data.resize(n * 2)
	var delay := int(SR * 0.082); var phase := 0.0
	for i in n:
		var p := float(i)/float(n); phase += TAU * freq / float(SR)
		var v := sin(phase) * exp(-p * 9.0) * volume
		if i >= delay:
			v += sin(phase) * exp(-float(i-delay)/float(n) * 12.0) * volume * 0.4
		if i >= delay * 2:
			v += sin(phase) * exp(-float(i-delay*2)/float(n) * 15.0) * volume * 0.2
		_write16(data, i, v)
	return _finalize(data, SR)

func _make_absorb_hum() -> AudioStreamWAV:
	## Loop orgánico que suena mientras el jugador absorbe
	var n := int(SR_D * 2.8); var data := PackedByteArray(); data.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	var p1 := 0.0; var p2 := 0.0; var p3 := 0.0
	for i in n:
		var t := float(i)/float(n); var fade := minf(t*6.0, minf((1.0-t)*6.0, 1.0))
		p1 += TAU*82.0/float(SR_D); p2 += TAU*110.5/float(SR_D); p3 += TAU*55.0/float(SR_D)
		var lfo := sin(TAU * 0.8 * t * 2.8)
		var v   := (sin(p1)*0.5 + sin(p2)*0.35 + sin(p3)*0.25) * (0.85 + lfo*0.12)
		v += rng.randf_range(-1.0,1.0) * 0.04
		_write16(data, i, v * 0.22 * fade)
	return _finalize(data, SR_D)

func _make_ambient_drone(alarm_level: int) -> AudioStreamWAV:
	var n := int(SR_D * 4.0); var data := PackedByteArray(); data.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 42 + alarm_level
	var all_freqs : Array = [
		[38.0, 55.0, 82.5], [38.0, 55.0, 82.5, 110.0],
		[38.0, 55.0, 82.5, 110.0, 138.6], [38.0, 55.0, 73.4, 82.5, 110.0, 138.6],
	]
	var freqs  : Array = all_freqs[clampi(alarm_level, 0, 3)]
	var phases := PackedFloat64Array(); phases.resize(freqs.size())
	var vol    := 0.065 + float(alarm_level) * 0.03
	for i in n:
		var p    := float(i)/float(n); var fade := minf(p*8.0, minf((1.0-p)*8.0, 1.0))
		var sum  := 0.0
		for j in freqs.size():
			phases[j] += TAU * float(freqs[j]) / float(SR_D)
			sum        += sin(phases[j]) * (1.0 - float(j) * 0.08)
		sum = sum / float(freqs.size()) + rng.randf_range(-1.0,1.0) * 0.012
		_write16(data, i, sum * vol * fade)
	return _finalize(data, SR_D)

func _make_heartbeat() -> AudioStreamWAV:
	var n := int(SR * 0.36); var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var p  := float(i)/float(n)
		var v1 := sin(TAU*52.0*float(i)/float(SR)) * exp(-p*22.0) * 0.72
		var p2 := maxf(0.0, p - 0.19)
		var v2 := sin(TAU*47.0*float(i)/float(SR)) * exp(-p2*28.0) * 0.52
		_write16(data, i, (v1 + v2) * 0.85)
	return _finalize(data, SR)

func _make_tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SR*dur); var d := PackedByteArray(); d.resize(n*2)
	for i in n: _write16(d, i, sin(TAU*freq*float(i)/float(SR)) * _env(float(i)/float(n),0.06,0.24) * vol)
	return _finalize(d, SR)

func _make_sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SR*dur); var d := PackedByteArray(); d.resize(n*2); var ph := 0.0
	for i in n:
		var p := float(i)/float(n); ph += TAU*(f0+(f1-f0)*p*p)/float(SR)
		_write16(d, i, sin(ph) * _env(p,0.04,0.25) * vol)
	return _finalize(d, SR)

func _make_noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SR*dur); var d := PackedByteArray(); d.resize(n*2)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in n: _write16(d, i, rng.randf_range(-1.0,1.0) * _env(float(i)/float(n),0.01,0.10) * vol)
	return _finalize(d, SR)

func _make_chord(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SR*dur); var d := PackedByteArray(); d.resize(n*2)
	var phases := PackedFloat64Array(); phases.resize(freqs.size())
	for i in n:
		var env := _env(float(i)/float(n),0.02,0.40); var sum := 0.0
		for j in freqs.size(): phases[j] += TAU*float(freqs[j])/float(SR); sum += sin(phases[j])
		_write16(d, i, sum/float(freqs.size()) * env * vol)
	return _finalize(d, SR)

func _make_siren(f_low: float, f_high: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SR*dur); var d := PackedByteArray(); d.resize(n*2); var ph := 0.0
	for i in n:
		var p := float(i)/float(n); var lfo := (sin(TAU*2.8*p*dur)+1.0)*0.5
		ph += TAU*(f_low+(f_high-f_low)*lfo)/float(SR)
		_write16(d, i, sin(ph) * _env(p,0.04,0.14) * vol)
	return _finalize(d, SR)

func _make_footstep() -> AudioStreamWAV:
	var n := int(SR*0.055); var d := PackedByteArray(); d.resize(n*2)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var fb := 75.0 + randf()*48.0; var ph := 0.0
	for i in n:
		var p := float(i)/float(n); var env := (1.0-p)*(1.0-p)*(1.0-p)
		ph += TAU*fb/float(SR)
		_write16(d, i, (sin(ph)*0.5 + rng.randf_range(-1.0,1.0)*0.5) * env * 0.25)
	return _finalize(d, SR)

func _env(t: float, atk: float, rel: float) -> float:
	if t < atk: return t/atk
	if t > 1.0-rel: return (1.0-t)/rel
	return 1.0

func _write16(data: PackedByteArray, idx: int, v: float) -> void:
	var s := clampi(int(v*32767.0), -32768, 32767)
	data[idx*2] = s & 0xFF; data[idx*2+1] = (s >> 8) & 0xFF

func _finalize(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new(); s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = mix_rate; s.stereo = false; s.data = data; return s

func _play(stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new(); p.stream = stream; add_child(p); p.play()
	p.finished.connect(p.queue_free)

func _play_delayed(stream: AudioStreamWAV, delay: float) -> void: _async_delayed(stream, delay)
func _async_delayed(stream: AudioStreamWAV, delay: float) -> void:
	await get_tree().create_timer(delay).timeout; _play(stream)
func _play_arpeggio() -> void: _async_arpeggio()
func _async_arpeggio() -> void:
	var freqs : Array = [261.6, 329.6, 392.0, 523.3, 659.3]
	for i in freqs.size():
		_play(_make_tone(float(freqs[i]), 0.20, 0.55))
		await get_tree().create_timer(0.10).timeout
