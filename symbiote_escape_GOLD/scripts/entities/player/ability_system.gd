extends Node
## AbilitySystem — gestor modular de habilidades del simbionte.
## Habilidades pasivas: absorbidas de enemigos (temporales o permanentes).
## Habilidades activas: desbloqueadas por nivel, activadas manualmente con cooldown.

signal passive_gained(ability_name: String)
signal passive_lost(ability_name: String)
signal active_used(skill_id: String)
signal cooldown_updated(skill_id: String, remaining: float, total: float)

# ── Datos de habilidades pasivas ─────────────────────────
# Probabilidades por tipo de enemigo absorbido
const WORKER_POOL    := ["SIGILO", "VELOCIDAD", "SENTIDO"]
const WORKER_WEIGHTS := [0.45, 0.35, 0.20]

const SECURITY_POOL    := ["SUPER_SALTO", "FUERZA", "VELOCIDAD"]
const SECURITY_WEIGHTS := [0.45, 0.35, 0.20]

const PASSIVE_DURATIONS := {
	"VELOCIDAD":   Constants.ABILITY_SPEED_DUR,
	"SUPER_SALTO": Constants.ABILITY_JUMP_DUR,
	"FUERZA":      -1.0,   # permanente
	"SIGILO":      Constants.ABILITY_STEALTH_DUR,
	"SENTIDO":     Constants.ABILITY_SENSE_DUR,
}

# ── Datos de habilidades activas ─────────────────────────
const ACTIVE_SKILLS    := ["DASH", "PULSO", "CAMUFLAJE"]
const ACTIVE_COOLDOWNS := {
	"DASH":      Constants.SKILL_DASH_COOLDOWN,
	"PULSO":     Constants.SKILL_PULSE_COOLDOWN,
	"CAMUFLAJE": Constants.SKILL_CAMO_COOLDOWN,
}

# ── Estado interno ────────────────────────────────────────
var passives  : Dictionary = {}   # nombre → true
var _timers   : Dictionary = {}   # nombre → segundos restantes
var _cooldowns: Dictionary = {}   # skill_id → [remaining, total]
var _rng      := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for skill in ACTIVE_SKILLS:
		_cooldowns[skill] = [0.0, ACTIVE_COOLDOWNS[skill]]

func _process(delta: float) -> void:
	# ── Expirar pasivas con duración ─────────────────────
	var expired : Array[String] = []
	for ability_name in _timers:
		_timers[ability_name] -= delta
		if _timers[ability_name] <= 0.0:
			expired.append(ability_name)
	for ability_name in expired:
		_timers.erase(ability_name)
		passives.erase(ability_name)
		passive_lost.emit(ability_name)

	# ── Cooldowns de activas — emit solo cuando hay cambio real ─
	for skill in ACTIVE_SKILLS:
		var cd : Array = _cooldowns[skill]
		if cd[0] > 0.0:
			var prev : float = float(cd[0])
			cd[0] = maxf(0.0, cd[0] - delta)
			cooldown_updated.emit(skill, cd[0], cd[1])
			if prev > 0.0 and cd[0] == 0.0:
				cooldown_updated.emit(skill, 0.0, cd[1])

# ── API pública ──────────────────────────────────────────

## Otorgar habilidad pasiva según tipo de enemigo absorbido.
func grant_from_enemy(enemy_type: String) -> String:
	var pool    : Array
	var weights : Array
	if enemy_type == "security":
		pool    = SECURITY_POOL
		weights = SECURITY_WEIGHTS
	else:
		pool    = WORKER_POOL
		weights = WORKER_WEIGHTS
	var chosen := _weighted_pick(pool, weights)
	_grant_passive(chosen)
	return chosen

## Intentar usar habilidad activa. Retorna true si se ejecutó.
func use_active(skill_id: String) -> bool:
	if not ProgressionMgr.is_skill_unlocked(skill_id):
		return false
	var cd : Array = _cooldowns.get(skill_id, [0.0, 1.0])
	if cd[0] > 0.0:
		return false
	# Poner en cooldown
	_cooldowns[skill_id][0] = _cooldowns[skill_id][1]
	cooldown_updated.emit(skill_id, _cooldowns[skill_id][0], _cooldowns[skill_id][1])
	active_used.emit(skill_id)
	# Efectos especiales de la habilidad
	if skill_id == "CAMUFLAJE":
		_grant_passive("SIGILO", Constants.SKILL_CAMO_DURATION)
	return true

## Verificar si una pasiva está activa.
func has_passive(name: String) -> bool:
	return passives.has(name)

## Compatibilidad: alias para código legacy.
func has(passive_name: String) -> bool:
	return has_passive(passive_name)

## Segundos restantes de una pasiva (-1 si permanente, 0 si inactiva).
func get_remaining(name: String) -> float:
	if not passives.has(name):
		return 0.0
	return _timers.get(name, -1.0)

## Fracción de cooldown restante [0..1] de una habilidad activa.
func get_cooldown_fraction(skill_id: String) -> float:
	var cd : Array = _cooldowns.get(skill_id, [0.0, 1.0])
	return cd[0] / cd[1] if cd[1] > 0.0 else 0.0

## Nombres de todas las pasivas actualmente activas.
func get_active_passives() -> Array:
	return passives.keys()

# ── Privado ──────────────────────────────────────────────

func _grant_passive(ability: String, override_dur: float = -999.0) -> void:
	passives[ability] = true
	var dur : float
	if override_dur != -999.0:
		dur = override_dur
	else:
		dur = PASSIVE_DURATIONS.get(ability, 15.0)
	if dur > 0.0:
		_timers[ability] = dur
	passive_gained.emit(ability)

func _weighted_pick(pool: Array, weights: Array) -> String:
	var total := 0.0
	for w in weights: total += w
	var r     := _rng.randf() * total
	var cumul := 0.0
	for i in pool.size():
		cumul += weights[i]
		if r <= cumul:
			return pool[i]
	return pool[-1]
