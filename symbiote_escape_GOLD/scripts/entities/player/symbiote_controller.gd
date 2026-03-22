extends CharacterBody3D
## SymbioteController — controlador principal del jugador. Versión comercial.
## Mejoras: FOV dinámico, slow-mo en absorción, squash al aterrizar, trail de sprint.

var health     : float = Constants.PLAYER_MAX_HEALTH
var max_health : float = Constants.PLAYER_MAX_HEALTH
var cam_pitch  : float = 0.0
var mouse_sens : float = 0.003

var _visual   : Node        = null
var _absorber : Node        = null
var _ab_sys   : Node        = null
var _spring   : SpringArm3D = null
var _cam      : Camera3D    = null

var _cam_trauma     : float = 0.0
var _cam_origin     : Vector3 = Vector3.ZERO
var _step_timer     : float = 0.0
var _target_fov     : float = Constants.CAM_FOV_NORMAL
var _was_on_floor   : bool  = true
var _slowmo_timer   : float = 0.0
var _is_sprinting   : bool  = false

func _ready() -> void:
	add_to_group("player")
	mouse_sens  = SaveMgr.get_mouse_sens()
	max_health  = Constants.PLAYER_MAX_HEALTH + ProgressionMgr.get_bonus_health()
	health      = max_health
	_build_collision()
	_build_camera()
	_build_absorb_area()
	_build_visual()
	_build_ability_system()
	call_deferred("_capture_cam_origin")
	GM.player_health_changed.emit(health, max_health)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.44; cap.height = 1.8
	col.shape  = cap; col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

func _build_camera() -> void:
	_spring = SpringArm3D.new()
	_spring.name          = "CameraArm"
	_spring.position      = Vector3(0.0, 1.5, 0.0)
	_spring.spring_length = 4.5
	add_child(_spring)
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov  = Constants.CAM_FOV_NORMAL
	_spring.add_child(_cam)

func _build_absorb_area() -> void:
	var area := Area3D.new()
	area.position = Vector3(0.0, 0.9, 0.0)
	add_child(area)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = Constants.ABSORB_RANGE
	cs.shape  = sp; area.add_child(cs)
	_absorber = load("res://scripts/entities/player/absorb_handler.gd").new()
	_absorber.setup(area)
	_absorber.absorb_completed.connect(_on_absorb_complete)
	_absorber.absorb_started.connect(_on_absorb_started)
	_absorber.absorb_cancelled.connect(_on_absorb_cancelled)
	add_child(_absorber)

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.set_script(load("res://scripts/entities/player/symbiote_visual.gd"))
	add_child(_visual)

func _build_ability_system() -> void:
	_ab_sys = Node.new()
	_ab_sys.set_script(load("res://scripts/entities/player/ability_system.gd"))
	_ab_sys.name = "AbilitySystem"
	add_child(_ab_sys)
	_ab_sys.passive_gained.connect(_on_passive_gained)
	_ab_sys.passive_lost.connect(_on_passive_lost)

func _capture_cam_origin() -> void:
	if _cam: _cam_origin = _cam.position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		cam_pitch = clampf(cam_pitch - event.relative.y * mouse_sens, -1.1, 0.5)
		if _spring: _spring.rotation.x = cam_pitch

func _physics_process(delta: float) -> void:
	if not GM.game_active: return

	# Slow-motion timer
	if _slowmo_timer > 0.0:
		_slowmo_timer -= delta
		if _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0

	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_handle_absorb(delta)
	_handle_active_skills()
	move_and_slide()
	_handle_camera_shake(delta)
	_handle_camera_fov(delta)
	_handle_footsteps(delta)
	_handle_land_detection()
	if _visual:
		_visual.set_power(GM.absorption_count)
		_visual.set_danger_vignette(health / max_health)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Constants.PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		var jf := Constants.PLAYER_JUMP_FORCE
		if _ab_sys and _ab_sys.has_passive("SUPER_SALTO"):
			jf *= Constants.ABILITY_JUMP_MULT
		velocity.y = jf
		_was_on_floor = false
		AudioMgr.play_jump()

