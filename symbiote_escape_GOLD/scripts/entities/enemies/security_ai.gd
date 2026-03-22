extends CharacterBody3D
## SecurityAI — Guardia de seguridad. Versión comercial.
## Mejoras: trabajo en equipo (radio coordinación), flanqueo, recibir alertas de workers,
##          búsqueda más inteligente en última posición conocida.

signal guard_chasing(pos: Vector3)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, CHASE, ATTACK, RETURNING, STUNNED }

var enemy_type       : String = "security"
var state            : State  = State.PATROL
var waypoints        : Array[Vector3] = []
var _wp_idx          : int    = 0
var last_known       : Vector3 = Vector3.ZERO
var _investigate_pos : Vector3 = Vector3.ZERO
var _atk_timer       : float  = 0.0
var _sus_timer       : float  = 0.0
var _stun_timer      : float  = 0.0
var _investigate_timer: float = 0.0
var _memory_timer    : float  = 0.0
var _alarm_level     : int    = 0
var _is_alerted      : bool   = false
var _flank_side      : float  = 1.0   # +1 o -1 para flanqueo alternado

var _spot           : SpotLight3D        = null
var _mesh           : MeshInstance3D     = null
var _abs_mat        : StandardMaterial3D = null
var _sentido_ring   : MeshInstance3D     = null
var _sentido_t      : float = 0.0
var _being_absorbed : bool  = false
var _search_sweep   : float = 0.0   # ángulo de búsqueda en grid

var _pl_ref : Node = null
var _ab_sys : Node = null

func _ready() -> void:
	add_to_group("security")
	_build_visual()
	_init_waypoints()
	Alarm.level_changed.connect(_on_alarm_changed)
	Alarm.noise_reported.connect(_on_noise_reported)
	# Lado de flanqueo aleatorio por instancia
	_flank_side = 1.0 if randf() > 0.5 else -1.0
	call_deferred("_cache_player")

func _cache_player() -> void:
	var g := get_tree().get_nodes_in_group("player")
	if g.size() > 0:
		_pl_ref = g[0]
		if _pl_ref.has_node("AbilitySystem"):
			_ab_sys = _pl_ref.get_node("AbilitySystem")

func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34; cap.height = 1.7
	col.shape = cap; col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	_mesh = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.29; cy.bottom_radius = 0.33; cy.height = 1.15
	_mesh.mesh = cy; _mesh.position = Vector3(0.0, 0.82, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.10, 0.16, 1.0)
	mat.metallic     = 0.4
	mat.roughness    = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	var head := MeshInstance3D.new()
	var hs   := SphereMesh.new(); hs.radius = 0.23; hs.height = 0.46
	head.mesh = hs; head.position = Vector3(0.0, 1.65, 0.0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.18, 0.16, 0.14, 1.0)
	head.material_override = hm
	add_child(head)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 1.0, 0.55); rim.light_color = Color(1.0, 0.12, 0.0, 1.0)
	rim.light_energy = 0.65; rim.omni_range = 2.0; add_child(rim)

	_spot = SpotLight3D.new()
	_spot.position     = Vector3(0.0, 1.6, -0.28)
	_spot.light_color  = Color(0.90, 0.90, 0.70, 1.0)
	_spot.light_energy = 2.0
	_spot.spot_range   = Constants.GUARD_FOV_DISTANCE
	_spot.spot_angle   = 28.0
	_spot.light_volumetric_fog_energy = 0.8  # volum fog visible
	add_child(_spot)

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

func _init_waypoints() -> void:
	if not waypoints.is_empty(): return
	var base := global_position
	for i in 4:
		var a := float(i) / 4.0 * TAU
		waypoints.append(base + Vector3(cos(a) * 5.5, 0.0, sin(a) * 5.5))

