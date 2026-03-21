extends CanvasLayer
## OptionsMenu v9 — opciones con secciones organizadas y controles mejorados.

const PW := 560
const PH := 520
const PX := (1920 - PW) / 2
const PY := (1080 - PH) / 2
const COL_PANEL := Color(0.04, 0.06, 0.10, 0.98)
const COL_GREEN := Color(0.18, 0.92, 0.44, 1.0)
const COL_TEXT  := Color(0.82, 0.87, 0.92, 1.0)
const COL_MUTED := Color(0.38, 0.42, 0.50, 1.0)

var _root : Control

func _ready() -> void:
	layer = 30
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# Overlay
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), Color(0, 0, 0, 0.82))
	# Panel
	_cr(_root, Vector2(PX, PY), Vector2(PW, PH), COL_PANEL)
	_cr(_root, Vector2(PX, PY), Vector2(PW, 3), COL_GREEN)
	_cr(_root, Vector2(PX, PY + PH - 1), Vector2(PW, 1), Color(0.1, 0.15, 0.1, 0.5))
	# Título
	_lbl(_root, Vector2(PX, PY + 18), Vector2(PW, 38), "OPCIONES",
		30, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_cr(_root, Vector2(PX + 28, PY + 64), Vector2(PW - 56, 1), Color(0.10, 0.14, 0.18, 1.0))

	# ── AUDIO ─────────────────────────────────────────────
	_section_header("AUDIO", PY + 78)
	_slider_row("Volumen maestro", PY + 110, 0.0, 1.0, 0.05,
		SaveMgr.get_master_vol(), func(v: float): SaveMgr.set_master_vol(v))

	# ── CONTROLES ─────────────────────────────────────────
	_section_header("CONTROLES", PY + 172)
	_slider_row("Sensibilidad ratón", PY + 204, 0.001, 0.008, 0.0005,
		SaveMgr.get_mouse_sens(), func(v: float): SaveMgr.set_mouse_sens(v))

	# ── JUEGO ─────────────────────────────────────────────
	_section_header("PARTIDA", PY + 266)
	_toggle_row("Invertir eje Y", PY + 298,
		SaveMgr.get_val("invert_y", false),
		func(v: bool): SaveMgr.set_val("invert_y", v))

	# ── Referencia de controles ───────────────────────────
	_cr(_root, Vector2(PX + 28, PY + 352), Vector2(PW - 56, 1), Color(0.10, 0.14, 0.18, 1.0))
	_lbl(_root, Vector2(PX + 28, PY + 360), Vector2(PW - 56, 18),
		"CONTROLES DEL JUEGO", 11, COL_MUTED)
	var ctrl_lines := [
		"WASD — Mover          Shift — Sprint",
		"Ratón — Cámara        E — Absorber",
		"Q — Dash              R — Pulso",
		"F — Camuflaje         ESC — Pausa",
	]
	for i in ctrl_lines.size():
		_lbl(_root, Vector2(PX + 28, PY + 380 + i * 20), Vector2(PW - 56, 18),
			ctrl_lines[i], 12, Color(0.50, 0.55, 0.62))

	# ── Botón cerrar ──────────────────────────────────────
	_cr(_root, Vector2(PX + 28, PY + PH - 68), Vector2(PW - 56, 1), Color(0.08, 0.12, 0.10, 0.8))
	var close_bg := _cr(_root, Vector2(PX + 28, PY + PH - 58), Vector2(PW - 56, 46),
		Color(0.08, 0.18, 0.10, 1.0))
	var close := Button.new()
	close.text     = "CERRAR"
	close.position = Vector2(PX + 28, PY + PH - 58)
	close.size     = Vector2(PW - 56, 46)
	close.flat     = true
	close.add_theme_color_override("font_color", COL_GREEN)
	close.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func(): SaveMgr.flush(); queue_free())
	close.mouse_entered.connect(func(): close_bg.color = Color(0.10, 0.26, 0.14, 1.0))
	close.mouse_exited.connect(func():  close_bg.color = Color(0.08, 0.18, 0.10, 1.0))
	_root.add_child(close)

func _section_header(txt: String, y: int) -> void:
	_cr(_root, Vector2(PX + 28, y + 12), Vector2(6, 16), COL_GREEN * 0.8)
	_lbl(_root, Vector2(PX + 42, y + 10), Vector2(PW - 70, 20), txt, 12, COL_GREEN)

func _slider_row(label: String, y: int, min_v: float, max_v: float, step: float,
		init_val: float, on_change: Callable) -> void:
	_lbl(_root, Vector2(PX + 28, y), Vector2(PW - 56, 20), label, 13, COL_TEXT)
	var slider := HSlider.new()
	slider.position  = Vector2(PX + 28, y + 24)
	slider.size      = Vector2(PW - 56, 28)
	slider.min_value = min_v; slider.max_value = max_v; slider.step = step
	slider.value     = init_val
	slider.value_changed.connect(on_change)
	_root.add_child(slider)

func _toggle_row(label: String, y: int, init_val: bool, on_change: Callable) -> void:
	_lbl(_root, Vector2(PX + 28, y + 6), Vector2(PW - 130, 24), label, 13, COL_TEXT)
	# Toggle button (simulated)
	var state    := [init_val]
	var tog_bg   := _cr(_root, Vector2(PX + PW - 100, y + 6), Vector2(72, 28),
		Color(0.08, 0.22, 0.10, 1.0) if init_val else Color(0.12, 0.12, 0.15, 1.0))
	var tog_lbl  := _lbl(_root, Vector2(PX + PW - 100, y + 6), Vector2(72, 28),
		"SÍ" if init_val else "NO", 13,
		COL_GREEN if init_val else COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var tog := Button.new()
	tog.position = Vector2(PX + PW - 100, y + 6)
	tog.size     = Vector2(72, 28)
	tog.flat     = true
	tog.pressed.connect(func():
		state[0] = not state[0]
		tog_lbl.text = "SÍ" if state[0] else "NO"
		tog_lbl.add_theme_color_override("font_color", COL_GREEN if state[0] else COL_MUTED)
		tog_bg.color = Color(0.08, 0.22, 0.10, 1.0) if state[0] else Color(0.12, 0.12, 0.15, 1.0)
		on_change.call(state[0])
	)
	_root.add_child(tog)

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
