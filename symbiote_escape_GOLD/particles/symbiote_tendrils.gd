## ARCHIVO: symbiote_tendrils.gd
## Partículas que se arrastran por el suelo al caminar

extends GPUParticles3D

@export var trail_length: float = 0.8
@export var spawn_rate: int = 30

func _ready():
	amount = 50
	lifetime = 0.8
	explosiveness = 0.0
	randomness = 0.6
	one_shot = false
	local_coords = true
	
	var mat = ParticleProcessMaterial.new()
	
	# Emisión en disco plano (nivel del suelo)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.5
	mat.emission_ring_inner_radius = 0.1
	mat.emission_ring_height = 0.02
	mat.emission_ring_axis = Vector3(0, 1, 0)
	
	# Movimiento horizontal hacia afuera
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.damping_min = 3.0
	mat.damping_max = 6.0
	
	# Escala (empiezan pequeñas, crecen, desaparecen)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0))
	scale_curve.add_point(Vector2(0.1, 1))
	scale_curve.add_point(Vector2(0.6, 0.6))
	scale_curve.add_point(Vector2(1, 0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve_x = scale_tex
	
	mat.scale_min = 0.02
	mat.scale_max = 0.06
	
	# Escala no uniforme (forma de tentáculo alargada)
	mat.scale_over_velocity_enabled = false
	
	# Color
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.4, 0.0, 0.8, 1.0),
		Color(0.2, 0.0, 0.4, 0.5),
		Color(0.05, 0.0, 0.1, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = gradient
	mat.color_ramp = color_tex
	
	# Turbulencia para movimiento orgánico
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 5.0
	mat.turbulence_noise_scale = 8.0
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.15
	
	process_material = mat
	
	# Material visual
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.35, 0.0, 0.7)
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.albedo_color = Color(0.3, 0.0, 0.6, 0.9)
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.12, 0.04)
	mesh.material = draw_mat
	draw_pass_1 = mesh
