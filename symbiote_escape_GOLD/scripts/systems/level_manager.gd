extends Node3D
## LevelManager v8 — ciclo de vida del nivel con nuevas rutas de patrulla.
## Rutas de patrulla actualizadas para el mapa v8 rediseñado.

@onready var _level_geo : Node3D      = $LevelGeometry
@onready var _enemies   : Node3D      = $Enemies
@onready var _hud_node  : CanvasLayer = $HUD

var _player     : Node = null
var _pause_menu : Node = null

# ─────────────────────────────────────────────────────────
# RUTAS DE PATRULLA v8
# Coordenadas y=1 (sobre el suelo). Referencia mapa v8:
#   ENTRADA (0,16)  LAB_A (28,4)   LAB_B (-28,4)
#   CONTROL (0,-20) ARCHIVO (30,-20) CAMARA_FRIA (-30,-20)
#   REACTOR (30,-46) HUB_SEG (-30,-46) SALIDA (0,-60)
#   VESTUARIO (26,22)
# ─────────────────────────────────────────────────────────
const PATROL_ROUTES := {
	# ── Salas de trabajadores ─────────────────────────────
	"entrada": [
		Vector3(-4, 1,  20), Vector3( 4, 1,  20),
		Vector3( 4, 1,  12), Vector3(-4, 1,  12),
	],
	"vestuario": [
		Vector3(22, 1, 20), Vector3(28, 1, 20),
		Vector3(28, 1, 24), Vector3(22, 1, 24),
	],
	"lab_a": [
		Vector3(22, 1,  8), Vector3(34, 1,  8),
		Vector3(34, 1,  0), Vector3(22, 1,  0),
	],
	"lab_b": [
		Vector3(-22, 1,  8), Vector3(-34, 1,  8),
		Vector3(-34, 1,  0), Vector3(-22, 1,  0),
	],
	"control": [
		Vector3(-5, 1, -16), Vector3( 5, 1, -16),
		Vector3( 5, 1, -24), Vector3(-5, 1, -24),
	],
	"archivo": [
		Vector3(24, 1, -16), Vector3(36, 1, -16),
		Vector3(36, 1, -24), Vector3(24, 1, -24),
	],
	"camara_fria": [
		Vector3(-24, 1, -16), Vector3(-34, 1, -16),
		Vector3(-34, 1, -24), Vector3(-24, 1, -24),
	],
	"reactor": [
		Vector3(22, 1, -40), Vector3(38, 1, -40),
		Vector3(38, 1, -52), Vector3(22, 1, -52),
	],
	"hub_seg": [
		Vector3(-22, 1, -40), Vector3(-37, 1, -40),
		Vector3(-37, 1, -52), Vector3(-22, 1, -52),
	],
	"salida": [
		Vector3(-4, 1, -56), Vector3( 4, 1, -56),
		Vector3( 4, 1, -64), Vector3(-4, 1, -64),
	],
	# ── Patrullas de corredor para guardias (más largas) ──
	"corredor_central_sur": [
		# ENTRADA ↔ SALA CONTROL (pasillo central)
		Vector3(-1, 1,  10), Vector3( 1, 1,  10),
		Vector3( 1, 1, -14), Vector3(-1, 1, -14),
	],
	"corredor_central_norte": [
		# SALA CONTROL ↔ SALIDA (pasillo norte)
		Vector3(-1, 1, -30), Vector3( 1, 1, -30),
		Vector3( 1, 1, -54), Vector3(-1, 1, -54),
	],
	"corredor_este": [
		# LAB A ↔ ARCHIVO ↔ REACTOR (flanco este)
		Vector3(28, 1,  0), Vector3(28, 1, -16),
		Vector3(28, 1, -28), Vector3(28, 1, -40),
	],
	"corredor_oeste": [
		# LAB B ↔ CAMARA FRIA ↔ HUB SEG (flanco oeste)
		Vector3(-28, 1,  0), Vector3(-28, 1, -16),
		Vector3(-28, 1, -28), Vector3(-28, 1, -40),
	],
	"corredor_norte_e": [
		# PASILLO NORTE lado este (acceso reactor)
		Vector3(10, 1, -46), Vector3(21, 1, -46),
		Vector3(21, 1, -54), Vector3(10, 1, -54),
	],
	"corredor_norte_o": [
		# PASILLO NORTE lado oeste (acceso hub)
		Vector3(-10, 1, -46), Vector3(-21, 1, -46),
		Vector3(-21, 1, -54), Vector3(-10, 1, -54),
	],
}

func _ready() -> void:
	Alarm.clear()
	_spawn_player()
	_generate_level()
	_spawn_enemies()
	_spawn_pause_menu()
	_wire_signals()
	GM.game_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_fade_in()

# ── Spawning ──────────────────────────────────────────────

func _spawn_player() -> void:
	var ps := load(ScenePaths.PLAYER) as PackedScene
	if ps:
		_player = ps.instantiate()
		_player.position = Vector3(0.0, 1.5, 16.0)  # spawn en ENTRADA v8
		add_child(_player)

func _generate_level() -> void:
	if _level_geo == null: return
	var gen := load("res://scripts/systems/level_generator.gd").new() as Node3D
	if gen == null: return
	_level_geo.add_child(gen)
	gen.generate()
	gen.exit_reached.connect(_on_exit_reached)

