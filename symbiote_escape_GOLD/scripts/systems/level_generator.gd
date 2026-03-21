extends Node3D
## LevelGenerator — Planta Nuclear. Versión comercial con ambiente cinematográfico.
## Mejoras: post-processing de calidad indie (SSAO, SSR, SDFGI), fog volumétrico,
##          luces de emergencia parpadeantes, entorno más atmosférico.

signal exit_reached

const WH := Constants.LEVEL_WALL_HEIGHT
const TK := Constants.LEVEL_WALL_THICK

# Paleta por zona
const C_ENTRADA   := Color(0.16, 0.18, 0.20, 1.0)
const C_LAB       := Color(0.12, 0.16, 0.22, 1.0)
const C_CONTROL   := Color(0.12, 0.18, 0.13, 1.0)
const C_REACTOR   := Color(0.08, 0.13, 0.08, 1.0)
const C_PELIGRO   := Color(0.20, 0.08, 0.08, 1.0)
const C_SECRETO   := Color(0.08, 0.12, 0.20, 1.0)
const C_SALIDA    := Color(0.08, 0.16, 0.16, 1.0)
const C_VESTUARIO := Color(0.18, 0.15, 0.10, 1.0)

const L_ENTRADA   := Color(0.8,  0.9,  1.0,  1.0)
const L_LAB       := Color(0.4,  0.6,  1.0,  1.0)
const L_CONTROL   := Color(0.3,  1.0,  0.4,  1.0)
const L_REACTOR   := Color(0.0,  1.0,  0.15, 1.0)
const L_PELIGRO   := Color(1.0,  0.2,  0.08, 1.0)
const L_SECRETO   := Color(0.1,  0.5,  1.0,  1.0)
const L_SALIDA    := Color(0.2,  1.0,  0.9,  1.0)

var _b : Node = null
var _flicker_lights : Array[OmniLight3D] = []  # luces que parpadean
var _flicker_timers : Array[float] = []

func generate() -> void:
	_b = load("res://scripts/systems/level_builder.gd").new()
	_b.setup(self)
	add_child(_b)
	_setup_environment()
	_build_all_rooms()
	_build_all_corridors()
	_build_ventilation_shafts()
	_build_locked_doors()
	_build_hazard_zones()
	_build_reactor_core()
	_build_secret_room()
	_build_exit()
	_build_props()
	_build_xp_orbs()
	_build_atmospheric_details()

func _setup_environment() -> void:
	var env := Environment.new()
	# Fondo oscuro industrial
	env.background_mode        = Environment.BG_COLOR
	env.background_color       = Color(0.008, 0.008, 0.015, 1.0)
	# Luz ambiental muy tenue — la oscuridad es importante en sigilo
	env.ambient_light_source   = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color    = Color(0.03, 0.04, 0.06, 1.0)
	env.ambient_light_energy   = 0.45
	# SSIL (Screen Space Indirect Light)
	env.ssil_enabled           = true
	env.ssil_radius            = 5.0
	env.ssil_intensity         = 1.2
	env.ssil_sharpness         = 0.98
	# SSAO para mejor percepción de profundidad
	env.ssao_enabled           = true
	env.ssao_radius            = 1.2
	env.ssao_intensity         = 2.5
	env.ssao_power             = 1.5
	# SSR para reflejos en suelos metálicos
	env.ssr_enabled            = true
	env.ssr_max_steps          = 32
	env.ssr_fade_in            = 0.15
	env.ssr_depth_tolerance    = 0.2
	# Bloom fuerte para sensación eléctrica/nuclear
	env.glow_enabled           = true
	env.glow_normalized        = false
	env.glow_intensity         = 1.0
	env.glow_strength          = 1.2
	env.glow_bloom             = 0.22
	env.glow_blend_mode        = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_levels/1          = true
	env.glow_levels/2          = true
	env.glow_levels/3          = true
	# Fog volumétrico para atmósfera densa
	env.volumetric_fog_enabled       = true
	env.volumetric_fog_density       = 0.018
	env.volumetric_fog_albedo        = Color(0.05, 0.06, 0.10, 1.0)
	env.volumetric_fog_emission      = Color(0.0, 0.0, 0.0, 1.0)
	env.volumetric_fog_gi_inject     = 1.0
	env.volumetric_fog_anisotropy    = 0.3
	env.volumetric_fog_length        = 64.0
	env.volumetric_fog_detail_spread = 2.0
	# Ajuste de color — film noir / sci-fi verde
	env.adjustment_enabled    = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast   = 1.15
	env.adjustment_saturation = 0.85
	# Tonemapping ACES para look cinematográfico
	env.tonemap_mode        = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure    = 1.1
	env.tonemap_white       = 6.0
	# DOF suave
	env.dof_blur_far_enabled   = true
	env.dof_blur_far_distance  = 38.0
	env.dof_blur_far_transition = 12.0
	env.dof_blur_amount        = 0.05

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Luz direccional tenue (sistema de iluminación interna)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	sun.light_color      = Color(0.4, 0.45, 0.55, 1.0)
	sun.light_energy     = 0.25
	sun.shadow_enabled   = true
	sun.shadow_blur      = 1.5
	add_child(sun)

