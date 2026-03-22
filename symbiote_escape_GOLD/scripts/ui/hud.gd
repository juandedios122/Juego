extends CanvasLayer
## HUD — versión comercial con feedback visual fuerte.
## Añadido: heartbeat connection, pulso de absorción, damage flash, vignette de peligro.

var _root          : Control = null
var _alarm_bar     : ColorRect
var _alarm_lbl     : Label
var _alarm_dot     : ColorRect
var _alarm_line    : ColorRect = null
var _hp_fill       : ColorRect
var _hp_lbl        : Label
var _hp_bg         : ColorRect
var _xp_fill       : ColorRect
var _xp_lbl        : Label
var _lvl_badge     : Label
var _abs_num       : Label
var _abs_pulse     : ColorRect = null  # pulsa al absorber

const SKILL_IDS  := ["DASH",  "PULSO",  "CAMUFLAJE"]
const SKILL_KEYS := ["Q",     "R",      "F"]
const SKILL_COLS := [Color(0.4, 0.8, 1.0), Color(1.0, 0.6, 0.3), Color(0.7, 0.4, 1.0)]
var _slots       : Dictionary = {}

const ALL_PASSIVES := ["VELOCIDAD", "SUPER_SALTO", "FUERZA", "SIGILO", "SENTIDO"]
var _passive_rows  : Dictionary = {}

# ── Indicadores de dirección y objetivo ──────────────────
var _threat_arrows  : Array = []   # 4 triángulos de dirección de amenaza
var _objective_lbl  : Label = null
var _absorb_notif   : Label = null
var _notif_tween    : Tween = null

var _ability_sys            : Node = null
var _dot_tween              : Tween = null
var _last_alarm             : int   = -1
var _has_ability_sys_method : bool  = false
var _passive_tick           : float = 0.0
var _abs_prev               : int   = 0

const BG_PANEL  := Color(0.04, 0.05, 0.08, 0.90)
const BG_DARK   := Color(0.02, 0.02, 0.04, 0.96)
const COL_HP    := Color(0.15, 0.90, 0.45, 1.0)
const COL_HP_LO := Color(1.0,  0.22, 0.12, 1.0)
const COL_XP    := Color(0.60, 0.35, 1.00, 1.0)
const COL_ABS   := Color(0.30, 0.80, 1.00, 1.0)
const COL_TEXT  := Color(0.85, 0.88, 0.92, 1.0)
const COL_MUTED := Color(0.45, 0.48, 0.55, 1.0)
const ALARM_COLS := [
	Color(0.12, 0.70, 0.30, 1.0),
	Color(0.90, 0.72, 0.08, 1.0),
	Color(1.00, 0.35, 0.05, 1.0),
	Color(1.00, 0.05, 0.20, 1.0),
]
const ALARM_LABELS := ["●  CALMA", "◆  ALERTA", "▲  ALARMA", "■  LOCKDOWN"]

func _ready() -> void:
	layer = 5; _build(); _connect_signals()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_alarm_bar(); _build_health_panel(); _build_xp_panel()
	_build_abs_panel(); _build_crosshair(); _build_skill_bar()
	_build_passives_panel(); _build_controls_hint()
	_build_threat_indicator(); _build_objective_label(); _build_absorb_notification()

func _build_alarm_bar() -> void:
	_alarm_bar = _rect(_root, Vector2(0,0), Vector2(1920,36), BG_DARK)
	_alarm_line = _rect(_root, Vector2(0,34), Vector2(1920,2), ALARM_COLS[0] as Color)
	_alarm_dot  = _rect(_root, Vector2(840,9), Vector2(14,14), ALARM_COLS[0] as Color)
	_alarm_lbl  = _lbl(_root, Vector2(0,4), Vector2(1920,28), ALARM_LABELS[0] as String,
		14, ALARM_COLS[0] as Color, HORIZONTAL_ALIGNMENT_CENTER)

func _refresh_alarm_bar(level: int) -> void:
	var col : Color = ALARM_COLS[clampi(level, 0, 3)] as Color
	_alarm_lbl.text = ALARM_LABELS[clampi(level, 0, 3)] as String
	_alarm_lbl.add_theme_color_override("font_color", col)
	_alarm_dot.color = col
	if _alarm_line: _alarm_line.color = col
	if _dot_tween: _dot_tween.kill()
	if level >= 2:
		_dot_tween = create_tween().set_loops()
		_dot_tween.tween_property(_alarm_dot, "modulate:a", 0.1, 0.28)
		_dot_tween.tween_property(_alarm_dot, "modulate:a", 1.0, 0.28)
	else:
		_alarm_dot.modulate.a = 1.0
	_alarm_bar.color = Color(0.20, 0.02, 0.02, 0.96) if level == 3 else BG_DARK

