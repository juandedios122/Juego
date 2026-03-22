extends Node
## ProgressionMgr — XP, niveles y poder global del simbionte.
## Ahora lee/escribe desde el slot activo de SaveMgr.

signal xp_changed(xp_in_level: int, xp_to_next: int, total_xp: int)
signal level_up(new_level: int)

var current_level : int = 1
var total_xp      : int = 0
var xp_in_level   : int = 0

func _ready() -> void:
	pass   # La carga se hace en load_from_slot(), llamado por GM al seleccionar slot.

# ── Carga/guardado por slot ───────────────────────────────

func load_from_slot() -> void:
	current_level = int(SaveMgr.get_val("player_level", 1))
	total_xp      = int(SaveMgr.get_val("player_total_xp", 0))
	xp_in_level   = total_xp - _xp_for_level(current_level)
	xp_in_level   = maxi(0, xp_in_level)

func _save() -> void:
	SaveMgr.set_val("player_level",    current_level)
	SaveMgr.set_val("player_total_xp", total_xp)

# ── API pública ──────────────────────────────────────────

func add_xp(amount: int) -> void:
	total_xp    += amount
	xp_in_level += amount
	while current_level < Constants.MAX_LEVEL:
		var needed := get_xp_to_next()
		if xp_in_level >= needed:
			xp_in_level -= needed
			current_level += 1
			level_up.emit(current_level)
		else:
			break
	_save()
	xp_changed.emit(xp_in_level, get_xp_to_next(), total_xp)

func get_xp_fraction() -> float:
	if current_level >= Constants.MAX_LEVEL: return 1.0
	var needed := get_xp_to_next()
	return float(xp_in_level) / float(needed) if needed > 0 else 1.0

func get_xp_to_next() -> int:
	if current_level >= Constants.MAX_LEVEL: return 1
	var thresholds : Array = Constants.LEVEL_XP
	if current_level < thresholds.size():
		return int(thresholds[current_level]) - int(thresholds[current_level - 1])
	return 9999

func is_skill_unlocked(skill_id: String) -> bool:
	match skill_id:
		"DASH":      return current_level >= Constants.SKILL_DASH_UNLOCK
		"PULSO":     return current_level >= Constants.SKILL_PULSE_UNLOCK
		"CAMUFLAJE": return current_level >= Constants.SKILL_CAMO_UNLOCK
	return false

func get_bonus_health() -> float:
	return float(current_level - 1) * Constants.HEALTH_PER_LEVEL

func get_damage_reduction(absorption_count: int) -> float:
	return minf(float(absorption_count) * Constants.POWER_DR_PER_ABSORB, Constants.POWER_DR_MAX)

func get_unlock_level(skill_id: String) -> int:
	match skill_id:
		"DASH":      return Constants.SKILL_DASH_UNLOCK
		"PULSO":     return Constants.SKILL_PULSE_UNLOCK
		"CAMUFLAJE": return Constants.SKILL_CAMO_UNLOCK
	return 99

func reset() -> void:
	current_level = 1
	total_xp      = 0
	xp_in_level   = 0

# ── Privado ───────────────────────────────────────────────

func _xp_for_level(lv: int) -> int:
	if lv <= 1: return 0
	var thresholds : Array = Constants.LEVEL_XP
	return int(thresholds[mini(lv - 1, thresholds.size() - 1)])
