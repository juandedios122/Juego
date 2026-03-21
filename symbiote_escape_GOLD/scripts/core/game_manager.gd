extends Node
## GM — GameManager, singleton principal.
## Gestiona el estado global, señales y transiciones de escena.

signal game_over
signal level_complete
signal absorption_count_changed(count: int)
signal player_health_changed(hp: float, max_hp: float)
signal alarm_changed(level: int)

var game_active      : bool = false
var absorption_count : int  = 0
var high_score       : int  = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	high_score   = SaveMgr.get_val("high_score", 0)
	# Auto-conectar señales de fin de juego a transiciones de escena
	game_over.connect(go_to_game_over)
	level_complete.connect(go_to_victory)

# ── Transiciones ──────────────────────────────────────────

func go_to_menu() -> void:
	_reset()
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)

func go_to_cinematic() -> void:
	get_tree().change_scene_to_file(ScenePaths.INTRO)

func go_to_level() -> void:
	get_tree().change_scene_to_file(ScenePaths.GAME_LEVEL)

func go_to_game_over() -> void:
	game_active = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(ScenePaths.GAME_OVER)

func go_to_victory() -> void:
	game_active = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if absorption_count > high_score:
		high_score = absorption_count
		SaveMgr.set_val("high_score", high_score)
	get_tree().change_scene_to_file(ScenePaths.VICTORY)

# ── Gameplay ──────────────────────────────────────────────

func add_absorption() -> void:
	absorption_count += 1
	absorption_count_changed.emit(absorption_count)

func quit_game() -> void:
	SaveMgr.flush()
	get_tree().quit()

# ── Privado ───────────────────────────────────────────────

func _reset() -> void:
	game_active      = false
	absorption_count = 0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
