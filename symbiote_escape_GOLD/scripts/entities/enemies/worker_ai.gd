extends CharacterBody3D
## WorkerAI — Trabajador de planta nuclear. Versión comercial.
## Mejoras: pánico dramático, llamar a compañeros, mirar al jugador con miedo,
##          animación de "agazaparse", alertar a guards cercanos.

signal spotted_player(pos: Vector3)

enum State { IDLE, PATROL, PANIC, FLEE, HIDE, BEING_ABSORBED, ABSORBED, STUNNED }

var enemy_type       : String  = "worker"
var state            : State   = State.IDLE
var spawn_pos        : Vector3 = Vector3.ZERO
var waypoints        : Array[Vector3] = []
var _wp_idx          : int     = 0
var _pat_timer       : float   = 0.0
var _stun_timer      : float   = 0.0
var _hide_timer      : float   = 0.0
var _panic_timer     : float   = 0.0   # tiempo de animación de pánico
var _spotted_once    : bool    = false
var _alarm_level     : int     = 0
var _called_for_help : bool    = false

var _mesh        : MeshInstance3D    = null
var _head        : MeshInstance3D    = null
var _body_mat    : StandardMaterial3D = null
var _state_light : OmniLight3D       = null
var _panic_particles : CPUParticles3D = null  # partículas de "?" o "!" sobre la cabeza
var _sentido_ring : MeshInstance3D   = null
var _sentido_t   : float = 0.0
var _base_col : Color

# Caché jugador
var _pl_ref : Node = null
var _ab_sys : Node = null

func _ready() -> void:
	add_to_group("worker")
	spawn_pos = global_position
	_build_visual()
	_init_waypoints()
	Alarm.level_changed.connect(_on_alarm_changed)
	call_deferred("_cache_player")

func _cache_player() -> void:
	var g := get_tree().get_nodes_in_group("player")
	if g.size() > 0:
		_pl_ref = g[0]
		if _pl_ref.has_node("AbilitySystem"):
			_ab_sys = _pl_ref.get_node("AbilitySystem")

