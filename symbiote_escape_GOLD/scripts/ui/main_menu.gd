extends CanvasLayer
## MainMenu — con selección de 3 slots de guardado.

const COL_BG    := Color(0.02, 0.03, 0.05, 1.0)
const COL_GREEN := Color(0.18, 0.92, 0.44, 1.0)
const COL_MUTED := Color(0.35, 0.40, 0.48, 1.0)
const COL_TEXT  := Color(0.82, 0.87, 0.92, 1.0)

var _particles  : Array  = []
var _elapsed    : float  = 0.0
var _title_lbl  : Label  = null
var _root       : Control = null
var _slot_panel : Control = null   # panel de selección de slots
var _main_panel : Control = null   # panel principal

func _ready() -> void:
	layer = 10
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_background()
	_build_title_section()
	_main_panel = _build_main_panel()
	_root.add_child(_main_panel)
	_slot_panel = _build_slot_panel()
	_root.add_child(_slot_panel)
	_slot_panel.visible = false
	_build_footer()

func _build_background() -> void:
	_cr(_root, Vector2.ZERO, Vector2(1920, 1080), COL_BG)
	_cr(_root, Vector2(1200, 0), Vector2(720, 1080), Color(0.015, 0.018, 0.028, 1.0))
	for i in 12:
		_cr(_root, Vector2(0, 90 * i), Vector2(1920, 1), Color(0.08, 0.10, 0.14, 0.5))
	for i in 70:
		var sz := randf_range(1.5, 4.5)
		var r  := ColorRect.new()
		r.size    = Vector2(sz, sz)
		r.color   = Color(0.1, 0.9, 0.4, randf_range(0.06, 0.4))
		r.position = Vector2(randf_range(0, 1920), randf_range(0, 1080))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("speed",  randf_range(10.0, 35.0))
		r.set_meta("drift",  randf_range(-8.0, 8.0))
		_root.add_child(r)
		_particles.append(r)
	# Decoración lateral
	_cr(_root, Vector2(0, 0), Vector2(640, 1080), Color(0.03, 0.04, 0.07, 0.6))
	_cr(_root, Vector2(638, 0), Vector2(2, 1080), Color(0.10, 0.22, 0.12, 0.6))
	var side := Label.new()
	side.text = "PLANTA NUCLEAR · SECTOR 7 · ACCESO RESTRINGIDO"
	side.position = Vector2(-280, 540); side.size = Vector2(600, 24)
	side.rotation = -PI / 2.0
	side.add_theme_font_size_override("font_size", 12)
	side.add_theme_color_override("font_color", Color(0.18, 0.92, 0.44, 0.2))
	_root.add_child(side)