func _handle_land_detection() -> void:
	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		# Acaba de aterrizar
		camera_shake(0.25)
		if _visual: _visual.trigger_land_squash()
		AudioMgr.play_land()
	_was_on_floor = on_floor_now

func _handle_movement(delta: float) -> void:
	_is_sprinting = Input.is_action_pressed("sprint") and not _absorber.active
	var spd := Constants.PLAYER_SPEED_SPRINT if _is_sprinting else Constants.PLAYER_SPEED_WALK
	if _ab_sys and _ab_sys.has_passive("VELOCIDAD"):
		spd *= Constants.ABILITY_SPEED_MULT

	var fwd := -global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var rgt :=  global_transform.basis.x; rgt.y = 0.0; rgt = rgt.normalized()
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): dir += fwd
	if Input.is_action_pressed("move_back"):    dir -= fwd
	if Input.is_action_pressed("move_right"):   dir += rgt
	if Input.is_action_pressed("move_left"):    dir -= rgt

	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if _visual:
			_visual.set_state("walk")
			_visual.set_sprinting(_is_sprinting)
		# FOV objetivo: sprint = wider
		_target_fov = Constants.CAM_FOV_SPRINT if _is_sprinting else Constants.CAM_FOV_NORMAL
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, spd * 8.0 * delta)
		if _visual and not _absorber.active:
			_visual.set_state("idle")
			_visual.set_sprinting(false)
		_target_fov = Constants.CAM_FOV_NORMAL

func _handle_absorb(delta: float) -> void:
	var pressing := Input.is_action_pressed("absorb")
	if _absorber: _absorber.tick(delta, pressing)
	if _absorber and _absorber.active:
		if _visual: _visual.set_state("absorb")
		_target_fov = Constants.CAM_FOV_ABSORB  # zoom in

func _handle_active_skills() -> void:
	if Input.is_action_just_pressed("skill_1"): _use_skill("DASH")
	if Input.is_action_just_pressed("skill_2"): _use_skill("PULSO")
	if Input.is_action_just_pressed("skill_3"): _use_skill("CAMUFLAJE")

func _use_skill(skill_id: String) -> void:
	if _ab_sys == null: return
	if not _ab_sys.use_active(skill_id): return
	match skill_id:
		"DASH":      _execute_dash()
		"PULSO":     _execute_pulse()
		"CAMUFLAJE": _execute_camuflaje()
	match skill_id:
		"DASH":      AudioMgr.play_skill_dash()
		"PULSO":     AudioMgr.play_skill_pulso()
		"CAMUFLAJE": AudioMgr.play_skill_camuflaje()

func _execute_dash() -> void:
	var dir := -global_transform.basis.z
	dir.y = 0.0
	dir   = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	velocity = dir * (Constants.SKILL_DASH_DISTANCE / 0.25)
	camera_shake(0.3)
	if _visual: _visual.play_dash_flash()

func _execute_pulse() -> void:
	if _visual: _visual.play_pulse_burst()
	camera_shake(0.4)
	var all_enemies : Array[Node] = []
	all_enemies.append_array(get_tree().get_nodes_in_group("worker"))
	all_enemies.append_array(get_tree().get_nodes_in_group("security"))
	for enemy in all_enemies:
		var in_range: bool = enemy.global_position.distance_to(global_position) <= Constants.SKILL_PULSE_RADIUS
		if is_instance_valid(enemy) and in_range and enemy.has_method("stun"):
			enemy.stun(Constants.SKILL_PULSE_STUN_TIME)

func _execute_camuflaje() -> void:
	if _visual: _visual.set_stealth_visual(true)

# ── Callbacks de absorción ────────────────────────────────

func _on_absorb_started() -> void:
	AudioMgr.play_absorb_start()

func _on_absorb_cancelled() -> void:
	_target_fov = Constants.CAM_FOV_NORMAL
	if AudioMgr.has_method("play_absorb_stop"): AudioMgr.play_absorb_stop()