func _build_visual() -> void:
	_base_col = Color(randf_range(0.38, 0.65), randf_range(0.32, 0.52), randf_range(0.28, 0.48), 1.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3; cap.height = 1.6
	col.shape = cap; col.position = Vector3(0.0, 0.8, 0.0)
	add_child(col)

	_mesh = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.27; cy.bottom_radius = 0.31; cy.height = 1.1
	_mesh.mesh = cy; _mesh.position = Vector3(0.0, 0.8, 0.0)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = _base_col
	_mesh.material_override = _body_mat
	add_child(_mesh)

	_head = MeshInstance3D.new()
	var hs := SphereMesh.new(); hs.radius = 0.21; hs.height = 0.42
	_head.mesh = hs; _head.position = Vector3(0.0, 1.58, 0.0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.75, 0.60, 0.52, 1.0)
	_head.material_override = hm
	add_child(_head)

	var rim_lt := OmniLight3D.new()
	rim_lt.position = Vector3(0.0, 1.0, 0.42); rim_lt.light_color = Color(0.8, 0.6, 0.3, 1.0)
	rim_lt.light_energy = 0.32; rim_lt.omni_range = 1.6; add_child(rim_lt)

	# Luz de estado (color cambia según emoción)
	_state_light = OmniLight3D.new()
	_state_light.position     = Vector3(0.0, 2.2, 0.0)
	_state_light.light_energy = 0.0
	_state_light.omni_range   = 2.5
	add_child(_state_light)

	# Partículas de exclamación de pánico (pequeñas partículas amarillas)
	_panic_particles = CPUParticles3D.new()
	_panic_particles.emitting             = false
	_panic_particles.amount               = 10
	_panic_particles.lifetime             = 0.5
	_panic_particles.one_shot             = false
	_panic_particles.emission_shape       = CPUParticles3D.EMISSION_SHAPE_BOX
	_panic_particles.emission_box_extents = Vector3(0.15, 0.1, 0.15)
	_panic_particles.gravity              = Vector3(0.0, 1.5, 0.0)
	_panic_particles.initial_velocity_min = 0.5
	_panic_particles.initial_velocity_max = 1.5
	_panic_particles.scale_amount_min     = 0.05
	_panic_particles.scale_amount_max     = 0.12
	_panic_particles.color                = Color(1.0, 0.9, 0.0, 1.0)
	_panic_particles.position             = Vector3(0.0, 2.0, 0.0)
	add_child(_panic_particles)

	# Anillo SENTIDO
	_sentido_ring = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.70; sm.height = 1.40
	_sentido_ring.mesh = sm
	var rm := StandardMaterial3D.new()
	rm.albedo_color               = Color(1.0, 0.1, 0.0, 0.18)
	rm.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled           = true
	rm.emission                   = Color(1.0, 0.2, 0.0, 1.0)
	rm.emission_energy_multiplier = 2.0
	_sentido_ring.material_override = rm
	_sentido_ring.position = Vector3(0.0, 0.85, 0.0)
	_sentido_ring.visible  = false
	add_child(_sentido_ring)

func set_patrol_waypoints(pts: Array) -> void:
	waypoints.clear()
	for p in pts: waypoints.append(p as Vector3)
	_wp_idx = 0
	state   = State.PATROL

func _init_waypoints() -> void:
	if not waypoints.is_empty(): return
	var base := global_position
	for i in 4:
		var a := float(i) / 4.0 * TAU
		waypoints.append(base + Vector3(cos(a) * 5.5, 0.0, sin(a) * 5.5))

func _physics_process(delta: float) -> void:
	if not GM.game_active or state == State.ABSORBED: return
	if not is_on_floor(): velocity.y -= Constants.PLAYER_GRAVITY * delta

	if state == State.STUNNED:
		_stun_timer -= delta
		velocity.x = 0.0; velocity.z = 0.0
		if _stun_timer <= 0.0: _resume_after_stun()
		move_and_slide(); return

	if state == State.BEING_ABSORBED:
		velocity.x = 0.0; velocity.z = 0.0
		move_and_slide(); return

	var pl := _get_player()

	match state:
		State.IDLE:    _do_idle(delta)
		State.PATROL:  _do_patrol(delta)
		State.PANIC:   _do_panic(delta, pl)
		State.FLEE:    _do_flee(delta, pl)
		State.HIDE:    _do_hide(delta)

	move_and_slide()
	_scan_for_player(pl)
	_update_sentido_ring(delta)

func _do_idle(delta: float) -> void:
	_pat_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if _pat_timer <= 0.0: state = State.PATROL

func _do_patrol(delta: float) -> void:
	if waypoints.is_empty(): state = State.IDLE; _pat_timer = 2.0; return
	var spd := Constants.WORKER_SPEED_ALERT if _alarm_level >= 1 else Constants.WORKER_SPEED_PATROL
	_move_toward(waypoints[_wp_idx], spd, delta)
	if global_position.distance_to(waypoints[_wp_idx]) < 1.0:
		_wp_idx    = (_wp_idx + 1) % waypoints.size()
		state      = State.IDLE
		_pat_timer = randf_range(1.5, 3.5)

func _do_panic(delta: float, pl: Node) -> void:
	# Fase de pánico: se congela mirando al jugador, se sacude
	_panic_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	# Mirar al jugador con miedo
	if pl and is_instance_valid(pl):
		var to := pl.global_position - global_position; to.y = 0.0
		if to.length_squared() > 0.01:
			look_at(global_position + to.normalized(), Vector3.UP)
	# Sacudida de cabeza (simula terror)
	if _head:
		_head.position.x = sin(_panic_timer * 40.0) * 0.04
	if _panic_timer <= 0.0:
		_head.position.x = 0.0
		_panic_particles.emitting = false
		# Llamar a guards cercanos
		if not _called_for_help:
			_called_for_help = true
			_call_nearby_guards()
		state = State.FLEE

func _do_flee(delta: float, pl: Node) -> void:
	if pl == null: state = State.PATROL; return
	var dist := global_position.distance_to(pl.global_position)
	var away := (global_position - pl.global_position).normalized()
	_move_toward(global_position + away * 6.0, Constants.WORKER_SPEED_FLEE, delta)
	if dist >= Constants.WORKER_HIDE_DIST:
		if _alarm_level >= int(Alarm.Level.ALARMA):
			_enter_hide()
		else:
			_spotted_once = false
			state = State.PATROL

func _do_hide(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	_hide_timer -= delta
	# Agacharse visualmente
	if _mesh: _mesh.scale.y = move_toward(_mesh.scale.y, 0.6, delta * 4.0)
	if _head: _head.position.y = move_toward(_head.position.y, 1.1, delta * 4.0)
	if _hide_timer <= 0.0:
		if _alarm_level < int(Alarm.Level.ALARMA):
			_spotted_once = false
			state = State.PATROL
			# Levantarse
			if _mesh: _mesh.scale.y = 1.0
			if _head: _head.position.y = 1.58
		else:
			_hide_timer = 3.0

func _call_nearby_guards() -> void:
	# Alertar a guards cercanos con la posición del jugador
	var guards := get_tree().get_nodes_in_group("security")
	for g in guards:
		if not is_instance_valid(g): continue
		if global_position.distance_to(g.global_position) <= Constants.WORKER_CALL_RADIUS:
			if g.has_method("receive_worker_alert"):
				g.receive_worker_alert(Alarm.last_noise_pos if Alarm.last_noise_pos != Vector3.ZERO else global_position)

func _scan_for_player(pl: Node) -> void:
	if state == State.BEING_ABSORBED or state == State.ABSORBED: return
	if pl == null: return
	var to_pl := pl.global_position - global_position
	var dist  := to_pl.length()
	var has_stealth := _player_has_stealth(pl)
	if dist < 2.0:
		_trigger_flee(pl); return
	if has_stealth: return
	if dist < Constants.WORKER_DETECT_RANGE_FOV:
		var fwd := -global_transform.basis.z
		if fwd.angle_to(to_pl.normalized()) < Constants.WORKER_FOV_ANGLE:
			_trigger_flee(pl); return
	if dist < Constants.WORKER_DETECT_RANGE:
		_trigger_flee(pl)

func _trigger_flee(pl: Node) -> void:
	if state == State.FLEE or state == State.HIDE or state == State.PANIC: return
	# Primero: pánico breve antes de huir
	state = State.PANIC
	_panic_timer = Constants.WORKER_PANIC_DURATION
	_panic_particles.emitting = true
	_set_state_light(Color(1.0, 0.8, 0.0, 1.0))
	if not _spotted_once:
		_spotted_once = true
		spotted_player.emit(pl.global_position)
		Alarm.worker_spotted(pl.global_position)
		AudioMgr.play_worker_flee()

func _enter_hide() -> void:
	state       = State.HIDE
	_hide_timer = 5.5
	_set_state_light(Color(0.2, 0.3, 1.0, 1.0))
	AudioMgr.play_worker_hide()

func _resume_after_stun() -> void:
	if _alarm_level >= int(Alarm.Level.ALARMA): _enter_hide()
	else: state = State.PATROL

func _on_alarm_changed(lv: int) -> void:
	_alarm_level = lv
	match lv:
		int(Alarm.Level.CALMA):
			_set_state_light_off()
			if state == State.HIDE: state = State.PATROL; _spotted_once = false
		int(Alarm.Level.ALERTA):
			_set_state_light(Color(1.0, 0.8, 0.0, 0.7))
		int(Alarm.Level.ALARMA), int(Alarm.Level.LOCKDOWN):
			if state == State.IDLE or state == State.PATROL:
				var pl := _get_player()
				if pl and global_position.distance_to(pl.global_position) < Constants.WORKER_DETECT_RANGE * 2.0:
					_trigger_flee(pl)
				else:
					_enter_hide()

func _update_sentido_ring(delta: float) -> void:
	_sentido_t -= delta
	if _sentido_t > 0.0: return
	_sentido_t = 0.5
	if _sentido_ring:
		_sentido_ring.visible = (_ab_sys != null and is_instance_valid(_ab_sys) and _ab_sys.has_passive("SENTIDO"))

func stun(duration: float) -> void:
	if state == State.BEING_ABSORBED or state == State.ABSORBED: return
	state = State.STUNNED
	_stun_timer = duration
	_set_state_light(Color(0.3, 0.3, 1.0, 1.0))

func start_absorb(progress: float) -> void:
	state = State.BEING_ABSORBED
	if _body_mat:
		_body_mat.albedo_color = _base_col.lerp(Color(0.05, 0.0, 0.15, 1.0), progress)
		_body_mat.emission_enabled = true
		_body_mat.emission = Color(0.35, 0.0, 0.85, 1.0) * progress
		_body_mat.emission_energy_multiplier = 1.5 + progress * 2.5

func finish_absorb() -> void:
	state = State.ABSORBED
	if Alarm.level_changed.is_connected(_on_alarm_changed):
		Alarm.level_changed.disconnect(_on_alarm_changed)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.38)
	await tw.finished
	queue_free()

func _move_toward(tgt: Vector3, spd: float, delta: float) -> void:
	var dir := tgt - global_position; dir.y = 0.0
	if dir.length_squared() > 0.04:
		dir = dir.normalized()
		velocity.x = dir.x * spd; velocity.z = dir.z * spd
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, spd * 8.0 * delta)

func _set_state_light(col: Color) -> void:
	if _state_light: _state_light.light_color = col; _state_light.light_energy = 1.4

func _set_state_light_off() -> void:
	if _state_light: _state_light.light_energy = 0.0

func _get_player() -> Node:
	if _pl_ref != null and is_instance_valid(_pl_ref): return _pl_ref
	var g := get_tree().get_nodes_in_group("player")
	if g.size() > 0:
		_pl_ref = g[0]
		if _pl_ref.has_node("AbilitySystem"): _ab_sys = _pl_ref.get_node("AbilitySystem")
	else:
		_pl_ref = null
	return _pl_ref

func _player_has_stealth(_pl: Node) -> bool:
	return _ab_sys != null and is_instance_valid(_ab_sys) and _ab_sys.has_passive("SIGILO")
