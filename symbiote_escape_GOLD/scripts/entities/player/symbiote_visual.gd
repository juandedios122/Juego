extends Node3D
## SymbioteVisual — Gold build. Final polish.
## NUEVO vs comercial: aberración cromática, flash blanco, anillo desde objetivo,
## gotas de slime, rim light dinámico, double-pulse anillo, vignette mejorada.
## SPRITES: usa AnimatedSprite3D si hay imágenes en assets/sprites/symbiote/

var body_mesh   : MeshInstance3D     = null
var glow        : OmniLight3D        = null
var body_mat    : StandardMaterial3D = null
var _eye_mats   : Array              = []

# ── Sprite (reemplaza body_mesh + eyes si hay imágenes) ──
var _sprite      : AnimatedSprite3D = null
var _use_sprite  : bool             = false

var _fx_stream      : CPUParticles3D = null
var _fx_burst       : CPUParticles3D = null
var _fx_trail       : CPUParticles3D = null
var _fx_slime_drops : CPUParticles3D = null
var _tentacle_meshes: Array          = []
var _pulse_ring     : MeshInstance3D = null
var _inner_ring     : MeshInstance3D = null
var _absorb_ring    : MeshInstance3D = null

var _pulse_active       : bool  = false
var _pulse_t            : float = 0.0
var _absorb_ring_active : bool  = false
var _absorb_ring_t      : float = 0.0

var _state        : String = "idle"
var _t            : float  = 0.0
var _power        : int    = 0
var _land_squash  : float  = 0.0
var _was_sprinting: bool   = false

# ── Overlays 2D ──────────────────────────────────────────
var _overlay_layer : CanvasLayer = null
var _flash_rect    : ColorRect   = null   # flash blanco absorción
var _danger_rect   : ColorRect   = null   # viñeta roja peligro
var _ca_r          : ColorRect   = null   # aberración rojo
var _ca_b          : ColorRect   = null   # aberración azul
var _scanlines     : ColorRect   = null   # scanlines CRT
var _absorb_distort: ColorRect   = null   # pulso de distorsión en absorción
var _flash_t  : float = 0.0
var _ca_t     : float = 0.0
var _danger_hp: float = 1.0
var _absorb_distort_t: float = 0.0

# ── Rim light ─────────────────────────────────────────────
var _rim_light : OmniLight3D = null

func _ready() -> void:
	_build_body(); _build_eyes(); _build_glow()
	_build_rim_light(); _build_particles()
	_build_tentacles(); _build_pulse_rings()
	_build_overlays()
	_try_load_sprite()

# ─────────────────────────────────────────────────────────
func _try_load_sprite() -> void:
	## Carga el spritesheet del simbionte si existe.
	## El sprite es billboard y reemplaza el mesh esférico + ojos.
	if not Engine.has_singleton("SpriteMgr"): return
	var mgr : Node = Engine.get_singleton("SpriteMgr")
	if not mgr.has_sprites("symbiote"): return

	_sprite = AnimatedSprite3D.new()
	_sprite.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size     = 0.016
	_sprite.position       = Vector3(0.0, 0.9, 0.0)
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.cast_shadow    = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)

	var sf := SpriteFrames.new()
	for anim_name in ["idle", "walk", "absorb", "dash"]:
		var frames := mgr.get_frames("symbiote", anim_name)
		if frames == null: continue
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, frames.get_animation_speed(anim_name))
			sf.set_animation_loop(anim_name, frames.get_animation_loop(anim_name))
			for i in frames.get_frame_count(anim_name):
				sf.add_frame(anim_name, frames.get_frame_texture(anim_name, i))
	_sprite.sprite_frames = sf
	_sprite.play("idle")
	_use_sprite = true

	# Ocultar mesh por código cuando hay sprite
	if body_mesh: body_mesh.visible = false
	for em in _eye_mats:
		var eye_node := em.get_local_scene()
		if eye_node: eye_node.visible = false

