## ARCHIVO: symbiote_aura.gd
## Pega este script como hijo del nodo del simbionte
## Crear un GPUParticles3D llamado "SymbioteAura" y asignar este script

extends GPUParticles3D

func _ready():
	amount = 60             # era 80
	lifetime = 1.0
	explosiveness = 0.0
	randomness = 0.3
	fixed_fps = 0
	fract_delta = true
	one_shot = false

	var mat = ParticleProcessMaterial.new()

	# Emisión desde esfera
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5

	# Dirección y velocidad
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0.15, 0)
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6

	# Escala
	mat.scale_min = 0.03
	mat.scale_max = 0.07

	# Color
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.5, 0.0, 1.0, 0.7),
		Color(0.3, 0.0, 0.6, 0.3),
		Color(0.1, 0.0, 0.2, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var color_curve = GradientTexture1D.new()
	color_curve.gradient = gradient
	mat.color_ramp = color_curve

	# Turbulencia — FIX: reducida de 3.0 → 0.6 para evitar partículas caóticas
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6    # era 3.0
	mat.turbulence_noise_scale = 3.0
	mat.turbulence_noise_speed_random = 0.3
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.15
	mat.turbulence_initial_displacement_min = -0.15
	mat.turbulence_initial_displacement_max = 0.15

	process_material = mat

	# Draw pass
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.4, 0.0, 0.8)
	draw_mat.emission_energy_multiplier = 1.2  # era 3.0 — FIX: causaba bloom explosivo

	draw_mat.albedo_color = Color(0.5, 0.0, 1.0, 0.7)

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.09, 0.09)
	mesh.material = draw_mat
	draw_pass_1 = mesh