func _on_absorb_complete(target: Node, enemy_type: String) -> void:
	var xp := Constants.XP_PER_SECURITY if enemy_type == "security" else Constants.XP_PER_WORKER
	ProgressionMgr.add_xp(xp)
	if _ab_sys: _ab_sys.grant_from_enemy(enemy_type)
	GM.add_absorption()
	health = minf(health + Constants.PLAYER_HEALTH_REGEN_PER_ABSORB, max_health)
	GM.player_health_changed.emit(health, max_health)

	# === IMPACTO MÁXIMO ===
	camera_shake(Constants.ABSORB_CAM_SHAKE)
	_trigger_hitstop(0.048)          # hit-stop 48ms — breve pero contundente
	_trigger_slowmo()
	if _visual:
		_visual.flash_absorb_complete()  # flash blanco de pantalla
		_visual.play_absorb_burst()
		if is_instance_valid(target):
			_visual.play_absorb_burst_at(target.global_position)
			_visual.trigger_absorb_ring(target.global_position)
	AudioMgr.play_absorb_complete()
	_target_fov = Constants.CAM_FOV_NORMAL
	if _visual: _visual.set_state("idle")
	if is_instance_valid(target):
		target.finish_absorb()

func _trigger_slowmo() -> void:
	Engine.time_scale = Constants.ABSORB_SLOWMO_SCALE
	_slowmo_timer = Constants.ABSORB_SLOWMO_DURATION / Constants.ABSORB_SLOWMO_SCALE

func _trigger_hitstop(real_seconds: float) -> void:
	## Congela el juego brevemente — hace que el impacto se sienta en los huesos.
	Engine.time_scale = 0.0
	var t := Timer.new()
	t.wait_time = real_seconds
	t.ignore_time_scale = true
	t.one_shot = true
	add_child(t)
	t.start()
	await t.timeout
	if is_instance_valid(t):
		t.queue_free()
	Engine.time_scale = 1.0

# ── Callbacks de habilidades ──────────────────────────────

func _on_passive_gained(ability_name: String) -> void:
	AudioMgr.play_ability_gained()
	if ability_name == "SIGILO" and _visual:
		_visual.set_stealth_visual(true)

func _on_passive_lost(ability_name: String) -> void:
	if ability_name == "SIGILO" and _visual:
		_visual.set_stealth_visual(false)

# ── Cámara ───────────────────────────────────────────────

func camera_shake(trauma: float) -> void:
	_cam_trauma = minf(_cam_trauma + trauma, 1.0)

func _handle_camera_shake(delta: float) -> void:
	if _cam_trauma <= 0.001: return
	_cam_trauma = maxf(0.0, _cam_trauma - delta * 4.0)
	if _cam == null: return
	var shake := _cam_trauma * _cam_trauma
	_cam.position = _cam_origin + Vector3(
		randf_range(-1.0, 1.0) * shake * 0.14,
		randf_range(-1.0, 1.0) * shake * 0.10,
		0.0)

func _handle_camera_fov(delta: float) -> void:
	if _cam == null: return
	_cam.fov = move_toward(_cam.fov, _target_fov, Constants.CAM_FOV_SPEED * delta * 60.0)

# ── Pasos y daño ─────────────────────────────────────────

func _handle_footsteps(delta: float) -> void:
	if not is_on_floor(): return
	var dir_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if dir_input.length() < 0.1: _step_timer = 0.0; return
	var interval := 0.28 if _is_sprinting else 0.44
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = interval
		AudioMgr.play_footstep()

func take_damage(amount: float) -> void:
	var base_dr   := ProgressionMgr.get_damage_reduction(GM.absorption_count)
	var fuerza_dr := Constants.ABILITY_FUERZA_DR if (_ab_sys and _ab_sys.has_passive("FUERZA")) else 0.0
	amount *= (1.0 - minf(base_dr + fuerza_dr, Constants.POWER_DR_MAX))
	health -= amount
	GM.player_health_changed.emit(health, max_health)
	AudioMgr.play_damage()
	camera_shake(Constants.DAMAGE_CAM_SHAKE)
	if _visual: _visual.flash_damage()  # aberración cromática
	if health <= 0.0:
		GM.game_over.emit()

func get_ability_system() -> Node:
	return _ab_sys
