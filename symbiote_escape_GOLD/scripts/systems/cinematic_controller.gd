extends Node
## CinematicController — cinemática de introducción completa en UI.
## Extiende Node (no Node3D), usa solo CanvasLayer+ColorRect+Label.

var _cv  : CanvasLayer
var _bg  : ColorRect
var _ttl : Label
var _sub : Label
var _hint: Label
var _pts : Array = []

var elapsed   : float = 0.0
var phase     : int   = 0
var pt        : float = 0.0   # phase time
var _skipped  : bool  = false

const PHASES = [
	{"dur": 2.5, "title": "",                 "sub": "",                                     "bg": 0},
	{"dur": 3.0, "title": "ESPACIO PROFUNDO", "sub": "Un cuerpo extraño se aproxima...",      "bg": 1},
	{"dur": 2.5, "title": "IMPACTO",          "sub": "Planta Nuclear KRYLOS-7 — IMPACTADA",  "bg": 2},
	{"dur": 3.5, "title": "",                 "sub": "Algo sobrevivio al impacto...",          "bg": 3},
	{"dur": 3.0, "title": "SYMBIOTE ESCAPE",  "sub": "Escapa antes de que sea demasiado tarde","bg": 4},
	{"dur": 2.0, "title": "",                 "sub": "",                                      "bg": 5},
]

const BGCOLS = [
	Color(0.00, 0.00, 0.02, 1.0),
	Color(0.00, 0.00, 0.06, 1.0),
	Color(0.35, 0.05, 0.00, 1.0),
	Color(0.02, 0.00, 0.05, 1.0),
	Color(0.00, 0.06, 0.02, 1.0),
	Color(0.00, 0.00, 0.00, 1.0),
]

func _ready() -> void:
	AudioMgr.play_cinematic_intro()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GM.game_active = false
	_build()

func _build() -> void:
	_cv = CanvasLayer.new()
	_cv.layer = 10
	add_child(_cv)

	_bg = ColorRect.new()
	_bg.color = BGCOLS[0]
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cv.add_child(_bg)

	for i in 90:
		var r := ColorRect.new()
		r.size  = Vector2(randf_range(1.0, 3.5), randf_range(1.0, 3.5))
		r.color = Color(1.0, 1.0, 1.0, randf_range(0.1, 0.8))
		r.position = Vector2(randf_range(0, 1920), randf_range(0, 1080))
		_cv.add_child(r)
		_pts.append({"r": r, "sp": randf_range(12.0, 65.0), "ba": r.color.a})

	_ttl  = _lbl(510, 420, 900, 110, 62, Color(1.0, 1.0, 1.0, 0.0))
	_sub  = _lbl(510, 555, 900,  60, 27, Color(0.75, 0.75, 0.75, 0.0))
	_hint = _lbl(1620,1032,280,  36, 17, Color(1.0, 1.0, 1.0, 0.3))
	_hint.text = "[ ENTER ]  Saltar"

func _lbl(x:int,y:int,w:int,h:int,fs:int,col:Color) -> Label:
	var lb := Label.new()
	lb.position = Vector2(x, y)
	lb.size     = Vector2(w, h)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	_cv.add_child(lb)
	return lb

func _process(delta: float) -> void:
	if _skipped:
		return
	if Input.is_action_just_pressed("skip_cinematic") or Input.is_action_just_pressed("ui_cancel"):
		_skip()
		return
	elapsed += delta
	pt     += delta
	_tick_particles(delta)
	_tick_phase(delta)

func _tick_particles(delta: float) -> void:
	for p in _pts:
		var r : ColorRect = p["r"]
		r.position.x -= p["sp"] * delta
		if r.position.x < -5.0:
			r.position.x = 1925.0
			r.position.y = randf_range(0.0, 1080.0)
		var fl := sin(elapsed * p["sp"] * 0.25) * 0.12
		r.color.a = clampf(p["ba"] + fl, 0.0, 1.0)
		if phase == 2:
			r.color = Color(1.0, clampf(r.color.g - delta*3.0, 0.2, 1.0), 0.0, r.color.a)
		elif phase >= 3:
			r.color = Color(
				lerpf(r.color.r, 0.25, delta * 0.8),
				lerpf(r.color.g, 0.00, delta * 0.8),
				lerpf(r.color.b, 0.60, delta * 0.8),
				r.color.a)

func _tick_phase(delta: float) -> void:
	var dur : float = PHASES[phase]["dur"]
	var t   : float = pt / dur

	match phase:
		0:
			_bg.color = _bg.color.lerp(BGCOLS[0], delta * 0.5)
			if pt >= dur: _next()
		1:
			_bg.color = _bg.color.lerp(BGCOLS[1], delta * 0.3)
			_ftxt(_ttl, PHASES[1]["title"], t, Color(0.6, 0.8, 1.0, 1.0))
			_ftxt(_sub, PHASES[1]["sub"],   t, Color(0.5, 0.7, 0.9, 1.0))
			if pt >= dur: _next()
		2:
			_bg.color = _bg.color.lerp(BGCOLS[2], delta * 12.0)
			var shk := maxf(0.0, 1.0 - pt) * 22.0
			_ttl.position.x = 510.0 + randf_range(-shk, shk)
			_ttl.position.y = 420.0 + randf_range(-shk, shk)
			_ttl.text = PHASES[2]["title"]
			_sub.text = PHASES[2]["sub"]
			_ttl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0, minf(t*4.0,1.0)))
			_sub.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, minf(t*3.0,0.85)))
			if pt >= dur: _next()
		3:
			_bg.color = _bg.color.lerp(BGCOLS[3], delta * 1.5)
			_ttl.position = Vector2(510.0, 420.0)
			_ftxt(_ttl, PHASES[3]["title"], t, Color(0.6, 0.0, 1.0, 1.0))
			_ftxt(_sub, PHASES[3]["sub"],   t, Color(0.7, 0.5, 0.9, 1.0))
			if pt >= dur: _next()
		4:
			_bg.color = _bg.color.lerp(BGCOLS[4], delta * 0.8)
			_ftxt(_ttl, PHASES[4]["title"], t, Color(0.2, 1.0, 0.4, 1.0))
			_ftxt(_sub, PHASES[4]["sub"],   t, Color(0.5, 0.9, 0.5, 1.0))
			if pt >= dur: _next()
		5:
			_bg.color = Color(0.0, 0.0, 0.0, 1.0)
			_ttl.add_theme_color_override("font_color", Color(1.0,1.0,1.0, 1.0-minf(t,1.0)))
			_sub.add_theme_color_override("font_color", Color(1.0,1.0,1.0, 1.0-minf(t,1.0)))
			if pt >= dur:
				GM.go_to_level()

func _ftxt(lb: Label, txt: String, t: float, col: Color) -> void:
	if lb.text != txt:
		lb.text = txt
	var a := 0.0
	if   t < 0.18:  a = t / 0.18
	elif t > 0.78:  a = 1.0 - (t - 0.78) / 0.22
	else:           a = 1.0
	lb.add_theme_color_override("font_color", Color(col.r, col.g, col.b, a))

func _next() -> void:
	phase = mini(phase + 1, PHASES.size() - 1)
	pt = 0.0
	_ttl.text = ""
	_sub.text = ""

func _skip() -> void:
	_skipped = true
	var tw := create_tween()
	tw.tween_property(_bg, "color", Color(0.0, 0.0, 0.0, 1.0), 0.35)
	await tw.finished
	GM.go_to_level()