func _build_all_rooms() -> void:
	var rooms := [
		[ 0.0,  16.0, 14.0, 14.0, C_ENTRADA,  L_ENTRADA,  "ENTRADA"       ],
		[26.0,  22.0, 10.0,  8.0, C_VESTUARIO,L_ENTRADA,  "VESTUARIO"     ],
		[28.0,   4.0, 16.0, 14.0, C_LAB,      L_LAB,      "LABORATORIO A" ],
		[-28.0,  4.0, 16.0, 14.0, C_LAB,      L_LAB,      "LABORATORIO B" ],
		[ 0.0, -20.0, 14.0, 16.0, C_CONTROL,  L_CONTROL,  "SALA CONTROL"  ],
		[ 0.0, -60.0, 12.0, 12.0, C_SALIDA,   L_SALIDA,   "ZONA SALIDA"   ],
		[30.0, -46.0, 18.0, 18.0, C_REACTOR,  L_REACTOR,  "NUCLEO REACTOR"],
		[-30.0,-46.0, 16.0, 14.0, C_PELIGRO,  L_PELIGRO,  "HUB SEGURIDAD" ],
		[30.0, -20.0, 14.0, 12.0, C_REACTOR,  L_REACTOR,  "ARCHIVO"       ],
		[-30.0,-20.0, 12.0, 12.0, C_SECRETO,  L_SECRETO,  "CAMARA FRIA"   ],
	]
	for r : Array in rooms:
		_build_room(r[0], r[1], r[2], r[3], r[4], r[5], r[6])

func _build_room(cx: float, cz: float, rw: float, rd: float,
		col: Color, lcol: Color, lbl: String) -> void:
	var hw := rw * 0.5; var hd := rd * 0.5
	# Materiales con roughness variado para más realismo
	var floor_col := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 1.0)
	var ceil_col  := Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 1.0)
	_b.slab(Vector3(cx, -TK*0.5, cz),     Vector3(rw, TK, rd), floor_col)
	_b.slab(Vector3(cx, WH+TK*0.5, cz),   Vector3(rw, TK, rd), ceil_col)
	_b.slab(Vector3(cx, WH*0.5, cz-hd),   Vector3(rw, WH, TK), col)
	_b.slab(Vector3(cx, WH*0.5, cz+hd),   Vector3(rw, WH, TK), col)
	_b.slab(Vector3(cx-hw, WH*0.5, cz),   Vector3(TK, WH, rd), col)
	_b.slab(Vector3(cx+hw, WH*0.5, cz),   Vector3(TK, WH, rd), col)
	for lx in [-rw*0.25, rw*0.25]:
		for lz in [-rd*0.25, rd*0.25]:
			_b.ceiling_light(cx + lx, cz + lz, lcol, maxf(rw, rd) * 0.9)
	if lbl != "":
		_b.sign_emissive(Vector3(cx, WH*0.75, cz-hd+0.07), lcol)

