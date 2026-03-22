extends Node
## AlarmSystem v10 — optimizado.
##
## OPTIMIZACIONES vs v9:
##   • _process reemplazado por Timer dedicado: solo activo cuando hay decaimiento pendiente.
##   • _pulse_lights limita la animación a MAX_ANIMATED_LIGHTS representativas por categoría.
##   • _lights separado en Array[OmniLight3D] tipado (evita boxing).
##   • _lights_dirty: limpieza de referencias inválidas diferida, no en cada pulse.

signal level_changed(lv: int)
signal noise_reported(pos: Vector3)

enum Level { CALMA = 0, ALERTA = 1, ALARMA = 2, LOCKDOWN = 3 }

const MAX_ANIMATED_LIGHTS := 12   # máx luces animadas por evento de alarma

var current       : Level = Level.CALMA
var active_guards : int   = 0
var last_noise_pos: Vector3 = Vector3.ZERO

var _decay_timer  : float = 0.0
var _lights       : Array[OmniLight3D] = []
var _lights_dirty : bool  = false   # hay luces inválidas que limpiar
var _ltween       : Tween = null

# Timer de decaimiento — solo corre cuando hay algo que decaer
var _decay_ticker : Timer

func _ready() -> void:
	_decay_ticker = Timer.new()
	_decay_ticker.wait_time   = 0.25   # tick cada 250 ms es suficiente para decaimiento
	_decay_ticker.autostart   = false
	_decay_ticker.timeout.connect(_tick_decay)
	add_child(_decay_ticker)

# ── Sin _process — el decaimiento lo maneja _decay_ticker ──

func _tick_decay() -> void:
	if active_guards > 0:
		_decay_timer = 0.0
		return
	# CALMA ya no tiene nada que decaer
	if current == Level.CALMA:
		_decay_ticker.stop()
		return
	_decay_timer += _decay_ticker.wait_time
	match current:
		Level.ALERTA:
			if _decay_timer >= Constants.ALARM_ALERTA_TIMEOUT:
				_decay_timer = 0.0; _apply_level(Level.CALMA)
		Level.ALARMA:
			if _decay_timer >= Constants.ALARM_ALARMA_TIMEOUT:
				_decay_timer = 0.0; _apply_level(Level.ALERTA)
		Level.LOCKDOWN:
			if _decay_timer >= Constants.ALARM_LOCKDOWN_DURATION:
				_decay_timer = 0.0; _apply_level(Level.ALARMA)

# ── API pública ───────────────────────────────────────────

## Registra una luz para pulso de alarma. Llama queue_free() normalmente
## y el Array se limpará en el próximo _pulse_lights.
func register_light(lt: OmniLight3D) -> void:
	_lights.append(lt)

## Worker vio al jugador → sube a ALERTA.
func worker_spotted(pos: Vector3) -> void:
	last_noise_pos = pos
	noise_reported.emit(pos)
	if current < Level.ALERTA:
		_apply_level(Level.ALERTA)
		_decay_timer = 0.0

## Guard confirmó amenaza → sube a ALARMA/LOCKDOWN.
func guard_confirmed(guard: Node) -> void:
	active_guards += 1
	last_noise_pos = guard.global_position
	noise_reported.emit(guard.global_position)
	var target := Level.ALARMA if active_guards < 2 else Level.LOCKDOWN
	if current < target: _apply_level(target)
	elif active_guards >= 2 and current < Level.LOCKDOWN: _apply_level(Level.LOCKDOWN)
	_decay_timer = 0.0   # detener decaimiento mientras guards activos

## Guard volvió a patrullar.
func guard_returned(_guard: Node) -> void:
	active_guards = maxi(0, active_guards - 1)
	_decay_timer  = 0.0
	if active_guards == 0 and current > Level.CALMA:
		_decay_ticker.start()   # reanudar decaimiento

## Guard absorbido.
func guard_absorbed(_guard: Node) -> void:
	active_guards = maxi(0, active_guards - 1)
	_decay_timer  = 0.0
	if active_guards == 0 and current > Level.CALMA:
		_decay_ticker.start()

## LOCKDOWN manual.
func lockdown() -> void:
	_apply_level(Level.LOCKDOWN); _decay_timer = 0.0

## Resetear todo el sistema.
func clear() -> void:
	active_guards = 0; _decay_timer = 0.0
	_decay_ticker.stop()
	_apply_level(Level.CALMA)

func get_level() -> int: return int(current)
func is_at_least(lv: Level) -> bool: return current >= lv

# ── Legado ────────────────────────────────────────────────
func raise_alert(_g: Node) -> void: guard_confirmed(_g)
func lower_alert(_g: Node) -> void: guard_returned(_g)
func suspicious()           -> void: worker_spotted(Vector3.ZERO)

# ── Privado ───────────────────────────────────────────────

func _apply_level(lv: Level) -> void:
	if lv == current: return
	current = lv
	level_changed.emit(int(lv))
	GM.alarm_changed.emit(int(lv) as int)
	_pulse_lights()
	AudioMgr.play_alarm_change(int(lv))   # stinger auditivo de cambio de estado
	# Asegurarse de que el timer de decaimiento esté corriendo si hay nivel elevado
	if lv > Level.CALMA and _decay_ticker.is_stopped():
		_decay_ticker.start()

func _pulse_lights() -> void:
	if _ltween: _ltween.kill(); _ltween = null

	# Limpieza diferida de referencias inválidas
	if _lights_dirty:
		var i := _lights.size() - 1
		while i >= 0:
			if not is_instance_valid(_lights[i]): _lights.remove_at(i)
			i -= 1
		_lights_dirty = false

	if _lights.is_empty(): return

	var col    := _level_color()
	var dim    := Color(col.r * 0.10, col.g * 0.10, col.b * 0.10, 1.0)
	var speeds : Array[float] = [0.7, 0.45, 0.20, 0.08]
	var sp     : float = speeds[clampi(int(current), 0, 3)]

	# ── OPTIMIZACIÓN CLAVE: animar solo un subconjunto representativo ─
	# Seleccionamos cada N-ésima luz para tener máximo MAX_ANIMATED_LIGHTS.
	var total  := _lights.size()
	var step   := maxi(1, total / MAX_ANIMATED_LIGHTS as int)
	_ltween = create_tween().set_loops()
	for i in range(0, total, step):
		if not is_instance_valid(_lights[i]): continue
		_ltween.tween_property(_lights[i], "light_color", col, sp)
		_ltween.tween_property(_lights[i], "light_color", dim, sp)

func _level_color() -> Color:
	match current:
		Level.CALMA:    return Color(0.70, 0.85, 1.00, 1.0)
		Level.ALERTA:   return Color(1.00, 0.75, 0.00, 1.0)
		Level.ALARMA:   return Color(1.00, 0.10, 0.00, 1.0)
		_:              return Color(1.00, 0.00, 0.50, 1.0)
