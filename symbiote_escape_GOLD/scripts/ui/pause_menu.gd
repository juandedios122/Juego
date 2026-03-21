extends CanvasLayer
## PauseMenu v9 — pausa rediseñada con diseño de panel modal claro.

const COL_BG    := Color(0.0, 0.0, 0.0, 0.78)
const COL_PANEL := Color(0.05, 0.07, 0.11, 0.98)
const COL_TEXT  := Color(0.82, 0.87, 0.92, 1.0)
const COL_MUTED := Color(0.38, 0.42, 0.50, 1.0)
const COL_GREEN := Color(0.18, 0.92, 0.44, 1.0)
const PW        := 440
const PH        := 420
const PX        := (1920 - PW) / 2
const PY        := (1080 - PH) / 2

var _open : bool  = false
var _root : Control

func _ready() -> void:
	layer         = 20
	visible       = false
	process_mode  = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# Overlay oscuro
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), COL_BG)
	# Panel principal
	_cr(_root, Vector2(PX, PY), Vector2(PW, PH), COL_PANEL)
	# Borde superior de acento
	_cr(_root, Vector2(PX, PY), Vector2(PW, 3), COL_GREEN)
	# Borde inferior
	_cr(_root, Vector2(PX, PY + PH - 1), Vector2(PW, 1), Color(0.1, 0.2, 0.12, 0.6))
	# Título
	_lbl(_root, Vector2(PX, PY + 22), Vector2(PW, 44),
		"PAUSA", 36, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	# Separador
	_cr(_root, Vector2(PX + 32, PY + 76), Vector2(PW - 64, 1), Color(0.12, 0.18, 0.22, 1.0))
	# Stat rápido: absorciones
	_lbl(_root, Vector2(PX + 32, PY + 86), Vector2(PW - 64, 22),
		"Absorciones esta sesión: %d" % GM.absorption_count,
		14, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	# Botones
	_build_btn("CONTINUAR",      PY + 130, Color(0.07, 0.18, 0.10, 1.0), COL_GREEN, func(): toggle())
	_build_btn("OPCIONES",       PY + 210, Color(0.06, 0.09, 0.18, 1.0), Color(0.55, 0.75, 1.0), _open_options)
	_build_btn("MENÚ PRINCIPAL", PY + 290, Color(0.12, 0.08, 0.04, 1.0), Color(0.9, 0.65, 0.3),
		func(): get_tree().paused = false; GM.go_to_menu())
	_build_btn("SALIR",          PY + 370, Color(0.18, 0.05, 0.05, 1.0), Color(1.0, 0.38, 0.3),
		func(): GM.quit_game())

func _build_btn(txt: String, y: int, bg: Color, fg: Color, cb: Callable) -> void:
	var BX := PX + 32
	var BW := PW - 64
	var BH := 52
	var bg_r := _cr(_root, Vector2(BX, y), Vector2(BW, BH), bg)
	_cr(_root, Vector2(BX, y), Vector2(3, BH), fg * 0.8)
	var btn := Button.new()
	btn.text     = txt
	btn.position = Vector2(BX, y)
	btn.size     = Vector2(BW, BH)
	btn.flat     = true
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): bg_r.color = bg.lightened(0.18))
	btn.mouse_exited.connect(func():  bg_r.color = bg)
	_root.add_child(btn)

func _open_options() -> void:
	var scr := load("res://scripts/ui/options_menu.gd")
	if scr:
		var om := CanvasLayer.new()
		om.set_script(scr)
		om.layer = layer + 1
		add_child(om)

func toggle() -> void:
	_open = not _open
	visible = _open
	get_tree().paused = _open
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if _open else Input.MOUSE_MODE_CAPTURED
	)

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