func _play_sprite(anim: String) -> void:
	if not _use_sprite or _sprite == null: return
	if _sprite.sprite_frames == null: return
	if not _sprite.sprite_frames.has_animation(anim):
		if _sprite.sprite_frames.has_animation("idle"): _sprite.play("idle")
		return
	if _sprite.animation != anim: _sprite.play(anim)

func _build_body() -> void:
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color               = Color(0.02, 0.01, 0.05, 1.0)
	body_mat.metallic                   = 0.95; body_mat.roughness = 0.04
	body_mat.emission_enabled           = true
	body_mat.emission                   = Color(0.15, 0.0, 0.5, 1.0)
	body_mat.emission_energy_multiplier = 2.0
	body_mat.rim_enabled                = true; body_mat.rim = 1.0; body_mat.rim_tint = 0.3
	body_mat.subsurf_scatter_enabled    = true
	body_mat.subsurf_scatter_strength   = 0.35
	body_mat.subsurf_scatter_skin_mode  = true
	body_mesh = MeshInstance3D.new()
	var sp := SphereMesh.new(); sp.radius = 0.44; sp.height = 1.1
	sp.rings = 16; sp.radial_segments = 24
	body_mesh.mesh = sp; body_mesh.position = Vector3(0.0, 0.9, 0.0)
	body_mesh.material_override = body_mat; add_child(body_mesh)

func _build_eyes() -> void:
	for ex in [-0.18, 0.18]:
		var eye := MeshInstance3D.new()
		var es  := SphereMesh.new(); es.radius = 0.08; es.height = 0.16
		eye.mesh = es; eye.position = Vector3(ex, 1.18, -0.37)
		var em := StandardMaterial3D.new()
		em.albedo_color               = Color(0.9, 0.9, 1.0, 1.0)
		em.emission_enabled           = true; em.emission = Color(0.6, 0.6, 1.0, 1.0)
		em.emission_energy_multiplier = 4.5; em.rim_enabled = true; em.rim = 0.5
		eye.material_override = em; add_child(eye); _eye_mats.append(em)

func _build_glow() -> void:
	glow = OmniLight3D.new(); glow.position = Vector3(0.0, 0.9, 0.0)
	glow.light_color = Color(0.35, 0.0, 1.0, 1.0); glow.light_energy = 1.6
	glow.omni_range = 4.5; glow.light_volumetric_fog_energy = 0.6; add_child(glow)

func _build_rim_light() -> void:
	_rim_light = OmniLight3D.new(); _rim_light.position = Vector3(0.0, 1.0, 1.2)
	_rim_light.light_color = Color(0.4, 0.0, 1.0, 1.0)
	_rim_light.light_energy = 0.8; _rim_light.omni_range = 2.5; add_child(_rim_light)