func _build_all_corridors() -> void:
	_corridor(Vector3(7,0,16),    Vector3(20,0,16),   3.6)
	_corridor(Vector3(-7,0,16),   Vector3(-20,0,16),  3.6)
	_corridor(Vector3(0,0,9),     Vector3(0,0,-12),   4.2)
	_corridor(Vector3(7,0,22),    Vector3(21,0,22),   2.8)
	_corridor(Vector3(20,0,4),    Vector3(7,0,-20),   3.2)
	_corridor(Vector3(-20,0,4),   Vector3(-7,0,-20),  3.2)
	_corridor(Vector3(7,0,-20),   Vector3(23,0,-20),  3.2)
	_corridor(Vector3(-7,0,-20),  Vector3(-24,0,-20), 3.2)
	_corridor(Vector3(0,0,-28),   Vector3(0,0,-54),   4.2)
	_corridor(Vector3(7,0,-46),   Vector3(21,0,-46),  3.6)
	_corridor(Vector3(-7,0,-46),  Vector3(-22,0,-46), 3.6)
	_corridor(Vector3(30,0,-29),  Vector3(30,0,-37),  3.6)
	_corridor(Vector3(-30,0,-26), Vector3(-30,0,-39), 3.0)

func _corridor(a: Vector3, b: Vector3, w: float) -> void:
	var mid  := (a + b) * 0.5
	var len  := a.distance_to(b)
	var dir  := (b - a).normalized()
	var is_x := absf(dir.x) > absf(dir.z)
	var cx   := mid.x; var cz := mid.z
	var wc   := Color(0.12, 0.14, 0.16, 1.0)
	var fc   := Color(0.11, 0.12, 0.14, 1.0)
	var cc   := Color(0.08, 0.09, 0.11, 1.0)
	if is_x:
		_b.slab(Vector3(cx,-TK*0.5,cz), Vector3(len,TK,w), fc)
		_b.slab(Vector3(cx,WH+TK*0.5,cz), Vector3(len,TK,w), cc)
		_b.slab(Vector3(cx,WH*0.5,cz-w*0.5), Vector3(len,WH,TK), wc)
		_b.slab(Vector3(cx,WH*0.5,cz+w*0.5), Vector3(len,WH,TK), wc)
	else:
		_b.slab(Vector3(cx,-TK*0.5,cz), Vector3(w,TK,len), fc)
		_b.slab(Vector3(cx,WH+TK*0.5,cz), Vector3(w,TK,len), cc)
		_b.slab(Vector3(cx-w*0.5,WH*0.5,cz), Vector3(TK,WH,len), wc)
		_b.slab(Vector3(cx+w*0.5,WH*0.5,cz), Vector3(TK,WH,len), wc)
	var lt := OmniLight3D.new()
	lt.position     = Vector3(cx, WH - 0.4, cz)
	lt.light_color  = Color(0.65, 0.70, 0.78, 1.0)
	lt.light_energy = 1.4
	lt.omni_range   = maxf(len, w) * 0.85
	lt.light_volumetric_fog_energy = 0.3
	add_child(lt)
	Alarm.register_light(lt)

func _build_ventilation_shafts() -> void:
	_b.vent_shaft(Vector3(4.5, 0, 9),   Vector3(4.5, 0, -14), true)
	_b.vent_shaft(Vector3(22, 0, 4),    Vector3(22, 0, -14),  true)
	_b.vent_shaft(Vector3(-22, 0, 4),   Vector3(-22, 0, -14), true)
	_b.vent_shaft(Vector3(-7, 0, -35),  Vector3(-24, 0, -35), true)

func _build_locked_doors() -> void:
	_b.locked_door(Vector3(23, WH*0.5, -20), Vector3(TK+0.3, WH, 3.4),
		Color(0.9, 0.55, 0.0, 1.0), Constants.DOOR_REQ_ARCHIVO, "ARCHIVO")
	_b.locked_door(Vector3(-24, WH*0.5, -20), Vector3(TK+0.3, WH, 3.0),
		Color(0.1, 0.5, 1.0, 1.0), Constants.DOOR_REQ_CAMARA_FRIA, "CAMARA")

func _build_hazard_zones() -> void:
	var hz_reactor := _b.hazard_tile(Vector3(30,0,-46), Vector2(12.0,12.0), Color(0.0,1.0,0.15,1.0))
	var hz_hub     := _b.hazard_tile(Vector3(-30,0,-46), Vector2(10.0,8.0), Color(1.0,0.15,0.0,1.0))
	_b.alert_strip(Vector3(22,0,-37), 5, 3.5, false)
	_b.alert_strip(Vector3(-36,0,-39), 4, 3.5, false)
	_wire_hazard_damage(hz_reactor, 4.0)
	_wire_hazard_damage(hz_hub, 4.0)