func _spawn_enemies() -> void:
	if _enemies == null: return
	var ws := load(ScenePaths.WORKER)   as PackedScene
	var ss := load(ScenePaths.SECURITY) as PackedScene

	# ── Trabajadores ──────────────────────────────────────
	_spawn_worker(ws, Vector3( 3, 1.5,  16), "entrada")
	_spawn_worker(ws, Vector3(-3, 1.5,  14), "entrada")
	_spawn_worker(ws, Vector3(25, 1.5,  22), "vestuario")
	_spawn_worker(ws, Vector3(28, 1.5,   6), "lab_a")
	_spawn_worker(ws, Vector3(32, 1.5,   2), "lab_a")
	_spawn_worker(ws, Vector3(24, 1.5,   2), "lab_a")
	_spawn_worker(ws, Vector3(-28, 1.5,  6), "lab_b")
	_spawn_worker(ws, Vector3(-32, 1.5,  2), "lab_b")
	_spawn_worker(ws, Vector3(-24, 1.5,  2), "lab_b")
	_spawn_worker(ws, Vector3( 0, 1.5, -20), "control")
	_spawn_worker(ws, Vector3( 3, 1.5, -16), "control")
	_spawn_worker(ws, Vector3(-3, 1.5, -24), "control")
	_spawn_worker(ws, Vector3(30, 1.5, -20), "archivo")
	_spawn_worker(ws, Vector3(-30, 1.5, -20), "camara_fria")
	_spawn_worker(ws, Vector3( 0, 1.5, -60), "salida")

	# ── Guardias ──────────────────────────────────────────
	_spawn_guard(ss, Vector3( 0, 1.5,   2), "corredor_central_sur")
	_spawn_guard(ss, Vector3( 0, 1.5, -38), "corredor_central_norte")
	_spawn_guard(ss, Vector3(28, 1.5,  -8), "corredor_este")
	_spawn_guard(ss, Vector3(-28, 1.5, -8), "corredor_oeste")
	_spawn_guard(ss, Vector3(12, 1.5, -46), "corredor_norte_e")
	_spawn_guard(ss, Vector3(-12, 1.5,-46), "corredor_norte_o")
	_spawn_guard(ss, Vector3(30, 1.5, -46), "reactor")

func _spawn_worker(scene: PackedScene, pos: Vector3, route: String) -> void:
	if scene == null: return
	var w := scene.instantiate() as Node3D
	w.position = pos
	_enemies.add_child(w)
	if w.has_method("set_patrol_waypoints") and PATROL_ROUTES.has(route):
		w.set_patrol_waypoints(PATROL_ROUTES[route] as Array)

func _spawn_guard(scene: PackedScene, pos: Vector3, route: String) -> void:
	if scene == null: return
	var s := scene.instantiate() as Node3D
	s.position = pos
	_enemies.add_child(s)
	if s.has_method("set_patrol_waypoints") and PATROL_ROUTES.has(route):
		s.set_patrol_waypoints(PATROL_ROUTES[route] as Array)

func _spawn_pause_menu() -> void:
	var pm := load(ScenePaths.PAUSE_MENU) as PackedScene
	if pm:
		_pause_menu = pm.instantiate()
		add_child(_pause_menu)

# ── Señales ────────────────────────────────────────────────

func _wire_signals() -> void:
	# ── CRÍTICO: conectar AbilitySystem del jugador al HUD ────
	if _player and _hud_node and _hud_node.has_method("set_ability_system"):
		var ab_sys : Node = null
		if _player.has_method("get_ability_system"):
			ab_sys = _player.get_ability_system()
		_hud_node.set_ability_system(ab_sys)

	# ── Drone ambiental: iniciar en CALMA ─────────────────────
	AudioMgr.play_ambient_start(0)
	Alarm.level_changed.connect(func(lv: int): AudioMgr.play_ambient_start(lv))

	# ── Audio de nivel up ────────────────────────────────────
	ProgressionMgr.level_up.connect(func(_lv: int): AudioMgr.play_level_up())
	if _player and _player.has_method("get_ability_system"):
		var ab := _player.get_ability_system()
		if ab: ab.passive_gained.connect(_on_passive_gained_notify)

	if _hud_node:
		GM.player_health_changed.connect(_on_health_changed)
		GM.absorption_count_changed.connect(_on_absorb_changed)
		Alarm.level_changed.connect(_on_alarm_changed_hud)

func _on_passive_gained_notify(ability_name: String) -> void:
	if _hud_node and _hud_node.has_method("show_absorb_notification"):
		_hud_node.show_absorb_notification(ability_name)

func _on_health_changed(hp: float, mx: float) -> void:
	if _hud_node and _hud_node.has_method("update_health"):
		_hud_node.update_health(hp, mx)
	AudioMgr.set_heartbeat(hp / maxf(mx, 1.0))

func _on_absorb_changed(c: int) -> void:
	if _hud_node and _hud_node.has_method("update_absorptions"):
		_hud_node.update_absorptions(c)

func _on_alarm_changed_hud(lvl: int) -> void:
	if _hud_node and _hud_node.has_method("update_alarm"):
		_hud_node.update_alarm(lvl)

func _on_exit_reached() -> void:
	AudioMgr.play_ambient_stop()
	GM.level_complete.emit()

# ── Fade in ────────────────────────────────────────────────

func _fade_in() -> void:
	# Oscurecimiento inicial (overlay negro)
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas := CanvasLayer.new()
	canvas.add_child(overlay)
	add_child(canvas)
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		canvas.queue_free()
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _pause_menu and _pause_menu.has_method("toggle"):
			_pause_menu.toggle()
