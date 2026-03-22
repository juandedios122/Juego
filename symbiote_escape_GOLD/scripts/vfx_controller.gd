## ARCHIVO: vfx_controller.gd
## Adjunta al nodo Camera3D del jugador
## Maneja: screen shake, chromatic aberration, motion blur, efectos de impacto

extends Camera3D

# === SCREEN SHAKE ===
var shake_strength: float = 0.0
var shake_decay: float = 8.0
var shake_frequency: float = 15.0
var shake_time: float = 0.0
var original_fov: float = 75.0

# === CHROMATIC ABERRATION (via shader de pantalla) ===
var aberration_strength: float = 0.0
var aberration_decay: float = 5.0

# === REFERENCIAS ===
var screen_shader_rect: ColorRect
var camera_pivot: Node3D
var base_position: Vector3

func _ready():
	original_fov = fov
	_setup_screen_effects()

func _setup_screen_effects():
	# Overlay de efectos en pantalla
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	screen_shader_rect = ColorRect.new()
	screen_shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Shader de post-proceso en canvas
	var screen_mat = ShaderMaterial.new()
	screen_mat.shader = _create_screen_shader()
	screen_shader_rect.material = screen_mat
	canvas.add_child(screen_shader_rect)

func _create_screen_shader() -> Shader:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;

uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_sharpness : hint_range(1.0, 8.0) = 3.0;
uniform float scanline_opacity : hint_range(0.0, 0.3) = 0.04;
uniform float noise_grain : hint_range(0.0, 0.05) = 0.015;
uniform float pulse_overlay : hint_range(0.0, 1.0) = 0.0;
uniform vec4 pulse_color : source_color = vec4(0.3, 0.0, 0.7, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)))*43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Chromatic aberration (daño/absorción)
	vec4 col_r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0));
	vec4 col_g = texture(TEXTURE, uv);
	vec4 col_b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0));
	vec4 color = vec4(col_r.r, col_g.g, col_b.b, col_g.a);
	
	// Viñeta symbiote (bordes oscuros púrpura)
	float dist = distance(uv, vec2(0.5));
	float vignette = pow(dist * 2.0, vignette_sharpness);
	vignette = clamp(vignette * vignette_strength, 0.0, 1.0);
	color.rgb = mix(color.rgb, vec3(0.02, 0.0, 0.05), vignette);
	
	// Scanlines sutiles
	float scanline = sin(uv.y * 600.0) * 0.5 + 0.5;
	scanline = pow(scanline, 2.0) * scanline_opacity;
	color.rgb -= scanline;
	
	// Grain (película)
	float grain = hash(uv + vec2(TIME * 0.1)) * noise_grain;
	color.rgb += grain - noise_grain * 0.5;
	
	// Pulse de absorción
	if (pulse_overlay > 0.0) {
		float radial = 1.0 - smoothstep(0.0, 0.5, dist);
		color.rgb = mix(color.rgb, pulse_color.rgb, pulse_overlay * radial * 0.4);
		// Ring expandiéndose
		float ring = smoothstep(0.0, 0.02, abs(dist - pulse_overlay * 0.6));
		color.rgb += pulse_color.rgb * (1.0 - ring) * pulse_overlay * 0.6;
	}
	
	COLOR = color;
}
"""
	return sh

func _process(delta: float):
	# === SHAKE ===
	if shake_strength > 0.01:
		shake_time += delta * shake_frequency
		var offset = Vector3(
			sin(shake_time * 3.7) * shake_strength,
			sin(shake_time * 5.1) * shake_strength,
			0.0
		)
		position = base_position + offset
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
	else:
		shake_strength = 0.0
		position = base_position
	
	# === CHROMATIC ABERRATION ===
	if aberration_strength > 0.001:
		aberration_strength = lerp(aberration_strength, 0.0, aberration_decay * delta)
		if screen_shader_rect and screen_shader_rect.material:
			screen_shader_rect.material.set_shader_parameter("chromatic_aberration", aberration_strength)

# === API PÚBLICA ===

func shake(strength: float = 0.05, frequency: float = 15.0):
	"""Sacudir la cámara. strength: 0.01-0.2"""
	shake_strength = strength
	shake_frequency = frequency
	base_position = position

func chromatic_hit(strength: float = 0.015):
	"""Efecto de impacto con aberración cromática"""
	aberration_strength = strength
	if screen_shader_rect and screen_shader_rect.material:
		screen_shader_rect.material.set_shader_parameter("chromatic_aberration", strength)

func absorb_pulse():
	"""Pulso visual cuando se absorbe un enemigo"""
	if not screen_shader_rect or not screen_shader_rect.material:
		return
	var tween = create_tween()
	screen_shader_rect.material.set_shader_parameter("pulse_overlay", 0.0)
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		0.0, 1.0, 0.15
	)
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		1.0, 0.0, 0.4
	)
	shake(0.03)
	chromatic_hit(0.012)

func level_up_flash():
	"""Flash al subir de nivel"""
	if not screen_shader_rect or not screen_shader_rect.material:
		return
	screen_shader_rect.material.set_shader_parameter("pulse_color", Color(0.5, 0.0, 1.0, 1.0))
	var tween = create_tween()
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		0.0, 0.8, 0.1
	)
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		0.8, 0.0, 0.6
	)
	shake(0.06)
	chromatic_hit(0.02)

func damage_flash():
	"""Flash al recibir daño"""
	screen_shader_rect.material.set_shader_parameter("pulse_color", Color(0.8, 0.0, 0.1, 1.0))
	var tween = create_tween()
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		0.0, 0.5, 0.05
	)
	tween.tween_method(
		func(v): screen_shader_rect.material.set_shader_parameter("pulse_overlay", v),
		0.5, 0.0, 0.3
	)
	shake(0.04)
	chromatic_hit(0.018)

func zoom_fov(target_fov: float, duration: float = 0.3):
	"""Zoom dramático para habilidades especiales"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "fov", target_fov, duration)
	tween.tween_property(self, "fov", original_fov, duration * 1.5)
