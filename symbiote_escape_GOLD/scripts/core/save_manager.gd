extends Node
## SaveManager (SaveMgr) — guarda y carga progreso con ConfigFile.
## Incluye: configuración, progresión de nivel, récords.

const SAVE_PATH := "user://save.cfg"

var _cfg := ConfigFile.new()

func _ready() -> void:
	_cfg.load(SAVE_PATH)
	var vol: float = float(get_val("master_vol", 1.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))

func get_val(key: String, default: Variant = null) -> Variant:
	return _cfg.get_value("data", key, default)

func set_val(key: String, val: Variant) -> void:
	_cfg.set_value("data", key, val)
	_cfg.save(SAVE_PATH)

func set_master_vol(v: float) -> void:
	_cfg.set_value("data", "master_vol", v)
	_cfg.save(SAVE_PATH)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(v, 0.0, 1.0)))

func get_master_vol() -> float:
	return _cfg.get_value("data", "master_vol", 1.0)

func get_mouse_sens() -> float:
	return _cfg.get_value("data", "mouse_sens", 0.003)

func set_mouse_sens(v: float) -> void:
	_cfg.set_value("data", "mouse_sens", v)
	_cfg.save(SAVE_PATH)

func reset_progression() -> void:
	_cfg.set_value("data", "player_level",    1)
	_cfg.set_value("data", "player_total_xp", 0)
	_cfg.save(SAVE_PATH)

func flush() -> void:
	_cfg.save(SAVE_PATH)
