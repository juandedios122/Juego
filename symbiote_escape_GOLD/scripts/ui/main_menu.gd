extends CanvasLayer
## MainMenu v9 — menú principal rediseñado con diseño atmosférico.

const COL_BG     := Color(0.02, 0.03, 0.05, 1.0)
const COL_PANEL  := Color(0.05, 0.07, 0.11, 1.0)
const COL_GREEN  := Color(0.18, 0.92, 0.44, 1.0)
const COL_MUTED  := Color(0.35, 0.40, 0.48, 1.0)
const COL_TEXT   := Color(0.82, 0.87, 0.92, 1.0)

var _particles : Array = []
var _elapsed   : float = 0.0
var _title_lbl : Label
var _root      : Control

func _ready() -> void:
	layer = 10
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_background()
	_build_left_panel()
	_build_title_section()
	_build_buttons()
	_build_footer()

func _build_background() -> void:
	# Fondo base muy oscuro
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), COL_BG)
	# Gradiente simulado — panel oscuro derecho
	_cr(_root, Vector2(1200, 0), Vector2(720, 1080), Color(0.015, 0.018, 0.028, 1.0))
	# Grid decorativo (líneas horizontales sutiles)
	for i in 12:
		_cr(_root, Vector2(0, 90 * i), Vector2(1920, 1), Color(0.08, 0.10, 0.14, 0.5))
	# Partículas flotantes
	for i in 70:
		var sz := randf_range(1.5, 4.5)
		var r  := ColorRect.new()
		r.size    = Vector2(sz, sz)
		r.color   = Color(0.1, 0.9, 0.4, randf_range(0.06, 0.4))
		r.position = Vector2(randf_range(0, 1920), randf_range(0, 1080))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("speed", randf_range(10.0, 35.0))
		r.set_meta("drift", randf_range(-8.0, 8.0))
		_root.add_child(r)
		_particles.append(r)

func _build_left_panel() -> void:
	# Panel izquierdo con decoración
	_cr(_root, Vector2(0, 0), Vector2(640, 1080), Color(0.03, 0.04, 0.07, 0.6))
	_cr(_root, Vector2(638, 0), Vector2(2, 1080), Color(0.10, 0.22, 0.12, 0.6))
	# Decoración nuclear
	_cr(_root, Vector2(220, 300), Vector2(200, 2), Color(0.18, 0.92, 0.44, 0.15))
	_cr(_root, Vector2(220, 450), Vector2(200, 2), Color(0.18, 0.92, 0.44, 0.08))
	# Texto decorativo lateral
	var side_lbl := Label.new()
	side_lbl.text = "PLANTA NUCLEAR · SECTOR 7 · ACCESO RESTRINGIDO"
	side_lbl.position = Vector2(-280, 540)
	side_lbl.size     = Vector2(600, 24)
	side_lbl.rotation = -PI / 2.0
	side_lbl.add_theme_font_size_override("font_size", 12)
	side_lbl.add_theme_color_override("font_color", Color(0.18, 0.92, 0.44, 0.2))
	_root.add_child(side_lbl)
	# Record
	var rec := _label(_root, Vector2(50, 860), Vector2(540, 26),
		"MEJOR RESULTADO: %d absorciones" % GM.high_score, 16, Color(0.5, 0.8, 0.55))
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_title_section() -> void:
	# "SYMBIOTE" grande
	_title_lbl = _label(_root, Vector2(620, 180), Vector2(1280, 140),
		"SYMBIOTE", 96, COL_GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	# "ESCAPE" en texto más pequeño y diferente estilo
	var escape_lbl := _label(_root, Vector2(620, 306), Vector2(1280, 60),
		"E S C A P E", 42, Color(0.65, 0.82, 0.67), HORIZONTAL_ALIGNMENT_CENTER)
	# Línea separadora
	_cr(_root, Vector2(760, 380), Vector2(800, 1), Color(0.18, 0.92, 0.44, 0.3))
	# Subtítulo
	_label(_root, Vector2(620, 396), Vector2(1280, 32),
		"Infiltra · Absorbe · Escapa", 20, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _build_buttons() -> void:
	var btn_defs := [
		["INICIAR JUEGO",  Color(0.08, 0.50, 0.22, 1.0), COL_GREEN,             GM.go_to_cinematic],
		["OPCIONES",       Color(0.06, 0.10, 0.22, 1.0), Color(0.55, 0.75, 1.0), _open_options],
		["SALIR",          Color(0.18, 0.06, 0.06, 1.0), Color(1.0, 0.4, 0.35),  GM.quit_game],
	]
	for i in btn_defs.size():
		var def  := btn_defs[i]
		var by   := 480 + i * 88
		_build_btn(def[0] as String, by, def[1] as Color, def[2] as Color, def[3] as Callable)

func _build_btn(txt: String, y: int, bg: Color, fg: Color, cb: Callable) -> void:
	var BX := 760; var BW := 400; var BH := 60
	# Sombra
	_cr(_root, Vector2(BX+3, y+3), Vector2(BW, BH), Color(0, 0, 0, 0.4))
	# Fondo del botón
	var bg_rect := _cr(_root, Vector2(BX, y), Vector2(BW, BH), bg)
	# Borde izquierdo de acento
	_cr(_root, Vector2(BX, y), Vector2(3, BH), fg * 0.8)
	# Texto
	var btn := Button.new()
	btn.text     = txt
	btn.position = Vector2(BX, y)
	btn.size     = Vector2(BW, BH)
	btn.flat     = true
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", fg * 0.7)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): bg_rect.color = bg.lightened(0.15))
	btn.mouse_exited.connect(func():  bg_rect.color = bg)
	_root.add_child(btn)

func _build_footer() -> void:
	_cr(_root, Vector2(0, 1064), Vector2(1920, 1), Color(0.1, 0.2, 0.12, 0.5))
	_label(_root, Vector2(0, 1058), Vector2(1920, 20),
		"Symbiote Escape  ·  v9.0  ·  Godot 4.6",
		12, Color(0.25, 0.28, 0.32), HORIZONTAL_ALIGNMENT_CENTER)

func _open_options() -> void:
	var scr := load("res://scripts/ui/options_menu.gd")
	if scr:
		var om := CanvasLayer.new()
		om.set_script(scr)
		om.layer = layer + 2
		add_child(om)

func _process(delta: float) -> void:
	_elapsed += delta
	# Pulso del título
	if _title_lbl:
		var p := 1.0 + sin(_elapsed * 1.4) * 0.018
		_title_lbl.scale = Vector2(p, p)
		_title_lbl.pivot_offset = _title_lbl.size * 0.5
	# Partículas
	for r in _particles:
		if not is_instance_valid(r): continue
		var sp   : float = r.get_meta("speed", 18.0)
		var drift: float = r.get_meta("drift", 0.0)
		r.position.y -= sp * delta
		r.position.x += drift * delta * 0.3
		if r.position.y < -6.0:
			r.position.y = 1086.0
			r.position.x = randf_range(0, 1920)

# ── Helpers ────────────────────────────────────────────────
func _cr(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col; r.position = pos; r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _label(parent: Control, pos: Vector2, sz: Vector2, txt: String,
		fs: int, col: Color, ha: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos; l.size = sz; l.text = txt
	l.horizontal_alignment = ha
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