func _physics_process(delta: float) -> void:
	if not GM.game_active: return
	if not is_on_floor(): velocity.y -= Constants.PLAYER_GRAVITY * delta

	if _being_absorbed:
		velocity.x = 0.0; velocity.z = 0.0
		move_and_slide(); return

	if state == State.STUNNED:
		_stun_timer -= delta
		velocity.x = 0.0; velocity.z = 0.0
		if _stun_timer <= 0.0: _resume_from_stun()
		move_and_slide(); return

	_atk_timer = maxf(0.0, _atk_timer - delta)
	if _memory_timer > 0.0: _memory_timer -= delta

	var pl := _get_player()

	match state:
		State.PATROL:      _do_patrol(delta)
		State.SUSPICIOUS:  _do_suspicious(delta, pl)
		State.INVESTIGATE: _do_investigate(delta)
		State.CHASE:       _do_chase(delta, pl)
		State.ATTACK:      _do_attack(pl)
		State.RETURNING:   _do_return(delta)

	move_and_slide()
	_scan_for_player(pl)
	_update_sentido_ring(delta)

func _do_patrol(_delta: float) -> void:
	if waypoints.is_empty(): return
	_move_to(waypoints[_wp_idx], Constants.GUARD_SPEED_PATROL)
	if global_position.distance_to(waypoints[_wp_idx]) < 1.2:
		_wp_idx = (_wp_idx + 1) % waypoints.size()

func _do_suspicious(delta: float, pl: Node) -> void:
	var to := last_known - global_position; to.y = 0.0
	if to.length_squared() > 0.01: look_at(global_position + to.normalized(), Vector3.UP)
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	# Barrido con la linterna durante SUSPICIOUS
	_search_sweep += delta * 2.5
	if _spot: _spot.rotation.y = sin(_search_sweep) * 0.4
	_sus_timer -= delta
	if _sus_timer <= 0.0:
		if _spot: _spot.rotation.y = 0.0
		if pl and _can_see_player(pl): _enter_chase()
		else: _enter_investigate()

func _do_investigate(delta: float) -> void:
	_investigate_timer -= delta
	_move_to(_investigate_pos, Constants.GUARD_SPEED_INVESTIGATE)
	var reached := global_position.distance_to(_investigate_pos) < 2.0
	if reached or _investigate_timer <= 0.0:
		if _investigate_timer <= 0.0:
			# Búsqueda en grid: intentar puntos cercanos
			_investigate_pos = _investigate_pos + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			_investigate_timer = 3.0
		else:
			_enter_return()

func _do_chase(delta: float, pl: Node) -> void:
	if pl and is_instance_valid(pl):
		last_known    = pl.global_position
		_memory_timer = Constants.GUARD_MEMORY_TIME
		var dist := global_position.distance_to(pl.global_position)
		if dist <= Constants.GUARD_ATTACK_RANGE:
			state = State.ATTACK; return
		var spd := Constants.GUARD_SPEED_LOCKDOWN if _alarm_level >= 3 else Constants.GUARD_SPEED_CHASE
		# Flanqueo: desplazarse lateralmente mientras persigue
		var to_pl : Vector3 = (pl.global_position - global_position).normalized()
		var flank  : Vector3 = to_pl.cross(Vector3.UP).normalized() * _flank_side * Constants.GUARD_FLANK_OFFSET * 0.3
		_move_to(pl.global_position + flank, spd)
		# Compartir posición con otros guards cercanos
		_radio_position(pl.global_position)
	else:
		if _memory_timer > 0.0:
			_move_to(last_known, Constants.GUARD_SPEED_INVESTIGATE)
			if global_position.distance_to(last_known) < 1.5: _memory_timer = 0.0
		else:
			_enter_return()

func _do_attack(pl: Node) -> void:
	if pl == null or not is_instance_valid(pl): state = State.CHASE; return
	var dist := global_position.distance_to(pl.global_position)
	if dist > Constants.GUARD_ATTACK_RANGE * 1.6: state = State.CHASE; return
	var to : Vector3 = pl.global_position - global_position; to.y = 0.0
	if to.length_squared() > 0.01: look_at(global_position + to.normalized(), Vector3.UP)
	velocity.x = 0.0; velocity.z = 0.0
	if _atk_timer <= 0.0 and pl.has_method("take_damage"):
		pl.take_damage(Constants.GUARD_ATTACK_DAMAGE)
		_atk_timer = Constants.GUARD_ATTACK_COOLDOWN
		AudioMgr.play_guard_attack()