func _wire_hazard_damage(area: Area3D, dps: float) -> void:
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"): body.set_meta("in_hazard", true)
	)
	area.body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"): body.set_meta("in_hazard", false)
	)
	var timer := Timer.new()
	timer.wait_time = 0.5; timer.autostart = true
	timer.timeout.connect(func() -> void:
		for b in area.get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(dps * 0.5)
				AudioMgr.play_hazard_tick()
	)
	area.add_child(timer)

func _build_reactor_core() -> void:
	var cx := 30.0; var cz := -46.0
	var mesh := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius = 2.2; cyl.bottom_radius = 2.6; cyl.height = 3.8
	mesh.mesh = cyl; mesh.position = Vector3(cx, 1.9, cz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.04, 0.20, 0.06, 1.0)
	mat.emission_enabled           = true
	mat.emission                   = Color(0.0, 0.9, 0.2, 1.0)
	mat.emission_energy_multiplier = 4.5
	mat.metallic = 0.92; mat.roughness = 0.08
	mesh.material_override = mat
	add_child(mesh)
	var body := StaticBody3D.new()
	body.position = Vector3(cx, 1.9, cz)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.6; cy.height = 3.8
	cs.shape = cy; body.add_child(cs); add_child(body)
	for i in 8:
		var ang := float(i) / 8.0 * TAU
		var lt  := OmniLight3D.new()
		lt.position    = Vector3(cx+cos(ang)*3.8, 1.5, cz+sin(ang)*3.8)
		lt.light_color  = Color(0.0, 1.0, 0.3, 1.0)
		lt.light_energy = 3.5
		lt.omni_range   = 6.0
		lt.light_volumetric_fog_energy = 1.5
		add_child(lt)

func _build_secret_room() -> void:
	_b.cylinder_prop(Vector3(-30, 0.8, -20), 0.5, 1.6, Color(0.3, 0.5, 0.8, 1.0))
	_b.cylinder_prop(Vector3(-28, 0.8, -22), 0.4, 1.4, Color(0.2, 0.4, 0.7, 1.0))
	_b.cylinder_prop(Vector3(-32, 0.8, -18), 0.4, 1.4, Color(0.2, 0.4, 0.7, 1.0))
	_b.slab(Vector3(-30, WH*0.5, -26.2), Vector3(10.0, WH, TK), Color(0.12, 0.20, 0.38, 1.0))
	var cold := OmniLight3D.new()
	cold.position    = Vector3(-30, 0.3, -20)
	cold.light_color = Color(0.2, 0.5, 1.0, 1.0)
	cold.light_energy = 2.0; cold.omni_range = 9.0
	cold.light_volumetric_fog_energy = 1.0
	add_child(cold)

func _build_exit() -> void:
	var area := Area3D.new()
	area.position = Vector3(0.0, 1.0, -60.0)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(8.0, 3.0, 2.0)
	cs.shape = bx; area.add_child(cs)
	area.body_entered.connect(_on_exit_body)
	add_child(area)
	_b.sign_emissive(Vector3(0.0, 3.3, -59.8), Color(0.2, 1.0, 0.9, 1.0))
	for i in 4:
		var arr := MeshInstance3D.new()
		var bm  := BoxMesh.new(); bm.size = Vector3(0.55, 0.14, 0.55)
		arr.mesh = bm; arr.position = Vector3(0.0, 0.3+float(i)*0.28, -59.2)
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(0.0,1.0,0.5,1.0)
		am.emission_enabled = true; am.emission = Color(0.0,1.0,0.5,1.0)
		am.emission_energy_multiplier = 5.0
		arr.material_override = am; add_child(arr)

func _on_exit_body(body: Node) -> void:
	if body.is_in_group("player"): exit_reached.emit()

