## ARCHIVO: symbiote_tendrils.gd
## Partículas que se arrastran por el suelo al caminar

extends GPUParticles3D

@export var trail_length: float = 0.8
@export var spawn_rate: int = 30

func _ready():
	amount = 50             # era 80
	lifetime = 1.0
	explosiveness = 0.0
	randomness = 0.6
	one_shot = false
	local_coords = true

	var mat = ParticleProcessMaterial.new()

	# Emisión en disco plano
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.6      # era 0.8
	mat.emission_ring_inner_radius = 0.15
	mat.emission_ring_height = 0.05
	mat.emission_ring_axis = Vector3(0, 1, 0)

	# Movimiento
	mat.direction = Vector3(0, 0.05, 1)
	mat.spread = 150.0
	mat.gravity = Vector3(0, -0.5, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5     # era 2.2
	mat.damping_min = 2.0
	mat.damping_max = 4.0

	# Turbulencia — FIX: el bloque duplicado y strength=3.0 causaba caos visual
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.5    # era 3.0
	mat.turbulence_noise_scale = 2.0
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.2
	mat.turbulence_initial_displacement_min = 0.0
	mat.turbulence_initial_displacement_max = 0.1

	# Escala
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0))
	scale_curve.add_point(Vector2(0.1, 1))
	scale_curve.add_point(Vector2(0.6, 0.6))
	scale_curve.add_point(Vector2(1, 0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	mat.scale_min = 0.02
	mat.scale_max = 0.08               # era 0.12

	# Color
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.6, 0.0, 1.0, 0.9),
		Color(0.4, 0.0, 0.8, 0.6),
		Color(0.2, 0.0, 0.5, 0.3),
		Color(0.05, 0.0, 0.15, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = gradient
	mat.color_ramp = color_tex

	process_material = mat

	# Material visual
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.35, 0.0, 0.7)
	draw_mat.emission_energy_multiplier = 1.0  # era 2.0 — FIX

	draw_mat.albedo_color = Color(0.3, 0.0, 0.6, 0.8)

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.10, 0.04)
	mesh.material = draw_mat
	draw_pass_1 = mesh