func _do_return(_delta: float) -> void:
	if waypoints.is_empty(): return
	_move_to(waypoints[_wp_idx], Constants.GUARD_SPEED_PATROL)
	if global_position.distance_to(waypoints[_wp_idx]) < 1.8:
		if _is_alerted: _is_alerted = false; Alarm.guard_returned(self)
		state = State.PATROL
		_spot_color(Color(0.9, 0.9, 0.7, 1.0))

func _radio_position(player_pos: Vector3) -> void:
	# Compartir última posición conocida con guards en radio GUARD_RADIO_RANGE
	var guards := get_tree().get_nodes_in_group("security")
	for g in guards:
		if g == self or not is_instance_valid(g): continue
		if global_position.distance_to(g.global_position) <= Constants.GUARD_RADIO_RANGE:
			if g.has_method("receive_radio"):
				g.receive_radio(player_pos)

func receive_radio(pos: Vector3) -> void:
	# Recibir posición de otro guard
	if state == State.PATROL or state == State.RETURNING:
		_investigate_pos   = pos
		_investigate_timer = Constants.GUARD_INVESTIGATE_TIME
		state              = State.INVESTIGATE
		_spot_color(Color(1.0, 0.7, 0.0, 1.0))

func receive_worker_alert(pos: Vector3) -> void:
	# Recibir alerta de un trabajador
	if state == State.PATROL or state == State.RETURNING:
		_investigate_pos   = pos
		_investigate_timer = Constants.GUARD_INVESTIGATE_TIME * 0.7
		state              = State.INVESTIGATE
		_spot_color(Color(1.0, 0.6, 0.0, 1.0))

func _scan_for_player(pl: Node) -> void:
	if state == State.CHASE or state == State.ATTACK or state == State.STUNNED: return
	if pl == null: return
	if not _can_see_player(pl): return
	last_known = pl.global_position
	match state:
		State.PATROL, State.INVESTIGATE, State.RETURNING:
			_enter_suspicious(pl)
		State.SUSPICIOUS:
			_sus_timer = minf(_sus_timer, 0.3)

func _can_see_player(pl: Node) -> bool:
	var to_pl : Vector3 = pl.global_position - global_position
	var dist  : float   = to_pl.length()
	if dist < 2.0: return true
	if _ab_sys and is_instance_valid(_ab_sys) and _ab_sys.has_passive("SIGILO"): return false
	var fov_dist  := Constants.GUARD_FOV_DISTANCE_ALARM if _alarm_level >= 2 else Constants.GUARD_FOV_DISTANCE
	if dist > fov_dist: return false
	var fov_angle := Constants.GUARD_FOV_ANGLE_ALARM if _alarm_level >= 2 else Constants.GUARD_FOV_ANGLE
	return (-global_transform.basis.z).angle_to(to_pl.normalized()) < fov_angle

func _enter_suspicious(pl: Node) -> void:
	state = State.SUSPICIOUS; last_known = pl.global_position
	_sus_timer = 0.3 if _alarm_level >= 2 else Constants.GUARD_SUSPICIOUS_TIME
	_spot_color(Color(1.0, 0.5, 0.0, 1.0))
	velocity.x = 0.0; velocity.z = 0.0
	_search_sweep = 0.0
	AudioMgr.play_guard_spotted()

func _enter_chase() -> void:
	state = State.CHASE; _spot_color(Color(1.0, 0.05, 0.0, 1.0))
	_call_backup()
	if not _is_alerted:
		_is_alerted = true
		Alarm.guard_confirmed(self)
		guard_chasing.emit(global_position)
		AudioMgr.play_guard_chase()

func _enter_investigate() -> void:
	state = State.INVESTIGATE; _investigate_pos = last_known
	_investigate_timer = Constants.GUARD_INVESTIGATE_TIME
	_spot_color(Color(1.0, 0.7, 0.0, 1.0))

func _call_backup() -> void:
	var guards := get_tree().get_nodes_in_group("security")
	for g in guards:
		if g == self or not is_instance_valid(g): continue
		if global_position.distance_to(g.global_position) <= Constants.GUARD_RADIO_RANGE:
			if g.has_method("receive_radio"):
				g.receive_radio(last_known)
				AudioMgr.play_guard_radio()