func _build_health_panel() -> void:
	var PX := 18; var PY := 48; var PW := 238; var PH := 72
	_rect(_root, Vector2(PX,PY), Vector2(PW,PH), BG_PANEL)
	_rect(_root, Vector2(PX,PY), Vector2(3,PH), COL_HP)
	_lbl(_root, Vector2(PX+10,PY+7), Vector2(120,18), "ENERGÍA", 11, COL_MUTED)
	_hp_lbl = _lbl(_root, Vector2(PX+10,PY+7), Vector2(PW-12,18), "100 / 100",
		11, COL_HP, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_bg  = _rect(_root, Vector2(PX+10,PY+32), Vector2(PW-20,14), Color(0.06,0.10,0.08,1.0))
	_hp_fill = _rect(_root, Vector2(PX+10,PY+32), Vector2(PW-20,14), COL_HP)
	for i in 3:
		_rect(_root, Vector2(PX+10+(PW-20)*0.25*(i+1),PY+32), Vector2(1,14), Color(0.04,0.05,0.08,0.7))
	_lbl(_root, Vector2(PX+10,PY+52), Vector2(PW-12,16), "VITALIDAD SIMBIONTE", 10, COL_MUTED)

func _build_xp_panel() -> void:
	var PX := 18; var PY := 130; var PW := 238; var PH := 56
	_rect(_root, Vector2(PX,PY), Vector2(PW,PH), BG_PANEL)
	_rect(_root, Vector2(PX,PY), Vector2(3,PH), COL_XP)
	_xp_lbl  = _lbl(_root, Vector2(PX+10,PY+7), Vector2(PW-12,16), "0 / 100", 11, COL_XP, HORIZONTAL_ALIGNMENT_RIGHT)
	_rect(_root, Vector2(PX+10,PY+30), Vector2(PW-20,10), Color(0.06,0.04,0.10,1.0))
	_xp_fill  = _rect(_root, Vector2(PX+10,PY+30), Vector2(0,10), COL_XP)
	_lvl_badge = _lbl(_root, Vector2(PX+10,PY+6), Vector2(PW-20,18), "NIV. 1", 11, COL_XP)

func _build_abs_panel() -> void:
	var PX := 18; var PY := 198; var PW := 238; var PH := 70
	_rect(_root, Vector2(PX,PY), Vector2(PW,PH), BG_PANEL)
	_rect(_root, Vector2(PX,PY), Vector2(3,PH), COL_ABS)
	_lbl(_root, Vector2(PX+10,PY+7), Vector2(160,16), "ABSORCIONES", 11, COL_MUTED)
	_abs_num   = _lbl(_root, Vector2(PX+8,PY+24), Vector2(PW-16,36), "0", 32, COL_ABS)
	# Pulso al absorber
	_abs_pulse = _rect(_root, Vector2(PX,PY), Vector2(PW,PH), Color(COL_ABS.r, COL_ABS.g, COL_ABS.b, 0.0))
	_lbl(_root, Vector2(PX+10,PY+52), Vector2(PW-12,14), "NECESITAS: 2 ARCHIVO  3 CAMARA", 9, COL_MUTED)

func _build_crosshair() -> void:
	var cx := 960.0; var cy := 540.0; var col := Color(1.0,1.0,1.0,0.55)
	_rect(_root, Vector2(cx-8,cy-0.5), Vector2(6,1), col)
	_rect(_root, Vector2(cx+2,cy-0.5), Vector2(6,1), col)
	_rect(_root, Vector2(cx-0.5,cy-8), Vector2(1,6), col)
	_rect(_root, Vector2(cx-0.5,cy+2), Vector2(1,6), col)
	_rect(_root, Vector2(cx-1,cy-1), Vector2(2,2), Color(1.0,1.0,1.0,0.95))

func _build_skill_bar() -> void:
	var SW := 118; var SH := 100; var GAP := 10
	var total_w := SKILL_IDS.size() * SW + (SKILL_IDS.size()-1) * GAP
	var bx := (1920 - total_w) / 2; var by := 964
	_rect(_root, Vector2(bx-8,by-8), Vector2(total_w+16,SH+16), BG_DARK)
	for i in SKILL_IDS.size():
		var sid : String = SKILL_IDS[i] as String; var key : String = SKILL_KEYS[i] as String; var col : Color = SKILL_COLS[i] as Color
		var x   := bx + i * (SW + GAP)
		var slot_bg := _rect(_root, Vector2(x,by), Vector2(SW,SH), BG_PANEL)
		var accent  := _rect(_root, Vector2(x,by), Vector2(SW,3), col * 0.5)
		var overlay := _rect(_root, Vector2(x,by), Vector2(SW,0), Color(0,0,0,0.72))
		var name_l  := _lbl(_root, Vector2(x+4,by+10), Vector2(SW-8,22), sid, 14, col, HORIZONTAL_ALIGNMENT_CENTER)
		var key_l   := _lbl(_root, Vector2(x+4,by+36), Vector2(SW-8,18), "[%s]" % key, 12, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var cd_l    := _lbl(_root, Vector2(x+4,by+62), Vector2(SW-8,20), "LISTO", 12, Color(0.3,1.0,0.5), HORIZONTAL_ALIGNMENT_CENTER)
		var lock_l  := _lbl(_root, Vector2(x+4,by+30), Vector2(SW-8,40),
			"Nivel %d" % ProgressionMgr.get_unlock_level(sid), 12, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_slots[sid] = {"bg":slot_bg,"accent":accent,"overlay":overlay,"name_l":name_l,"key_l":key_l,"cd_l":cd_l,"lock_l":lock_l}
	_refresh_skill_locks()

func _build_passives_panel() -> void:
	var PX := 1664.0
	_lbl(_root, Vector2(PX,48), Vector2(240,20), "HABILIDADES PASIVAS", 10, COL_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var PCOLS := {"VELOCIDAD":Color(0.3,0.9,1.0),"SUPER_SALTO":Color(0.5,1.0,0.5),
		"FUERZA":Color(1.0,0.5,0.3),"SIGILO":Color(0.7,0.5,1.0),"SENTIDO":Color(1.0,0.9,0.3)}
	for i in ALL_PASSIVES.size():
		var name : String = ALL_PASSIVES[i] as String; var pcol : Color = PCOLS.get(name, COL_TEXT) as Color
		var ry   : float  = 70.0 + i * 30.0
		var row_bg := _rect(_root, Vector2(PX-4,ry), Vector2(244,24), BG_PANEL)
		_rect(_root, Vector2(PX-4,ry), Vector2(2,24), pcol)
		var timer_l := _lbl(_root, Vector2(PX+4,ry+4), Vector2(234,18), "● " + name, 12, pcol, HORIZONTAL_ALIGNMENT_RIGHT)
		row_bg.visible = false; timer_l.visible = false
		_passive_rows[name] = {"bg":row_bg,"timer":timer_l}

func _build_controls_hint() -> void:
	_rect(_root, Vector2(0,1072), Vector2(1920,8), BG_DARK)
	_lbl(_root, Vector2(0,1058), Vector2(1920,14),
		"WASD · Mover   Shift · Sprint   Espacio · Saltar   E · Absorber   Q · Dash   R · Pulso   F · Camuflaje   ESC · Pausa",
		11, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _build_threat_indicator() -> void:
	var poses  := [Vector2(960,62), Vector2(960,1018), Vector2(54,540), Vector2(1866,540)]
	var rots   := [0.0, PI, -PI*0.5, PI*0.5]
	for i in 4:
		var ar := ColorRect.new(); ar.size = Vector2(20,20)
		ar.position = poses[i] - Vector2(10,10); ar.rotation = rots[i]
		ar.color = Color(1.0, 0.18, 0.02, 0.0)
		ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(ar); _threat_arrows.append(ar)

func _build_objective_label() -> void:
	_objective_lbl = _lbl(_root, Vector2(0, 42), Vector2(1920, 20),
		"▶  OBJETIVO: Llega a la ZONA DE SALIDA (norte)",
		11, Color(0.65, 0.88, 0.65, 0.65), HORIZONTAL_ALIGNMENT_CENTER)

func _build_absorb_notification() -> void:
	_absorb_notif = _lbl(_root, Vector2(760, 515), Vector2(400, 36),
		"", 17, Color(0.7, 0.4, 1.0, 0.0), HORIZONTAL_ALIGNMENT_CENTER)

func show_absorb_notification(ability_name: String) -> void:
	if _absorb_notif == null: return
	var labels := {
		"SIGILO": "+ SIGILO  —  eres invisible", "VELOCIDAD": "+ VELOCIDAD  —  sprint 2×",
		"SENTIDO": "+ SENTIDO  —  percibes enemigos", "SUPER_SALTO": "+ SUPER SALTO",
		"FUERZA": "+ FUERZA  —  daño reducido (permanente)",
	}
	_absorb_notif.text = labels.get(ability_name, "+ " + ability_name)
	_absorb_notif.modulate.a = 0.0
	if _notif_tween: _notif_tween.kill()
	_notif_tween = create_tween()
	_notif_tween.tween_property(_absorb_notif, "modulate:a", 1.0, 0.16)
	_notif_tween.tween_interval(1.8)
	_notif_tween.tween_property(_absorb_notif, "modulate:a", 0.0, 0.55)

func update_threat_direction(guard_pos: Vector3, player_pos: Vector3,
		cam: Transform3D, alarm_level: int) -> void:
	if _threat_arrows.is_empty(): return
	if alarm_level < 1:
		for a in _threat_arrows: (a as ColorRect).color.a = 0.0; return
	var to_g := (guard_pos - player_pos).normalized()
	var fwd  := -cam.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var rgt  := cam.basis.x;  rgt.y = 0.0; rgt = rgt.normalized()
	var dot_f := to_g.dot(fwd); var dot_r := to_g.dot(rgt)
	var v := clampf(float(alarm_level) / 3.0, 0.25, 1.0)
	(_threat_arrows[0] as ColorRect).color.a = maxf(0.0, dot_f) * v * 0.9
	(_threat_arrows[1] as ColorRect).color.a = maxf(0.0, -dot_f) * v * 0.9
	(_threat_arrows[2] as ColorRect).color.a = maxf(0.0, -dot_r) * v * 0.9
	(_threat_arrows[3] as ColorRect).color.a = maxf(0.0, dot_r) * v * 0.9

func _connect_signals() -> void:
	ProgressionMgr.xp_changed.connect(_on_xp)
	ProgressionMgr.level_up.connect(_on_level_up)
	GM.player_health_changed.connect(_on_health_for_heartbeat)

func _on_health_for_heartbeat(hp: float, max_hp: float) -> void:
	AudioMgr.set_heartbeat(hp / max_hp)

func set_ability_system(ab_sys: Node) -> void:
	_ability_sys = ab_sys
	_has_ability_sys_method = ab_sys != null and ab_sys.has_method("get_remaining")
	if ab_sys == null: return
	ab_sys.passive_gained.connect(_on_passive_gained)
	ab_sys.passive_lost.connect(_on_passive_lost)
	ab_sys.cooldown_updated.connect(_on_cooldown_updated)

func update_health(hp: float, max_hp: float) -> void:
	if _hp_fill == null: return
	var frac := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_hp_fill.size.x = (238-20) * frac
	_hp_lbl.text    = "%d / %d" % [int(hp), int(max_hp)]
	_hp_fill.color  = COL_HP_LO if frac < 0.3 else COL_HP

func update_absorptions(count: int) -> void:
	if _abs_num: _abs_num.text = str(count)
	# Pulso dramático al absorber
	if count > _abs_prev and _abs_pulse:
		_abs_prev = count
		var tw := create_tween()
		tw.tween_property(_abs_pulse, "color:a", 0.55, 0.06)
		tw.tween_property(_abs_pulse, "color:a", 0.0, 0.35)

func update_alarm(level: int) -> void:
	if level == _last_alarm: return
	_last_alarm = level
	_refresh_alarm_bar(level)

func _on_xp(xp_in: int, xp_to_next: int, _total: int) -> void:
	if _xp_fill:
		var frac := clampf(float(xp_in)/maxf(float(xp_to_next),1.0), 0.0, 1.0)
		_xp_fill.size.x = (238-20) * frac
	if _xp_lbl: _xp_lbl.text = "%d / %d" % [xp_in, xp_to_next]

func _on_level_up(new_level: int) -> void:
	if _lvl_badge: _lvl_badge.text = "NIV. %d" % new_level
	_refresh_skill_locks(); _show_level_notif(new_level)

func _on_passive_gained(name: String) -> void:
	if not _passive_rows.has(name): return
	var row : Dictionary = _passive_rows[name]
	(row["bg"] as ColorRect).visible = true; (row["timer"] as Label).visible = true

func _on_passive_lost(name: String) -> void:
	if not _passive_rows.has(name): return
	var row : Dictionary = _passive_rows[name]
	(row["bg"] as ColorRect).visible = false; (row["timer"] as Label).visible = false

func _on_cooldown_updated(sid: String, remaining: float, total: float) -> void:
	if not _slots.has(sid): return
	var slot : Dictionary = _slots[sid]
	var overlay : ColorRect = slot["overlay"] as ColorRect
	var cd_lbl  : Label     = slot["cd_l"] as Label
	var accent  : ColorRect = slot["accent"] as ColorRect
	var frac    := clampf(remaining / maxf(total, 0.001), 0.0, 1.0)
	overlay.size.y = 100.0 * frac
	if remaining <= 0.05:
		cd_lbl.text = "LISTO"; cd_lbl.add_theme_color_override("font_color", Color(0.2,1.0,0.4))
		var tw := create_tween()
		tw.tween_property(accent, "color", SKILL_COLS[SKILL_IDS.find(sid)] as Color, 0.08)
		tw.tween_property(accent, "color", (SKILL_COLS[SKILL_IDS.find(sid)] as Color) * 0.5, 0.5)
	else:
		cd_lbl.text = "%.1fs" % remaining
		cd_lbl.add_theme_color_override("font_color", Color(1.0,0.55,0.15))

func _process(delta: float) -> void:
	if _ability_sys == null: return
	_passive_tick -= delta
	if _passive_tick > 0.0: return
	_passive_tick = 0.5
	for name in ALL_PASSIVES:
		if not _passive_rows.has(name): continue
		var row : Dictionary = _passive_rows[name]
		if not (row["timer"] as Label).visible: continue
		var rem := _ability_sys.get_remaining(name) if _has_ability_sys_method else -1.0
		var timer_lbl : Label = row["timer"] as Label
		if rem < 0.0: timer_lbl.text = "● " + name + "  ∞"
		elif rem > 0.0: timer_lbl.text = "● " + name + "  %ds" % int(rem + 0.9)
		else: _on_passive_lost(name)

func _refresh_skill_locks() -> void:
	for i in SKILL_IDS.size():
		var sid : String = SKILL_IDS[i] as String
		if not _slots.has(sid): continue
		var slot : Dictionary = _slots[sid]
		var unlocked := ProgressionMgr.is_skill_unlocked(sid)
		(slot["name_l"] as Label).visible = unlocked
		(slot["key_l"]  as Label).visible = unlocked
		(slot["cd_l"]   as Label).visible = unlocked
		(slot["lock_l"] as Label).visible = not unlocked
		(slot["overlay"] as ColorRect).visible = unlocked
		(slot["bg"] as ColorRect).color = BG_PANEL if unlocked else Color(0.02,0.02,0.03,0.9)
		(slot["accent"] as ColorRect).color = SKILL_COLS[i] as Color if unlocked else COL_MUTED * 0.3

func _show_level_notif(level: int) -> void:
	var lbl := _lbl(_root, Vector2(760,430), Vector2(400,72), "¡ NIVEL %d !", 58, COL_XP, HORIZONTAL_ALIGNMENT_CENTER)
	var sub_text := ""
	if level == Constants.SKILL_DASH_UNLOCK:   sub_text = "▸ DASH desbloqueado"
	elif level == Constants.SKILL_PULSE_UNLOCK: sub_text = "▸ PULSO desbloqueado"
	elif level == Constants.SKILL_CAMO_UNLOCK:  sub_text = "▸ CAMUFLAJE desbloqueado"
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", 340.0, 1.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.8).set_delay(0.7)
	tw.tween_callback(lbl.queue_free)
	if sub_text != "":
		var sub := _lbl(_root, Vector2(760,506), Vector2(400,28), sub_text, 20, Color(0.4,1.0,0.5), HORIZONTAL_ALIGNMENT_CENTER)
		var tw2 := create_tween()
		tw2.tween_property(sub, "position:y", 486.0, 2.0).set_trans(Tween.TRANS_EXPO)
		tw2.parallel().tween_property(sub, "modulate:a", 0.0, 2.0).set_delay(0.9)
		tw2.tween_callback(sub.queue_free)

func _rect(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col; r.position = pos; r.size = sz; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r); return r

func _lbl(parent: Control, pos: Vector2, sz: Vector2, txt: String, fs: int, col: Color, ha: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos; l.size = sz; l.text = txt; l.horizontal_alignment = ha
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l); return l