func _build_particles() -> void:
	_fx_stream = CPUParticles3D.new(); _fx_stream.emitting = false; _fx_stream.amount = 52
	_fx_stream.lifetime = 0.55; _fx_stream.one_shot = false
	_fx_stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fx_stream.emission_sphere_radius = 2.4; _fx_stream.gravity = Vector3(0.0, 4.5, 0.0)
	_fx_stream.initial_velocity_min = 2.2; _fx_stream.initial_velocity_max = 5.5
	_fx_stream.scale_amount_min = 0.04; _fx_stream.scale_amount_max = 0.20
	_fx_stream.color = Color(0.5, 0.0, 1.0, 1.0); _fx_stream.position = Vector3(0.0, 0.9, 0.0)
	add_child(_fx_stream)

	_fx_burst = CPUParticles3D.new(); _fx_burst.emitting = false; _fx_burst.amount = 200
	_fx_burst.lifetime = 1.4; _fx_burst.one_shot = true; _fx_burst.explosiveness = 0.98
	_fx_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fx_burst.emission_sphere_radius = 0.7; _fx_burst.gravity = Vector3(0.0, -2.5, 0.0)
	_fx_burst.initial_velocity_min = 6.0; _fx_burst.initial_velocity_max = 18.0
	_fx_burst.scale_amount_min = 0.06; _fx_burst.scale_amount_max = 0.38
	_fx_burst.color = Color(0.85, 0.0, 1.0, 1.0); _fx_burst.position = Vector3(0.0, 0.9, 0.0)
	add_child(_fx_burst)

	_fx_trail = CPUParticles3D.new(); _fx_trail.emitting = false; _fx_trail.amount = 28
	_fx_trail.lifetime = 0.28; _fx_trail.one_shot = false
	_fx_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fx_trail.emission_sphere_radius = 0.28; _fx_trail.gravity = Vector3(0.0, 0.5, 0.0)
	_fx_trail.initial_velocity_min = 0.2; _fx_trail.initial_velocity_max = 0.9
	_fx_trail.scale_amount_min = 0.03; _fx_trail.scale_amount_max = 0.12
	_fx_trail.color = Color(0.3, 0.0, 0.8, 0.55); _fx_trail.position = Vector3(0.0, 0.5, 0.0)
	add_child(_fx_trail)

	# Gotas de slime — identidad visual única del simbionte
	_fx_slime_drops = CPUParticles3D.new(); _fx_slime_drops.emitting = false
	_fx_slime_drops.amount = 14; _fx_slime_drops.lifetime = 0.85; _fx_slime_drops.one_shot = false
	_fx_slime_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fx_slime_drops.emission_sphere_radius = 0.18; _fx_slime_drops.gravity = Vector3(0.0, -9.8, 0.0)
	_fx_slime_drops.initial_velocity_min = 0.4; _fx_slime_drops.initial_velocity_max = 2.2
	_fx_slime_drops.scale_amount_min = 0.04; _fx_slime_drops.scale_amount_max = 0.16
	_fx_slime_drops.color = Color(0.22, 0.0, 0.55, 0.9)
	_fx_slime_drops.position = Vector3(0.0, 0.3, 0.0); add_child(_fx_slime_drops)

func _build_tentacles() -> void:
	for i in 6:
		var t := MeshInstance3D.new(); var cy := CylinderMesh.new()
		cy.top_radius = 0.02; cy.bottom_radius = 0.07; cy.height = 0.9; t.mesh = cy
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.04, 0.0, 0.12, 1.0); m.emission_enabled = true
		m.emission = Color(0.4, 0.0, 1.0, 1.0); m.emission_energy_multiplier = 2.2
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.0
		t.material_override = m; t.visible = false; add_child(t); _tentacle_meshes.append(t)

func _build_pulse_rings() -> void:
	_pulse_ring = MeshInstance3D.new()
	var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; _pulse_ring.mesh = sp
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.6, 0.0, 1.0, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.emission_enabled = true
	m.emission = Color(0.5, 0.0, 1.0, 1.0); m.emission_energy_multiplier = 4.5
	_pulse_ring.material_override = m; _pulse_ring.position = Vector3(0.0, 0.9, 0.0)
	_pulse_ring.visible = false; add_child(_pulse_ring)

	_inner_ring = MeshInstance3D.new(); _inner_ring.mesh = sp
	var m2 := StandardMaterial3D.new(); m2.albedo_color = Color(1.0, 0.3, 0.8, 0.2)
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m2.emission_enabled = true
	m2.emission = Color(1.0, 0.0, 0.5, 1.0); m2.emission_energy_multiplier = 3.2
	_inner_ring.material_override = m2; _inner_ring.position = Vector3(0.0, 0.9, 0.0)
	_inner_ring.visible = false; add_child(_inner_ring)

	# Anillo tórico que crece DESDE el objetivo absorbido
	_absorb_ring = MeshInstance3D.new()
	var tor := TorusMesh.new(); tor.inner_radius = 0.3; tor.outer_radius = 0.55
	_absorb_ring.mesh = tor
	var m3 := StandardMaterial3D.new(); m3.albedo_color = Color(0.8, 0.0, 1.0, 0.55)
	m3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m3.emission_enabled = true
	m3.emission = Color(1.0, 0.0, 0.8, 1.0); m3.emission_energy_multiplier = 6.0
	_absorb_ring.material_override = m3; _absorb_ring.visible = false; add_child(_absorb_ring)

