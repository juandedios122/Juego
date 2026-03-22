## ARCHIVO: symbiote_aura.tscn
## Pega este script como hijo del nodo del simbionte
## Crear un GPUParticles3D llamado "SymbioteAura" y asignar este script

extends GPUParticles3D

func _ready():
	# Configuración de partículas de aura
	amount = 80
	lifetime = 1.2
	explosiveness = 0.0
	randomness = 0.3
	fixed_fps = 0
	fract_delta = true
	one_shot = false
	
	# El process material debe ser un ParticleProcessMaterial
	var mat = ParticleProcessMaterial.new()
	
	# Emisión desde esfera
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.55
	
	# Dirección y velocidad
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0.2, 0)
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	
	# Escala
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	
	# Color - púrpura/violeta
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.5, 0.0, 1.0, 0.8),
		Color(0.3, 0.0, 0.6, 0.4),
		Color(0.1, 0.0, 0.2, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	
	var color_curve = GradientTexture1D.new()
	color_curve.gradient = gradient
	mat.color_ramp = color_curve
	
	# Turbulencia para look orgánico
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 3.0
	mat.turbulence_noise_scale = 4.0
	mat.turbulence_noise_speed_random = 0.5
	mat.turbulence_influence_min = 0.1
	mat.turbulence_influence_max = 0.2
	mat.turbulence_initial_displacement_min = -0.3
	mat.turbulence_initial_displacement_max = 0.3
	
	process_material = mat
	
	# Draw pass - usar QuadMesh para billboards
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.4, 0.0, 0.8)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.albedo_color = Color(0.5, 0.0, 1.0, 0.8)
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	mesh.material = draw_mat
	draw_pass_1 = mesh
