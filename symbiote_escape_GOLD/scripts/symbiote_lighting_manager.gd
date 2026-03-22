## ARCHIVO: symbiote_lighting_manager.gd
## Adjunta al nodo raíz de la escena
## Maneja toda la iluminación dinámica del nivel

extends Node

# === LUCES ===
@onready var main_light: OmniLight3D
@onready var symbiote_light: OmniLight3D
@onready var accent_lights: Array[OmniLight3D] = []

var time: float = 0.0

# === CONFIGURACIÓN ===
const SYMBIOTE_LIGHT_COLOR = Color(0.4, 0.0, 0.9, 1.0)
const SYMBIOTE_LIGHT_ENERGY_MIN = 2.5
const SYMBIOTE_LIGHT_ENERGY_MAX = 4.5
const SYMBIOTE_PULSE_SPEED = 1.8

const ACCENT_COLORS = [
	Color(0.3, 0.0, 0.7),
	Color(0.5, 0.0, 0.8),
	Color(0.15, 0.0, 0.4),
]

func _ready():
	_setup_environment()
	_setup_lights()

func _setup_environment():
	# Configurar WorldEnvironment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	
	# Fondo oscuro
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.005, 0.02, 1)
	
	# Ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.0, 0.12, 1)
	env.ambient_light_energy = 0.5
	
	# Tonemap cinematográfico
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	
	# GLOW - esencial para el look symbiote
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.85
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale = 2.0
	
	# SSAO
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.5
	env.ssao_power = 1.5
	
	# SSR
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	
	# Niebla volumétrica oscura
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.04, 0.0, 0.08)
	env.volumetric_fog_emission = Color(0.05, 0.0, 0.15)
	env.volumetric_fog_emission_energy = 0.25
	env.volumetric_fog_length = 64.0
	
	# Color grading
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.2
	
	env_node.environment = env
	add_child(env_node)

func _setup_lights():
	# === LUZ PRINCIPAL (techo, oscura y fría) ===
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-60, -45, 0)
	dir_light.light_color = Color(0.3, 0.25, 0.4)
	dir_light.light_energy = 0.4
	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.05
	dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	dir_light.directional_shadow_max_distance = 50.0
	add_child(dir_light)
	
	# === LUZ DEL SIMBIONTE (sigue al jugador) ===
	symbiote_light = OmniLight3D.new()
	symbiote_light.light_color = SYMBIOTE_LIGHT_COLOR
	symbiote_light.light_energy = 3.5
	symbiote_light.omni_range = 6.0
	symbiote_light.omni_attenuation = 1.5
	symbiote_light.shadow_enabled = true
	symbiote_light.shadow_bias = 0.1
	add_child(symbiote_light)
	
	# === SPOT LIGHTS EN PILARES (tipo prisión oscura) ===
	_create_ceiling_spots()
	
	# === LUCES DE ACENTO AMBIENTALES ===
	_create_accent_lights()

func _create_ceiling_spots():
	# Spotlights en el techo para efecto de interrogatorio/laboratorio
	var positions = [
		Vector3(0, 8, 0),
		Vector3(8, 8, 8),
		Vector3(-8, 8, 8),
		Vector3(8, 8, -8),
		Vector3(-8, 8, -8),
	]
	
	for pos in positions:
		var spot = SpotLight3D.new()
		spot.position = pos
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.light_color = Color(0.7, 0.6, 0.9)
		spot.light_energy = 2.0
		spot.spot_range = 12.0
		spot.spot_angle = 35.0
		spot.spot_angle_attenuation = 0.8
		spot.shadow_enabled = true
		add_child(spot)

func _create_accent_lights():
	# Luces de color en puntos del escenario (aportan profundidad)
	var accent_data = [
		{pos = Vector3(5, 0.5, 5), color = Color(0.2, 0.0, 0.5), energy = 1.5, range_ = 4.0},
		{pos = Vector3(-5, 0.5, -5), color = Color(0.3, 0.0, 0.6), energy = 1.2, range_ = 3.5},
		{pos = Vector3(-6, 1.0, 6), color = Color(0.1, 0.0, 0.3), energy = 1.8, range_ = 5.0},
		{pos = Vector3(7, 0.5, -3), color = Color(0.15, 0.0, 0.4), energy = 1.0, range_ = 3.0},
	]
	
	for d in accent_data:
		var light = OmniLight3D.new()
		light.position = d.pos
		light.light_color = d.color
		light.light_energy = d.energy
		light.omni_range = d.range_
		light.shadow_enabled = false # Sin sombra para performance
		accent_lights.append(light)
		add_child(light)

func _process(delta: float):
	time += delta
	
	# === PULSO DEL SIMBIONTE ===
	var pulse = sin(time * SYMBIOTE_PULSE_SPEED) * 0.5 + 0.5
	var pulse2 = sin(time * SYMBIOTE_PULSE_SPEED * 1.7 + 1.2) * 0.4 + 0.6
	
	if symbiote_light:
		symbiote_light.light_energy = lerp(
			SYMBIOTE_LIGHT_ENERGY_MIN,
			SYMBIOTE_LIGHT_ENERGY_MAX,
			pulse
		)
		# Cambio sutil de color
		symbiote_light.light_color = Color(
			0.3 + pulse * 0.15,
			0.0,
			0.8 + pulse2 * 0.2,
			1.0
		)
	
	# === PARPADEO AMBIENTAL ===
	for i in accent_lights.size():
		var light = accent_lights[i]
		var flicker = sin(time * (1.2 + i * 0.7) + i * 2.1) * 0.15 + 0.85
		light.light_energy = ACCENT_COLORS[i % ACCENT_COLORS.size()].r * 2.0 * flicker

func attach_to_player(player: Node3D):
	## Llama esto desde el jugador para seguirlo
	if symbiote_light:
		symbiote_light.reparent(player)
		symbiote_light.position = Vector3(0, 0.5, 0)
