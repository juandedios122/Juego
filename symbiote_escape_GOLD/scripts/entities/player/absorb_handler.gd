extends Node
## AbsorbHandler — gestiona la lógica de absorción.
## Emite señales con tipo de enemigo y posición para VFX/SFX.

signal absorb_completed(target: Node, enemy_type: String)
signal absorb_progress_changed(progress: float)
signal absorb_tick(progress: float, target_pos: Vector3)
signal absorb_started
signal absorb_cancelled

const ABSORB_TIME  := Constants.ABSORB_TIME
const ABSORB_RANGE := Constants.ABSORB_RANGE
const TICK_INTERVAL := 0.12   # segundos entre ticks de VFX

var active   : bool  = false
var target   : Node  = null
var progress : float = 0.0

var _area       : Area3D = null
var _tick_timer : float  = 0.0

func setup(area: Area3D) -> void:
	_area = area

func tick(delta: float, pressing: bool) -> void:
	if not pressing:
		if active:
			absorb_cancelled.emit()
		_cancel()
		return

	if _area == null:
		return

	var closest := _find_closest()
	if closest == null:
		if active:
			absorb_cancelled.emit()
		_cancel()
		return

	# Cambio de objetivo → resetear progreso
	if target != closest:
		target   = closest
		progress = 0.0

	# Primera vez que se activa
	if not active:
		active = true
		absorb_started.emit()

	progress += delta / ABSORB_TIME
	progress  = minf(progress, 1.0)
	absorb_progress_changed.emit(progress)
	closest.start_absorb(progress)

	# Tick periódico para partículas y audio
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		absorb_tick.emit(progress, closest.global_position)

	if progress >= 1.0:
		var t     := target
		var etype : String = t.get("enemy_type") if t.get("enemy_type") != null else "worker"
		_cancel()
		absorb_completed.emit(t, etype)

func _cancel() -> void:
	active      = false
	target      = null
	progress    = 0.0
	_tick_timer = 0.0

func _find_closest() -> Node:
	if _area == null:
		return null
	var best := INF
	var found : Node = null
	for body in _area.get_overlapping_bodies():
		if body.has_method("start_absorb"):
			var d := _area.global_position.distance_to(body.global_position)
			if d < best:
				best  = d
				found = body
	return found