func _build_overlays() -> void:
	_overlay_layer = CanvasLayer.new(); _overlay_layer.layer = 15; add_child(_overlay_layer)

	_flash_rect = ColorRect.new(); _flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay_layer.add_child(_flash_rect)

	_danger_rect = ColorRect.new(); _danger_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger_rect.color = Color(0.55, 0.0, 0.0, 0.0)
	_danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay_layer.add_child(_danger_rect)

	# Distorsión de absorción — pulso verde/violeta
	_absorb_distort = ColorRect.new(); _absorb_distort.set_anchors_preset(Control.PRESET_FULL_RECT)
	_absorb_distort.color = Color(0.3, 0.0, 0.8, 0.0)
	_absorb_distort.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay_layer.add_child(_absorb_distort)

	# Scanlines CRT sutiles — dan identidad visual sci-fi
	_scanlines = ColorRect.new(); _scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanlines.color = Color(0.0, 0.0, 0.0, 0.06)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay_layer.add_child(_scanlines)

	# Aberración cromática: dos planos semitransparentes desplazados en X
	var ca_layer := CanvasLayer.new(); ca_layer.layer = 16; add_child(ca_layer)
	_ca_r = ColorRect.new(); _ca_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ca_r.color = Color(1.0, 0.0, 0.0, 0.0)
	_ca_r.mouse_filter = Control.MOUSE_FILTER_IGNORE; ca_layer.add_child(_ca_r)
	_ca_b = ColorRect.new(); _ca_b.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ca_b.color = Color(0.0, 0.0, 1.0, 0.0)
	_ca_b.mouse_filter = Control.MOUSE_FILTER_IGNORE; ca_layer.add_child(_ca_b)

# ── API pública ───────────────────────────────────────────

func set_state(s: String) -> void:
	if _state == s: return
	_state = s; _t = 0.0
	_fx_stream.emitting = (s == "absorb")
	for t in _tentacle_meshes: t.visible = (s == "absorb") and not _use_sprite
	_fx_slime_drops.emitting = (s == "walk")
	# Sprite
	match s:
		"idle":    _play_sprite("idle")
		"walk":    _play_sprite("walk")
		"absorb":  _play_sprite("absorb")
	# Distorsión de pantalla al entrar en absorción
	if s == "absorb":
		_absorb_distort_t = 1.0
	else:
		_absorb_distort_t = 0.0
		if _absorb_distort: _absorb_distort.color.a = 0.0

func set_sprinting(sprinting: bool) -> void:
	_was_sprinting = sprinting
	_fx_trail.emitting = sprinting and _state == "walk"
	_fx_slime_drops.emitting = _state == "walk"

func set_power(absorption_count: int) -> void:
	_power = absorption_count
	if _rim_light: _rim_light.light_energy = 0.8 + float(_power) * 0.08

func set_stealth_visual(active: bool) -> void:
	if body_mat:
		body_mat.albedo_color.a = 0.12 if active else 1.0
		body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if active else BaseMaterial3D.TRANSPARENCY_DISABLED
	if glow: glow.light_energy = 0.08 if active else (1.6 + float(_power) * 0.06)
	for em in _eye_mats: em.emission_energy_multiplier = 0.4 if active else 4.5
	if _rim_light: _rim_light.light_energy = 0.1 if active else (0.8 + float(_power) * 0.08)

func trigger_land_squash() -> void: _land_squash = 1.0

func set_danger_vignette(hp_fraction: float) -> void:
	_danger_hp = hp_fraction

func flash_damage() -> void:
	## Aberración cromática roja al recibir daño
	_ca_t = 0.60
	if _ca_r: _ca_r.color.a = 0.38; _ca_r.position.x = 9.0
	if _ca_b: _ca_b.color.a = 0.30; _ca_b.position.x = -9.0

func flash_absorb_complete() -> void:
	## Flash blanco brillante — el momento más impactante del juego
	_flash_t = 1.0
	if _flash_rect: _flash_rect.color.a = 0.78