func _build_title_section() -> void:
	_title_lbl = _lbl(_root, Vector2(620, 140), Vector2(1280, 140),
		"SYMBIOTE", 96, COL_GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl(_root, Vector2(620, 278), Vector2(1280, 60),
		"E S C A P E", 42, Color(0.65, 0.82, 0.67), HORIZONTAL_ALIGNMENT_CENTER)
	_cr(_root, Vector2(760, 348), Vector2(800, 1), Color(0.18, 0.92, 0.44, 0.3))
	_lbl(_root, Vector2(620, 362), Vector2(1280, 32),
		"Infiltra · Absorbe · Escapa", 20, COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _build_main_panel() -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var btn_defs := [
		["NUEVA / CONTINUAR",  Color(0.08, 0.50, 0.22, 1.0), COL_GREEN,              _show_slots],
		["OPCIONES",           Color(0.06, 0.10, 0.22, 1.0), Color(0.55, 0.75, 1.0), _open_options],
		["SALIR",              Color(0.18, 0.06, 0.06, 1.0), Color(1.0, 0.4, 0.35),  GM.quit_game],
	]
	for i in btn_defs.size():
		var def: Array = btn_defs[i]
		_build_btn(panel, def[0] as String, 430 + i * 88,
			def[1] as Color, def[2] as Color, def[3] as Callable)
	# Mejor puntuación global
	var best := 0
	for slot_idx in 3:
		var summary := SaveMgr.get_slot_summary(slot_idx)
		best = maxi(best, int(summary["absorptions"]))
	_lbl(panel, Vector2(50, 860), Vector2(540, 26),
		"MEJOR RESULTADO: %d absorciones" % best, 16,
		Color(0.5, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	return panel

func _build_slot_panel() -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Fondo semitransparente
	_cr(panel, Vector2(580, 400), Vector2(760, 380), Color(0.03, 0.05, 0.08, 0.96))
	_cr(panel, Vector2(580, 400), Vector2(760, 2), COL_GREEN * 0.6)
	_lbl(panel, Vector2(580, 412), Vector2(760, 36),
		"SELECCIONAR PARTIDA", 22, COL_GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	# 3 slots
	for i in 3:
		_build_slot_card(panel, i, 460 + i * 96)
	# Botón volver
	_build_btn(panel, "← VOLVER", 780, Color(0.08, 0.08, 0.12, 1.0), COL_MUTED, _hide_slots)
	return panel

func _build_slot_card(parent: Control, slot: int, y: int) -> void:
	var summary := SaveMgr.get_slot_summary(slot)
	var exists  : bool = summary["exists"] as bool
	var BX := 600; var BW := 720; var BH := 72
	var bg_col := Color(0.06, 0.10, 0.08, 1.0) if exists else Color(0.04, 0.04, 0.06, 1.0)
	var bg := _cr(parent, Vector2(BX, y), Vector2(BW, BH), bg_col)
	_cr(parent, Vector2(BX, y), Vector2(3, BH), COL_GREEN if exists else COL_MUTED)
	# Número de slot
	_lbl(parent, Vector2(BX + 12, y + 8), Vector2(60, 56),
		"#%d" % (slot + 1), 28, COL_GREEN if exists else COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if exists:
		var pt := float(summary["play_time"])
		var mins := int(pt / 60.0)
		var secs := int(fmod(pt, 60.0))
		_lbl(parent, Vector2(BX + 80, y + 8), Vector2(400, 22),
			"Nivel %d  ·  %d XP  ·  %d absorciones" % [
				int(summary["level"]), int(summary["total_xp"]), int(summary["absorptions"])],
			15, COL_TEXT)
		_lbl(parent, Vector2(BX + 80, y + 36), Vector2(300, 20),
			"Tiempo: %02d:%02d" % [mins, secs], 13, COL_MUTED)
		# Botón borrar
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.position = Vector2(BX + BW - 44, y + 16)
		del_btn.size     = Vector2(36, 36)
		del_btn.flat     = true
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		del_btn.add_theme_font_size_override("font_size", 18)
		var s := slot
		del_btn.pressed.connect(func(): _delete_slot(s))
		parent.add_child(del_btn)
	else:
		_lbl(parent, Vector2(BX + 80, y + 22), Vector2(400, 28),
			"— Partida vacía —", 16, COL_MUTED)
	# Botón principal del slot
	var btn := Button.new()
	btn.position = Vector2(BX, y); btn.size = Vector2(BW - 50, BH)
	btn.flat = true
	btn.mouse_entered.connect(func(): bg.color = bg_col.lightened(0.12))
	btn.mouse_exited.connect(func():  bg.color = bg_col)
	var s := slot
	btn.pressed.connect(func(): _select_slot(s))
	parent.add_child(btn)

func _show_slots() -> void:
	_main_panel.visible = false
	_slot_panel.visible = true

func _hide_slots() -> void:
	_slot_panel.visible = false
	_main_panel.visible = true

func _select_slot(slot: int) -> void:
	SaveMgr.select_slot(slot)
	ProgressionMgr.load_from_slot()
	GM.high_score = int(SaveMgr.get_val("high_score", 0))
	GM.go_to_cinematic()

func _delete_slot(slot: int) -> void:
	SaveMgr.delete_slot(slot)
	if slot == SaveMgr.get_active_slot():
		ProgressionMgr.reset()
	# Reconstruir panel de slots — remove old, build and add new
	_slot_panel.queue_free()
	_slot_panel = _build_slot_panel()
	_slot_panel.visible = true
	_root.add_child(_slot_panel)

func _open_options() -> void:
	var scr := load("res://scripts/ui/options_menu.gd")
	if scr:
		var om := CanvasLayer.new()
		om.set_script(scr)
		om.layer = layer + 2
		add_child(om)

func _build_btn(parent: Control, txt: String, y: int,
		bg: Color, fg: Color, cb: Callable) -> void:
	var BX := 760; var BW := 400; var BH := 60
	_cr(parent, Vector2(BX + 3, y + 3), Vector2(BW, BH), Color(0, 0, 0, 0.4))
	var bg_rect := _cr(parent, Vector2(BX, y), Vector2(BW, BH), bg)
	_cr(parent, Vector2(BX, y), Vector2(3, BH), fg * 0.8)
	var btn := Button.new()
	btn.text = txt; btn.position = Vector2(BX, y); btn.size = Vector2(BW, BH)
	btn.flat = true
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", fg * 0.7)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): bg_rect.color = bg.lightened(0.15))
	btn.mouse_exited.connect(func():  bg_rect.color = bg)
	parent.add_child(btn)

func _build_footer() -> void:
	_cr(_root, Vector2(0, 1064), Vector2(1920, 1), Color(0.1, 0.2, 0.12, 0.5))
	_lbl(_root, Vector2(0, 1058), Vector2(1920, 20),
		"Symbiote Escape  ·  v10.0  ·  Godot 4.6",
		12, Color(0.25, 0.28, 0.32), HORIZONTAL_ALIGNMENT_CENTER)

func _process(delta: float) -> void:
	_elapsed += delta
	if _title_lbl:
		var p := 1.0 + sin(_elapsed * 1.4) * 0.018
		_title_lbl.scale = Vector2(p, p)
		_title_lbl.pivot_offset = _title_lbl.size * 0.5
	for r in _particles:
		if not is_instance_valid(r): continue
		r.position.y -= float(r.get_meta("speed", 18.0)) * delta
		r.position.x += float(r.get_meta("drift", 0.0)) * delta * 0.3
		if r.position.y < -6.0:
			r.position.y = 1086.0
			r.position.x = randf_range(0, 1920)

func _cr(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col; r.position = pos; r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r); return r

func _lbl(parent: Control, pos: Vector2, sz: Vector2, txt: String,
		fs: int, col: Color, ha: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos; l.size = sz; l.text = txt; l.horizontal_alignment = ha
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l); return l
