extends Node
## LevelBuilder v8 — helpers geométricos para la planta nuclear mejorada.
## Nuevos métodos v8: vent_shaft(), locked_door(), hazard_tile(), xp_orb(), alert_strip()

var _parent : Node3D = null

func setup(parent: Node3D) -> void:
	_parent = parent

# ─────────────────────────────────────────────────────────
# PRIMITIVAS BASE
# ─────────────────────────────────────────────────────────

## Caja estática con colisión y visual.
func slab(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi   := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size   = size
	mi.mesh   = bm
	var mat  := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness    = 0.85
	mat.metallic     = 0.15
	mi.material_override = mat
	body.add_child(mi)
	var cs   := CollisionShape3D.new()
	var bs   := BoxShape3D.new()
	bs.size   = size
	cs.shape  = bs
	body.add_child(cs)
	_parent.add_child(body)
	return body

## Cilindro estático con colisión.
func cylinder_prop(pos: Vector3, r: float, h: float, col: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi   := MeshInstance3D.new()
	var cm   := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h
	mi.mesh   = cm
	var mat  := StandardMaterial3D.new()
	mat.albedo_color = col; mat.roughness = 0.7; mat.metallic = 0.3
	mi.material_override = mat
	body.add_child(mi)
	var cs   := CollisionShape3D.new()
	var cy   := CylinderShape3D.new()
	cy.radius = r; cy.height = h
	cs.shape  = cy
	body.add_child(cs)
	_parent.add_child(body)

## Cartel luminoso emisivo (decorativo, sin colisión).
func sign_emissive(pos: Vector3, col: Color) -> void:
	var sm   := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size   = Vector3(2.6, 0.45, 0.07)
	sm.mesh   = bm
	sm.position = pos
	var mat  := StandardMaterial3D.new()
	mat.albedo_color               = Color(col.r*0.2, col.g*0.2, col.b*0.2, 1.0)
	mat.emission_enabled           = true
	mat.emission                   = col
	mat.emission_energy_multiplier = 1.0
	sm.material_override = mat
	_parent.add_child(sm)

## Luz de techo con fixture decorativo. Registrada en AlarmSystem.
func ceiling_light(lx: float, lz: float, col: Color, rng: float) -> OmniLight3D:
	var fix  := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size   = Vector3(0.32, 0.08, 0.32)
	fix.mesh  = bm
	fix.position = Vector3(lx, Constants.LEVEL_WALL_HEIGHT - 0.04, lz)
	var fm   := StandardMaterial3D.new()
	fm.albedo_color               = col
	fm.emission_enabled           = true
	fm.emission                   = col
	fm.emission_energy_multiplier = 3.0
	fix.material_override = fm
	_parent.add_child(fix)
	var lt   := OmniLight3D.new()
	lt.position     = Vector3(lx, Constants.LEVEL_WALL_HEIGHT - 0.35, lz)
	lt.light_color  = col
	lt.light_energy = 1.6
	lt.omni_range   = rng
	_parent.add_child(lt)
	Alarm.register_light(lt)
	return lt

# ─────────────────────────────────────────────────────────
# NUEVOS MÉTODOS v8
# ─────────────────────────────────────────────────────────

## Conducto de ventilación transitable para el jugador.
## add_npc_blocker: añade techo bajo que los NPCs (más altos) no pueden atravesar.
func vent_shaft(a: Vector3, b: Vector3, add_npc_blocker: bool = true) -> void:
	var W   := Constants.VENT_WIDTH
	var VH  := Constants.VENT_HEIGHT
	var TK  := Constants.LEVEL_WALL_THICK
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var dir := (b - a).normalized()
	var is_x := absf(dir.x) > absf(dir.z)
	var mc  := Color(0.28, 0.31, 0.34, 1.0)
	var cc  := Color(0.15, 0.17, 0.19, 1.0)
	if is_x:
		slab(Vector3(mid.x, a.y - TK*0.5,              mid.z), Vector3(len, TK, W),  mc)
		slab(Vector3(mid.x, a.y + VH + TK*0.5,         mid.z), Vector3(len, TK, W),  cc)
		slab(Vector3(mid.x, a.y + VH*0.5, mid.z - W*0.5), Vector3(len, VH, TK),      mc)
		slab(Vector3(mid.x, a.y + VH*0.5, mid.z + W*0.5), Vector3(len, VH, TK),      mc)
	else:
		slab(Vector3(mid.x, a.y - TK*0.5,              mid.z), Vector3(W, TK, len),  mc)
		slab(Vector3(mid.x, a.y + VH + TK*0.5,         mid.z), Vector3(W, TK, len),  cc)
		slab(Vector3(mid.x - W*0.5, a.y + VH*0.5, mid.z), Vector3(TK, VH, len),      mc)
		slab(Vector3(mid.x + W*0.5, a.y + VH*0.5, mid.z), Vector3(TK, VH, len),      mc)
	# Luz tenue interior
	var lt := OmniLight3D.new()
	lt.position     = Vector3(mid.x, a.y + VH * 0.5, mid.z)
	lt.light_color  = Color(0.4, 0.8, 0.5, 1.0)
	lt.light_energy = 0.45
	lt.omni_range   = len * 0.65
	_parent.add_child(lt)
	# Bloqueador de NPC (capa 2 = enemies)
	if add_npc_blocker:
		var bl := StaticBody3D.new()
		bl.position = Vector3(mid.x, a.y + VH + 0.6, mid.z)
		bl.collision_layer = 2; bl.collision_mask = 0
		var bcs := CollisionShape3D.new()
		var bbs := BoxShape3D.new()
		bbs.size = Vector3(len if is_x else W + 0.5, 1.2, W + 0.5 if is_x else len)
		bcs.shape = bbs
		bl.add_child(bcs)
		_parent.add_child(bl)

## Puerta bloqueada que se abre cuando el jugador tiene suficientes absorciones.
## Retorna el Area3D de trigger por si se quiere conectar señal extra.
func locked_door(pos: Vector3, size: Vector3, col: Color,
		required_absorptions: int, label: String = "") -> Area3D:
	# Cuerpo físico
	var door := StaticBody3D.new()
	door.name = "Door_" + label
	door.position = pos
	var dmi := MeshInstance3D.new()
	var dbm := BoxMesh.new()
	dbm.size = size
	dmi.mesh = dbm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color               = col
	dmat.emission_enabled           = true
	dmat.emission                   = col * 0.55
	dmat.emission_energy_multiplier = 1.4
	dmat.metallic  = 0.75
	dmat.roughness = 0.18
	dmi.material_override = dmat
	door.add_child(dmi)
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = size
	dcs.shape = dbs
	door.add_child(dcs)
	_parent.add_child(door)
	# Cartel de requisito
	if label != "":
		sign_emissive(Vector3(pos.x, pos.y + size.y*0.5 + 0.4, pos.z), col)
	# Sensor de proximidad
	var trigger := Area3D.new()
	trigger.name = "DoorTrigger_" + label
	trigger.position = pos
	var tcs := CollisionShape3D.new()
	var tbs := BoxShape3D.new()
	tbs.size = size + Vector3(2.0, 0.5, 2.0)
	tcs.shape = tbs
	trigger.add_child(tcs)
	_parent.add_child(trigger)
	# Closure de apertura — captura referencias locales
	var _opened  := false
	var door_ref := door
	var mat_ref  := dmat
	var req      := required_absorptions
	trigger.body_entered.connect(func(body: Node) -> void:
		if _opened: return
		if not body.is_in_group("player"): return
		if GM.absorption_count < req: return
		_opened = true
		AudioMgr.play_door_unlock()   # sonido de apertura
		var tw := door_ref.create_tween()
		tw.tween_property(door_ref, "position:y",
				door_ref.position.y + Constants.LEVEL_WALL_HEIGHT + 0.6,
				Constants.DOOR_OPEN_TIME).set_ease(Tween.EASE_IN)
		var col_shape := door_ref.get_node_or_null("CollisionShape3D")
		if col_shape: col_shape.disabled = true
		mat_ref.emission = Color(0.0, 1.0, 0.4, 1.0)
	)
	return trigger

## Tile de suelo peligroso (radiación, calor). Retorna Area3D para conectar daño.
func hazard_tile(center: Vector3, size_xz: Vector2, col: Color) -> Area3D:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size  = Vector3(size_xz.x, 0.06, size_xz.y)
	mi.mesh  = bm
	mi.position = center + Vector3(0, 0.03, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(col.r*0.25, col.g*0.25, col.b*0.25, 1.0)
	mat.emission_enabled           = true
	mat.emission                   = col
	mat.emission_energy_multiplier = 2.2
	mi.material_override = mat
	_parent.add_child(mi)
	var lt := OmniLight3D.new()
	lt.position     = center + Vector3(0, 1.0, 0)
	lt.light_color  = col
	lt.light_energy = 2.4
	lt.omni_range   = maxf(size_xz.x, size_xz.y) * 0.9
	_parent.add_child(lt)
	var area := Area3D.new()
	area.name = "HazardArea"
	area.position = center
	var cs  := CollisionShape3D.new()
	var bs  := BoxShape3D.new()
	bs.size  = Vector3(size_xz.x, 2.5, size_xz.y)
	cs.shape = bs
	area.add_child(cs)
	_parent.add_child(area)
	return area

## Orbe de XP recogible. Pequeño=verde, grande=dorado.
func xp_orb(pos: Vector3, amount: int) -> void:
	var col : Color
	if amount <= Constants.XP_ORB_SMALL:
		col = Color(0.2, 1.0, 0.55, 1.0)
	else:
		col = Color(1.0, 0.78, 0.0, 1.0)
	var orb := MeshInstance3D.new()
	var sm  := SphereMesh.new()
	sm.radius = 0.26; sm.height = 0.52
	orb.mesh  = sm
	orb.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = col * 0.25
	mat.emission_enabled           = true
	mat.emission                   = col
	mat.emission_energy_multiplier = 3.5
	orb.material_override = mat
	_parent.add_child(orb)
	var glow := OmniLight3D.new()
	glow.position     = pos
	glow.light_color  = col
	glow.light_energy = 1.2
	glow.omni_range   = 3.2
	_parent.add_child(glow)
	var area := Area3D.new()
	area.position = pos
	var cs   := CollisionShape3D.new()
	var ss   := SphereShape3D.new()
	ss.radius = 0.85
	cs.shape  = ss
	area.add_child(cs)
	_parent.add_child(area)
	var xp      := amount
	var orb_ref := orb
	var gl_ref  := glow
	area.body_entered.connect(func(body: Node) -> void:
		if not body.is_in_group("player"): return
		AudioMgr.play_xp_orb()   # sonido de recogida
		ProgressionMgr.add_xp(xp)
		orb_ref.queue_free()
		gl_ref.queue_free()
		area.queue_free()
	)

## Tira de luces rojas de alerta (zonas de peligro / tensión).
func alert_strip(origin: Vector3, count: int, step: float, is_x: bool) -> void:
	for i in count:
		var off := Vector3(i * step if is_x else 0.0, 0.0,
				0.0 if is_x else i * step)
		var lt := OmniLight3D.new()
		lt.position     = origin + off + Vector3(0.0, Constants.LEVEL_WALL_HEIGHT - 0.28, 0.0)
		lt.light_color  = Color(1.0, 0.08, 0.04, 1.0)
		lt.light_energy = 1.3
		lt.omni_range   = 4.2
		_parent.add_child(lt)
		Alarm.register_light(lt)