func trigger_absorb_ring(world_pos: Vector3) -> void:
	## Anillo tórico que explota desde la posición del objetivo absorbido
	_absorb_ring.global_position = world_pos
	_absorb_ring.scale   = Vector3.ONE * 0.1
	_absorb_ring.visible = true
	_absorb_ring_active  = true; _absorb_ring_t = 0.0

func play_absorb_burst() -> void: _fx_burst.emitting = true

func play_absorb_burst_at(world_pos: Vector3) -> void:
	_fx_burst.global_position = world_pos; _fx_burst.emitting = true

func play_dash_flash() -> void:
	_play_sprite("dash")
	if body_mat:
		var tw := create_tween()
		tw.tween_property(body_mat, "emission_energy_multiplier", 14.0, 0.04)
		tw.tween_property(body_mat, "emission_energy_multiplier", 2.0, 0.22)
	_fx_trail.emitting = true; _ca_t = 0.28

func play_pulse_burst() -> void:
	_pulse_active = true; _pulse_t = 0.0
	if _pulse_ring: _pulse_ring.visible = true; _pulse_ring.scale = Vector3.ONE
	if _inner_ring: _inner_ring.visible = true; _inner_ring.scale = Vector3.ONE * 0.7

# ── Proceso ───────────────────────────────────────────────

func _process(delta: float) -> void:
	if body_mesh == null or glow == null: return
	_t += delta
	var power_glow := 1.6 + float(_power) * 0.07

	if _land_squash > 0.0:
		_land_squash = maxf(0.0, _land_squash - delta * 14.0)
		var sq := 1.0 - _land_squash * 0.14
		body_mesh.scale.y = sq
		body_mesh.scale.x = 1.0 + _land_squash * 0.07
		body_mesh.scale.z = body_mesh.scale.x
	else:
		_animate_state(power_glow)

	if _state == "absorb": _animate_tentacles()
	if _pulse_active: _animate_pulse(delta)
	if _absorb_ring_active: _animate_absorb_ring(delta)

	# Flash blanco
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta * 5.5)
		if _flash_rect: _flash_rect.color.a = _flash_t * 0.78

	# Aberración cromática (daño y dash)
	if _ca_t > 0.0:
		_ca_t = maxf(0.0, _ca_t - delta * 4.5)
		var off := _ca_t * 10.0
		if _ca_r: _ca_r.color.a = _ca_t * 0.38; _ca_r.position.x = off
		if _ca_b: _ca_b.color.a = _ca_t * 0.30; _ca_b.position.x = -off
	else:
		if _ca_r: _ca_r.color.a = 0.0
		if _ca_b: _ca_b.color.a = 0.0

	# Viñeta de peligro pulsante
	if _danger_rect:
		var danger := clampf(1.0 - _danger_hp * 2.8, 0.0, 0.88)
		_danger_rect.color.a = danger * (0.42 + sin(_t * 7.0) * 0.20)

	# Distorsión de absorción — pulso violeta que late mientras absorbes
	if _absorb_distort:
		if _state == "absorb":
			_absorb_distort.color.a = 0.10 + sin(_t * 9.0) * 0.07
			_absorb_distort.color = Color(
				0.2 + sin(_t * 6.0) * 0.1,
				0.0,
				0.7 + sin(_t * 8.5) * 0.2,
				_absorb_distort.color.a)
		elif _absorb_distort_t > 0.0:
			_absorb_distort_t = maxf(0.0, _absorb_distort_t - delta * 3.5)
			_absorb_distort.color.a = _absorb_distort_t * 0.18

	# Scanlines — parpadeo muy sutil sincronizado con el glow
	if _scanlines:
		_scanlines.color.a = 0.05 + sin(_t * 0.7) * 0.01

