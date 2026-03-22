extends Node
## SaveManager — 3 slots de guardado independientes.
## Cada slot tiene su propio archivo: user://save_slot_0.cfg, etc.
## El slot activo se selecciona desde el menú principal.

const MAX_SLOTS   := 3
const SLOT_PREFIX := "user://save_slot_"

var active_slot : int = -1   # -1 = sin slot cargado

var _cfgs : Array[ConfigFile] = []

func _ready() -> void:
	_cfgs.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		_cfgs[i] = ConfigFile.new()
		_cfgs[i].load(SLOT_PREFIX + str(i) + ".cfg")
	# Aplicar volumen del slot 0 como default hasta que se elija slot
	var vol : float = float(_cfgs[0].get_value("settings", "master_vol", 1.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))

# ── Selección de slot ─────────────────────────────────────

func select_slot(slot: int) -> void:
	active_slot = clampi(slot, 0, MAX_SLOTS - 1)
	var vol : float = float(get_val("master_vol", 1.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))

func get_active_slot() -> int:
	return active_slot

## Devuelve un diccionario con el resumen de cada slot para mostrar en el menú.
func get_slot_summary(slot: int) -> Dictionary:
	var cfg := _cfgs[clampi(slot, 0, MAX_SLOTS - 1)]
	return {
		"exists":      cfg.has_section("data"),
		"level":       int(cfg.get_value("data", "player_level", 1)),
		"total_xp":    int(cfg.get_value("data", "player_total_xp", 0)),
		"absorptions": int(cfg.get_value("data", "high_score", 0)),
		"play_time":   float(cfg.get_value("data", "play_time", 0.0)),
	}

func delete_slot(slot: int) -> void:
	var idx := clampi(slot, 0, MAX_SLOTS - 1)
	_cfgs[idx] = ConfigFile.new()
	_cfgs[idx].save(SLOT_PREFIX + str(idx) + ".cfg")

# ── API genérica (usa slot activo) ────────────────────────

func get_val(key: String, default: Variant = null) -> Variant:
	if active_slot < 0: return default
	return _cfgs[active_slot].get_value("data", key, default)

func set_val(key: String, val: Variant) -> void:
	if active_slot < 0: return
	_cfgs[active_slot].set_value("data", key, val)
	_cfgs[active_slot].save(SLOT_PREFIX + str(active_slot) + ".cfg")

# ── Configuración (compartida entre slots) ────────────────

func get_master_vol() -> float:
	if active_slot < 0: return 1.0
	return float(_cfgs[active_slot].get_value("settings", "master_vol", 1.0))

func set_master_vol(v: float) -> void:
	var vol := clampf(v, 0.0, 1.0)
	if active_slot >= 0:
		_cfgs[active_slot].set_value("settings", "master_vol", vol)
		_cfgs[active_slot].save(SLOT_PREFIX + str(active_slot) + ".cfg")
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))

func get_mouse_sens() -> float:
	if active_slot < 0: return 0.003
	return float(_cfgs[active_slot].get_value("settings", "mouse_sens", 0.003))

func set_mouse_sens(v: float) -> void:
	if active_slot < 0: return
	_cfgs[active_slot].set_value("settings", "mouse_sens", v)
	_cfgs[active_slot].save(SLOT_PREFIX + str(active_slot) + ".cfg")

func reset_progression() -> void:
	if active_slot < 0: return
	_cfgs[active_slot].set_value("data", "player_level",    1)
	_cfgs[active_slot].set_value("data", "player_total_xp", 0)
	_cfgs[active_slot].set_value("data", "play_time",       0.0)
	_cfgs[active_slot].save(SLOT_PREFIX + str(active_slot) + ".cfg")

func flush() -> void:
	if active_slot < 0: return
	_cfgs[active_slot].save(SLOT_PREFIX + str(active_slot) + ".cfg")

# ── Tiempo de juego ───────────────────────────────────────

func add_play_time(seconds: float) -> void:
	if active_slot < 0: return
	var t := float(get_val("play_time", 0.0)) + seconds
	set_val("play_time", t)