func _enter_return() -> void:
	state = State.RETURNING
	if _is_alerted: _is_alerted = false; Alarm.guard_returned(self)
	_spot_color(Color(0.9, 0.9, 0.7, 1.0))

func _resume_from_stun() -> void:
	state = State.CHASE if _is_alerted else State.PATROL
	_spot_color(Color(0.9, 0.9, 0.7, 1.0))

func _on_alarm_changed(lv: int) -> void:
	_alarm_level = lv
	if lv >= 2 and state == State.PATROL and not _is_alerted:
		if Alarm.last_noise_pos != Vector3.ZERO:
			_investigate_pos   = Alarm.last_noise_pos
			_investigate_timer = Constants.GUARD_INVESTIGATE_TIME
			state              = State.INVESTIGATE
			_spot_color(Color(1.0, 0.7, 0.0, 1.0))
	# Actualizar rango del spot según nivel de alarma
	if _spot:
		_spot.spot_range = Constants.GUARD_FOV_DISTANCE_ALARM if lv >= 2 else Constants.GUARD_FOV_DISTANCE

func _on_noise_reported(pos: Vector3) -> void:
	if (state == State.PATROL or state == State.RETURNING) and not _is_alerted:
		_investigate_pos   = pos
		_investigate_timer = Constants.GUARD_INVESTIGATE_TIME
		state              = State.INVESTIGATE
		_spot_color(Color(1.0, 0.7, 0.0, 1.0))

func _update_sentido_ring(delta: float) -> void:
	_sentido_t -= delta
	if _sentido_t > 0.0: return
	_sentido_t = 0.5
	if _sentido_ring:
		var has_sentido : bool = _ab_sys != null and is_instance_valid(_ab_sys) and _ab_sys.has_passive("SENTIDO")
		_sentido_ring.visible = has_sentido

func stun(duration: float) -> void:
	if _being_absorbed: return
	state = State.STUNNED; _stun_timer = duration
	_spot_color(Color(0.3, 0.3, 1.0, 1.0))

func start_absorb(progress: float) -> void:
	_being_absorbed = true
	if _mesh:
		if _abs_mat == null:
			_abs_mat = StandardMaterial3D.new()
			_abs_mat.albedo_color = Color(0.12, 0.12, 0.18, 1.0)
			_abs_mat.emission_enabled = true
			_mesh.material_override = _abs_mat
		_abs_mat.albedo_color = Color(0.12, 0.12, 0.18).lerp(Color(0.04, 0.0, 0.14), progress)
		_abs_mat.emission = Color(0.3, 0.0, 0.8, 1.0) * progress
		_abs_mat.emission_energy_multiplier = 1.5 + progress * 3.0

func finish_absorb() -> void:
	_being_absorbed = false
	if _is_alerted: Alarm.guard_absorbed(self); _is_alerted = false
	if Alarm.level_changed.is_connected(_on_alarm_changed):
		Alarm.level_changed.disconnect(_on_alarm_changed)
	if Alarm.noise_reported.is_connected(_on_noise_reported):
		Alarm.noise_reported.disconnect(_on_noise_reported)
	if _spot: _spot.visible = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.40)
	await tw.finished
	queue_free()

func _get_player() -> Node:
	if _pl_ref != null and is_instance_valid(_pl_ref): return _pl_ref
	var g := get_tree().get_nodes_in_group("player")
	if g.size() > 0:
		_pl_ref = g[0]
		if _pl_ref.has_node("AbilitySystem"): _ab_sys = _pl_ref.get_node("AbilitySystem")
	else:
		_pl_ref = null
	return _pl_ref

func _move_to(tgt: Vector3, spd: float) -> void:
	var dir := tgt - global_position; dir.y = 0.0
	if dir.length_squared() > 0.04:
		dir = dir.normalized()
		velocity.x = dir.x * spd; velocity.z = dir.z * spd
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0; velocity.z = 0.0

func _spot_color(col: Color) -> void:
	if _spot: _spot.light_color = col
