extends CanvasLayer
## GameOverScreen v9 — pantalla de derrota con estadísticas y animación de entrada.

const COL_BG    := Color(0.02, 0.01, 0.01, 1.0)
const COL_RED   := Color(1.00, 0.18, 0.08, 1.0)
const COL_TEXT  := Color(0.82, 0.87, 0.92, 1.0)
const COL_MUTED := Color(0.42, 0.36, 0.34, 1.0)

var _root    : Control
var _elapsed : float = 0.0
var _particles : Array = []

func _ready() -> void:
	layer = 50
	_build()
	_animate_entrance()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Fondo rojo oscuro
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), COL_BG)
	# Overlay cromático rojo
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), Color(0.28, 0.0, 0.0, 0.45))
	# Líneas de scanline (atmosférico)
	for i in 27:
		_cr(_root, Vector2(0, i * 40), Vector2(1920, 1), Color(0.0, 0.0, 0.0, 0.2))
	# Partículas descendentes (cenizas)
	for i in 40:
		var sz := randf_range(2.0, 5.0)
		var r  := ColorRect.new()
		r.size     = Vector2(sz, sz)
		r.color    = Color(0.8, 0.2, 0.1, randf_range(0.08, 0.35))
		r.position = Vector2(randf_range(0, 1920), randf_range(-200, 1080))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("speed", randf_range(20.0, 60.0))
		_root.add_child(r)
		_particles.append(r)

	# Panel central de stats
	var SPX := 560; var SPY := 280; var SPW := 800; var SPH := 420
	_cr(_root, Vector2(SPX, SPY), Vector2(SPW, SPH), Color(0.06, 0.02, 0.02, 0.92))
	_cr(_root, Vector2(SPX, SPY), Vector2(SPW, 3), COL_RED)
	_cr(_root, Vector2(SPX, SPY + SPH), Vector2(SPW, 1), Color(0.3, 0.05, 0.02, 0.5))

	# Título
	_lbl(_root, Vector2(SPX, SPY + 28), Vector2(SPW, 56),
		"HAS SIDO CAPTURADO", 42, COL_RED, HORIZONTAL_ALIGNMENT_CENTER)
	# Subtítulo
	_lbl(_root, Vector2(SPX, SPY + 86), Vector2(SPW, 30),
		"El simbionte no pudo escapar de la planta", 18, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	# Separador
	_cr(_root, Vector2(SPX + 48, SPY + 128), Vector2(SPW - 96, 1), Color(0.18, 0.06, 0.04, 1.0))

	# Stats
	var abs_count := GM.absorption_count
	var stats := [
		["Absorciones realizadas", str(abs_count)],
		["Nivel alcanzado", "Niv. %d" % ProgressionMgr.current_level],
		["Récord personal", "%d absorciones" % GM.high_score],
	]
	for i in stats.size():
		var sy := SPY + 148 + i * 52
		_lbl(_root, Vector2(SPX + 48, sy), Vector2(SPW * 0.55, 28),
			stats[i][0], 16, COL_MUTED)
		_lbl(_root, Vector2(SPX + 48, sy), Vector2(SPW - 96, 28),
			stats[i][1], 18, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		if i < stats.size() - 1:
			_cr(_root, Vector2(SPX + 48, sy + 36), Vector2(SPW - 96, 1),
				Color(0.12, 0.04, 0.03, 1.0))

	# Botones
	_btn("INTENTAR DE NUEVO", SPX + 48, SPY + 330,
		(SPW - 96) / 2 - 6, Color(0.08, 0.18, 0.08, 1.0), Color(0.2, 1.0, 0.4), GM.go_to_cinematic)
	_btn("MENÚ PRINCIPAL", SPX + 48 + (SPW - 96) / 2 + 6, SPY + 330,
		(SPW - 96) / 2 - 6, Color(0.18, 0.06, 0.04, 1.0), COL_RED, GM.go_to_menu)

func _btn(txt: String, x: float, y: float, w: float, bg: Color, fg: Color, cb: Callable) -> void:
	var BH := 54
	var bg_r := _cr(_root, Vector2(x, y), Vector2(w, BH), bg)
	_cr(_root, Vector2(x, y), Vector2(3, BH), fg * 0.8)
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
	# Fade in desde negro total
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	_elapsed += delta
	for r in _particles:
		if not is_instance_valid(r): continue
		var sp: float = r.get_meta("speed", 35.0)
		r.position.y += sp * delta
		if r.position.y > 1090.0:
			r.position.y = -8.0
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