func _build_props() -> void:
	_b.slab(Vector3(-4,0.5,-20), Vector3(1.0,1.0,0.4), Color(0.18,0.28,0.18,1.0))
	_b.slab(Vector3( 4,0.5,-20), Vector3(1.0,1.0,0.4), Color(0.18,0.28,0.18,1.0))
	_b.slab(Vector3( 0,0.5,-28), Vector3(1.2,1.0,0.4), Color(0.18,0.28,0.18,1.0))
	for px in [24.0, 30.0, -24.0, -30.0]:
		_b.slab(Vector3(px, 0.45, 4.0), Vector3(2.0, 0.9, 0.7), Color(0.26,0.26,0.30,1.0))
	for bp in [Vector3(5,0.6,16), Vector3(-5,0.6,16), Vector3(5,0.6,12)]:
		_b.cylinder_prop(bp, 0.3, 1.2, Color(0.45,0.28,0.08,1.0))
	for bx in [Vector3(28,0.3,-18), Vector3(31,0.3,-22), Vector3(33,0.3,-18)]:
		_b.slab(bx, Vector3(1.2,0.6,0.9), Color(0.32,0.25,0.16,1.0))
	for lx in [24.0, 25.4, 26.8]:
		_b.slab(Vector3(lx, 1.0, 22.0), Vector3(1.2, 2.0, 0.5), Color(0.28,0.28,0.32,1.0))
	_b.cylinder_prop(Vector3(3, 0.6, -46), 0.35, 1.3, Color(0.22,0.48,0.48,1.0))
	_b.cylinder_prop(Vector3(-3, 0.6, -52), 0.35, 1.3, Color(0.22,0.48,0.48,1.0))

func _build_xp_orbs() -> void:
	_b.xp_orb(Vector3(26, 0.8, 22),  Constants.XP_ORB_SMALL)
	_b.xp_orb(Vector3(4.5, 0.8, -4), Constants.XP_ORB_SMALL)
	_b.xp_orb(Vector3(22, 0.8, -4),  Constants.XP_ORB_SMALL)
	_b.xp_orb(Vector3(-22, 0.8, -4), Constants.XP_ORB_SMALL)
	_b.xp_orb(Vector3(-30, 0.8, -20), Constants.XP_ORB_LARGE)
	_b.xp_orb(Vector3(30, 0.8, -20),  Constants.XP_ORB_LARGE)
	_b.xp_orb(Vector3(30, 0.8, -46),  Constants.XP_ORB_LARGE)

# ── Detalles atmosféricos ─────────────────────────────────
func _build_atmospheric_details() -> void:
	# Luces de emergencia rojas que parpadean en zonas de peligro
	var flicker_positions := [
		Vector3(25, 3.2, -40), Vector3(35, 3.2, -40),
		Vector3(-25, 3.2, -40), Vector3(-35, 3.2, -40),
		Vector3(0, 3.2, -35), Vector3(0, 3.2, -50),
	]
	for pos in flicker_positions:
		var fl := OmniLight3D.new()
		fl.position     = pos
		fl.light_color  = Color(1.0, 0.05, 0.02, 1.0)
		fl.light_energy = 1.8
		fl.omni_range   = 7.0
		fl.light_volumetric_fog_energy = 0.8
		add_child(fl)
		_flicker_lights.append(fl)
		_flicker_timers.append(randf_range(1.0, Constants.FLICKER_INTERVAL_MAX))

	# Manchas de humedad en paredes (cuadrados oscuros decorativos)
	var stain_positions := [
		[Vector3(-3.8, 1.5, 9.0), Vector3(0.4, 1.2, 0.06)],
		[Vector3(4.0, 2.0, -12.0), Vector3(0.6, 0.8, 0.06)],
		[Vector3(-7.0, 1.0, -28.0), Vector3(0.5, 1.5, 0.06)],
	]
	for st : Array in stain_positions:
		var sm := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = st[1] as Vector3
		sm.mesh = bm; sm.position = st[0] as Vector3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.04, 0.04, 0.06, 1.0)
		mat.roughness    = 0.95
		sm.material_override = mat
		add_child(sm)

func _process(delta: float) -> void:
	# Parpadeo de luces de emergencia
	for i in _flicker_lights.size():
		_flicker_timers[i] -= delta
		if _flicker_timers[i] <= 0.0:
			var fl : OmniLight3D = _flicker_lights[i]
			fl.light_energy = 0.0 if fl.light_energy > 0.5 else 1.8
			if fl.light_energy > 0.5:
				# Resetear con intervalo normal
				_flicker_timers[i] = randf_range(Constants.FLICKER_INTERVAL_MIN, Constants.FLICKER_INTERVAL_MAX)
			else:
				# Apagado: breve
				_flicker_timers[i] = randf_range(0.05, 0.25)