func _animate_state(power_glow: float) -> void:
	# Si hay sprite, solo actualizamos el glow (el sprite maneja la animación visual)
	if _use_sprite:
		if glow: glow.light_energy = power_glow + sin(_t * 3.14) * 0.35
		return
	match _state:
		"idle":
			var b := sin(_t * PI) * 0.04
			body_mesh.scale     = Vector3(1.0 + b, 1.0 - b * 0.6, 1.0 + b)
			body_mesh.position.y = 0.9 + sin(_t * PI) * 0.022
			glow.light_energy   = power_glow + sin(_t * 3.14) * 0.35
			for em in _eye_mats: em.emission_energy_multiplier = 4.5 + sin(_t * 1.5) * 0.9
		"walk":
			var b := sin(_t * 14.0) * 0.08
			var lean := sin(_t * 7.0) * 0.05
			body_mesh.position.y = 0.9 + absf(b) * 0.5
			body_mesh.scale = Vector3(1.0 + lean, 1.0 - absf(b) * 0.32, 1.0 - lean)
			glow.light_energy = power_glow + 0.45
		"absorb":
			var p := sin(_t * 6.5) * 0.30 + 1.25
			body_mesh.scale = Vector3(p, 2.3 - p * 0.52, p)
			glow.light_energy = power_glow + 4.5 + sin(_t * 12.0) * 3.5
			glow.omni_range   = 5.5 + sin(_t * 8.0) * 1.2
			if body_mat:
				var r := 0.38 + sin(_t * 13.0) * 0.22
				body_mat.emission = Color(r, 0.0, 1.0 - r * 0.3, 1.0)
				body_mat.emission_energy_multiplier = 3.5 + sin(_t * 9.5) * 1.8
			for em in _eye_mats:
				em.emission_energy_multiplier = 7.0 + sin(_t * 11.0) * 3.0

func _animate_tentacles() -> void:
	for i in _tentacle_meshes.size():
		var t : MeshInstance3D = _tentacle_meshes[i] as MeshInstance3D
		var angle := float(i) / float(_tentacle_meshes.size()) * TAU
		var wave  := sin(_t * 5.5 + float(i) * 1.1) * 0.45
		var reach := 0.85 + sin(_t * 3.2 + float(i) * 0.7) * 0.32
		t.position = Vector3(cos(angle+wave)*reach, 0.5+sin(_t*4.2+float(i)*0.9)*0.42, sin(angle+wave)*reach)
		t.look_at(Vector3(0.0, 0.9, 0.0)); t.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		var m := t.material_override as StandardMaterial3D
		if m: m.albedo_color.a = 0.65 + sin(_t * 7.5 + float(i)) * 0.3

func _animate_pulse(delta: float) -> void:
	_pulse_t += delta; var prog := _pulse_t / 0.72
	if prog >= 1.0:
		_pulse_active = false
		if _pulse_ring: _pulse_ring.visible = false
		if _inner_ring: _inner_ring.visible = false
	else:
		var s1 := 1.0 + prog * (Constants.SKILL_PULSE_RADIUS * 1.9)
		var s2 := 1.0 + maxf(0.0, prog - 0.12) * (Constants.SKILL_PULSE_RADIUS * 1.5)
		if _pulse_ring:
			_pulse_ring.scale = Vector3(s1, s1 * 0.18, s1)
			var m := _pulse_ring.material_override as StandardMaterial3D
			if m: m.albedo_color.a = 0.32 * (1.0 - prog)
		if _inner_ring:
			_inner_ring.scale = Vector3(s2, s2 * 0.28, s2)
			var m2 := _inner_ring.material_override as StandardMaterial3D
			if m2: m2.albedo_color.a = 0.26 * (1.0 - maxf(0.0, prog - 0.12))

func _animate_absorb_ring(delta: float) -> void:
	_absorb_ring_t += delta; var prog := _absorb_ring_t / 0.48
	if prog >= 1.0:
		_absorb_ring_active = false; _absorb_ring.visible = false
	else:
		var s := 0.1 + prog * 9.0
		_absorb_ring.scale = Vector3(s, s * 0.12, s)
		var m := _absorb_ring.material_override as StandardMaterial3D
		if m: m.albedo_color.a = 0.58 * (1.0 - prog)
