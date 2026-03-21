extends CanvasLayer
## VictoryScreen v9 — pantalla de victoria con estadísticas completas y celebración.

const COL_BG    := Color(0.01, 0.04, 0.02, 1.0)
const COL_GREEN := Color(0.18, 0.92, 0.44, 1.0)
const COL_GOLD  := Color(1.00, 0.82, 0.22, 1.0)
const COL_TEXT  := Color(0.82, 0.87, 0.92, 1.0)
const COL_MUTED := Color(0.40, 0.48, 0.42, 1.0)

var _root      : Control
var _elapsed   : float = 0.0
var _particles : Array = []
var _title_lbl : Label
var _is_record : bool = false

func _ready() -> void:
	layer = 50
	_is_record = GM.absorption_count >= GM.high_score and GM.absorption_count > 0
	_build()
	_animate_entrance()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Fondo verde muy oscuro
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), COL_BG)
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), Color(0.05, 0.18, 0.08, 0.25))
	# Líneas de brillo
	for i in 18:
		_cr(_root, Vector2(0, i * 60), Vector2(1920, 1), Color(0.0, 0.3, 0.1, 0.12))
	# Partículas (confeti verde/dorado ascendente)
	for i in 80:
		var col_choice := COL_GREEN if randf() > 0.35 else COL_GOLD
		var sz := randf_range(2.5, 6.0)
		var r  := ColorRect.new()
		r.size     = Vector2(sz, sz * randf_range(0.5, 2.5))
		r.color    = Color(col_choice.r, col_choice.g, col_choice.b, randf_range(0.1, 0.55))
		r.position = Vector2(randf_range(0, 1920), randf_range(-60, 1080))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("speed",  randf_range(25.0, 80.0))
		r.set_meta("drift",  randf_range(-20.0, 20.0))
		_root.add_child(r)
		_particles.append(r)

	# Panel de stats (izquierda-centro)
	var SPX := 240; var SPY := 200; var SPW := 720; var SPH := 580
	_cr(_root, Vector2(SPX, SPY), Vector2(SPW, SPH), Color(0.04, 0.07, 0.05, 0.94))
	_cr(_root, Vector2(SPX, SPY), Vector2(SPW, 3), COL_GREEN)
	_cr(_root, Vector2(SPX, SPY + SPH), Vector2(SPW, 1), Color(0.1, 0.25, 0.12, 0.5))

	# Título (fuera del panel, grande)
	_title_lbl = _lbl(_root, Vector2(240, 100), Vector2(720, 90),
		"ESCAPASTE", 72, COL_GREEN, HORIZONTAL_ALIGNMENT_CENTER)

	# Subtítulo del panel
	_lbl(_root, Vector2(SPX, SPY + 20), Vector2(SPW, 36),
		"El simbionte ha conseguido huir", 18, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	# Badge de récord (solo si es nuevo récord)
	if _is_record:
		_cr(_root, Vector2(SPX + SPW/2 - 100, SPY + 55), Vector2(200, 30),
			Color(0.5, 0.35, 0.0, 0.9))
		_lbl(_root, Vector2(SPX + SPW/2 - 100, SPY + 58), Vector2(200, 26),
			"★  NUEVO RÉCORD  ★", 14, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# Separador
	_cr(_root, Vector2(SPX + 40, SPY + 96), Vector2(SPW - 80, 1), Color(0.1, 0.22, 0.12, 1.0))

	# Estadísticas
	var abs_count := GM.absorption_count
	var stats := [
		["Absorciones",      str(abs_count),                             COL_GREEN],
		["Nivel alcanzado",  "Niv. %d" % ProgressionMgr.current_level,  COL_TEXT],
		["XP total",         str(ProgressionMgr.get_xp_to_next()) + "+", COL_TEXT],
		["Récord anterior",  "%d absorciones" % GM.high_score,           COL_GOLD if _is_record else COL_MUTED],
	]
	for i in stats.size():
		var sy : float = float(SPY + 116 + i * 72)
		# Fondo alternado leve
		if i % 2 == 0:
			_cr(_root, Vector2(SPX + 2, sy - 4), Vector2(SPW - 4, 62),
				Color(0.06, 0.10, 0.07, 0.6))
		_lbl(_root, Vector2(SPX + 40, sy + 6), Vector2(SPW * 0.55, 32),
			stats[i][0] as String, 16, COL_MUTED)
		_lbl(_root, Vector2(SPX + 40, sy + 6), Vector2(SPW - 80, 32),
			stats[i][1] as String, 22, stats[i][2] as Color, HORIZONTAL_ALIGNMENT_RIGHT)
		if i < stats.size() - 1:
			_cr(_root, Vector2(SPX + 40, sy + 52), Vector2(SPW - 80, 1),
				Color(0.08, 0.14, 0.08, 1.0))

	# Botones
	var by : int = SPY + 480
	_btn("JUGAR DE NUEVO",  SPX + 40, by, (SPW - 88) / 2,
		Color(0.06, 0.20, 0.10, 1.0), COL_GREEN, GM.go_to_cinematic)
	_btn("MENÚ PRINCIPAL",  SPX + 48 + (SPW - 88) / 2, by, (SPW - 88) / 2,
		Color(0.05, 0.08, 0.18, 1.0), Color(0.55, 0.75, 1.0), GM.go_to_menu)

	# Panel derecho decorativo (logros / consejos)
	var LP := 1020; var LY := 200; var LW := 660; var LH := 580
	_cr(_root, Vector2(LP, LY), Vector2(LW, LH), Color(0.03, 0.05, 0.04, 0.85))
	_cr(_root, Vector2(LP, LY), Vector2(LW, 3), COL_GOLD * 0.6)
	_lbl(_root, Vector2(LP, LY + 20), Vector2(LW, 28),
		"CONSEJOS DE SIGILO", 15, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_cr(_root, Vector2(LP + 32, LY + 56), Vector2(LW - 64, 1), Color(0.15, 0.12, 0.04, 1.0))
	var tips : Array[String] = [
		"Los trabajadores huyen al escuchar la alarma.",
		"Las ventilaciones permiten bypasear zonas vigiladas.",
		"Absorber guardias activa la alerta más rápido.",
		"El PULSO aturde enemigos en radio de 7 metros.",
		"El CAMUFLAJE bloquea la detección por cono visual.",
		"Las puertas bloqueadas se abren con absorciones.",
		"El núcleo reactor causa daño de radiación continuo.",
		"Los orbes dorados dan el doble de XP.",
	]
	for i in tips.size():
		_lbl(_root, Vector2(LP + 32, LY + 72 + i * 56), Vector2(LW - 64, 18),
			"▸  " + tips[i], 13, COL_TEXT if i % 2 == 0 else COL_MUTED)

func _btn(txt: String, x: float, y: float, w: float, bg: Color, fg: Color, cb: Callable) -> void:
	var BH := 56
	var bg_r := _cr(_root, Vector2(x, y), Vector2(w, BH), bg)
	_cr(_root, Vector2(x, y), Vector2(3, BH), fg * 0.9)
	var btn := Button.new()
	btn.text     = txt
	btn.position = Vector2(x, y)
	btn.size     = Vector2(w, BH)
	btn.flat     = true
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): bg_r.color = bg.lightened(0.15))
	btn.mouse_exited.connect(func():  bg_r.color = bg)
	_root.add_child(btn)

func _animate_entrance() -> void:
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 1.4).set_ease(Tween.EASE_OUT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	_elapsed += delta
	# Pulso del título
	if _title_lbl and is_instance_valid(_title_lbl):
		var p := 1.0 + sin(_elapsed * 2.0) * 0.022
		_title_lbl.scale = Vector2(p, p)
		_title_lbl.pivot_offset = _title_lbl.size * 0.5
	# Partículas ascendentes
	for r in _particles:
		if not is_instance_valid(r): continue
		var sp   : float = r.get_meta("speed", 40.0)
		var drift: float = r.get_meta("drift", 0.0)
		r.position.y -= sp * delta
		r.position.x += drift * delta
		if r.position.y < -10.0:
			r.position.y = 1090.0
			r.position.x = randf_range(0, 1920)

func _cr(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col; r.position = pos; r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r); return r

func _lbl(parent: Control, pos: Vector2, sz: Vector2, txt: String,
		fs: int, col: Color, ha: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos; l.size = sz; l.text = txt
	l.horizontal_alignment = ha
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l); return l
