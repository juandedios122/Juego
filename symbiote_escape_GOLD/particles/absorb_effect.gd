## ARCHIVO: absorb_effect.gd
## Efecto de absorción de enemigos - espectacular

extends GPUParticles3D

signal absorption_complete

@export var absorb_duration: float = 1.0
var target_pos: Vector3

func trigger_absorption(from_pos: Vector3, to_pos: Vector3):
	global_position = from_pos
	target_pos = to_pos
	
	# Partículas que vuelan desde enemigo hacia el simbionte
	amount = 120
	lifetime = absorb_duration * 0.9
	explosiveness = 0.8
	one_shot = true
	emitting = true
	
	var mat = ParticleProcessMaterial.new()
	
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	
	# Atraer hacia destino
	mat.attractor_interaction_enabled = true
	
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0.5, 0)
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	
	# Rotación
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	
	# Escala
	mat.scale_min = 0.05
	mat.scale_max = 0.18
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	
	# Color mágico
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.7, 0.0, 1.0, 0.9),
		Color(0.3, 0.0, 0.6, 0.5),
		Color(0.0, 0.0, 0.1, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = gradient
	mat.color_ramp = color_tex
	
	process_material = mat
	
	# Material - brillante
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.8, 0.0, 1.0)
	draw_mat.emission_energy_multiplier = 5.0
	draw_mat.albedo_color = Color(0.6, 0.0, 1.0, 1.0)
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
	mesh.material = draw_mat
	draw_pass_1 = mesh
	
	# Mover partículas al destino
	var tween = create_tween()
	tween.tween_property(self, "global_position", to_pos, absorb_duration * 0.7)
	tween.tween_callback(func(): emission_complete.emit())

# Usar en el script del simbionte:
# var absorb = preload("res://particles/absorb_effect.gd")
# 
# func absorb_enemy(enemy: Node3D):
#     var effect = GPUParticles3D.new()
#     effect.set_script(absorb)
#     get_parent().add_child(effect)
#     effect.trigger_absorption(enemy.global_position, global_position)
#     enemy.queue_free()
